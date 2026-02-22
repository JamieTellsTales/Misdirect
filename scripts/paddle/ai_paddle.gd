extends "res://scripts/paddle/paddle.gd"
class_name AIPaddle
## AI-controlled paddle with department personality

# AI behavior parameters
@export var move_speed: float = 400.0
@export var reaction_delay: float = 0.1  # Seconds before reacting to ticket
@export var accuracy: float = 0.9  # 0.0-1.0, chance to track correctly
@export var prediction_strength: float = 0.5  # How much to predict ticket movement

# Personality traits
var should_deflect_own_tickets: bool = false  # Security paranoia
var ignore_purple_tickets: bool = false  # Development ignores Management
var panic_threshold: int = 3  # Service Desk panics with many tickets

# Movement bounds
var min_pos: float = 0.0
var max_pos: float = 0.0
var locked_pos: float = 0.0  # Position on the locked axis

# Internal state
var target_position: float = 0.0
var reaction_timer: float = 0.0
var current_target_ticket: Node2D = null
var is_panicking: bool = false


func _ready() -> void:
	super._ready()
	_calculate_movement_bounds()
	_apply_personality()
	# Store the initial position on the axis we don't move
	if is_horizontal:
		locked_pos = position.y
	else:
		locked_pos = position.x


func _calculate_movement_bounds() -> void:
	# Paddles can only move within their fixed-size zone
	var arena_width: float = 1280.0
	var arena_height: float = 720.0
	var zone_length: float = 400.0  # Fixed zone width for fairness
	var half_length: float = paddle_length / 2.0
	var half_zone: float = zone_length / 2.0

	if is_horizontal:
		# Horizontal paddle moves left/right within zone
		var center_x: float = arena_width / 2.0
		min_pos = center_x - half_zone + half_length
		max_pos = center_x + half_zone - half_length
	else:
		# Vertical paddle moves up/down within zone
		var center_y: float = arena_height / 2.0
		min_pos = center_y - half_zone + half_length
		max_pos = center_y + half_zone - half_length


func _apply_personality() -> void:
	match department_type:
		DepartmentDataScript.DepartmentType.SERVICE_DESK:
			# Reactive, occasionally panics
			reaction_delay = 0.05
			accuracy = 0.85
			move_speed = 450.0
			prediction_strength = 0.3

		DepartmentDataScript.DepartmentType.INFRASTRUCTURE:
			# Slow to respond, rarely misses
			reaction_delay = 0.25
			accuracy = 0.95
			move_speed = 300.0
			prediction_strength = 0.7

		DepartmentDataScript.DepartmentType.SECURITY:
			# Paranoid, deflects almost everything
			reaction_delay = 0.08
			accuracy = 0.9
			move_speed = 400.0
			prediction_strength = 0.6
			should_deflect_own_tickets = true  # Paranoid!

		DepartmentDataScript.DepartmentType.DEVELOPMENT:
			# Distracted, ignores Management tickets
			reaction_delay = 0.15
			accuracy = 0.8
			move_speed = 350.0
			prediction_strength = 0.4
			ignore_purple_tickets = true

		DepartmentDataScript.DepartmentType.MANAGEMENT:
			# Almost never catches anything
			reaction_delay = 0.5
			accuracy = 0.3
			move_speed = 200.0
			prediction_strength = 0.1


func _physics_process(delta: float) -> void:
	reaction_timer += delta

	if reaction_timer >= reaction_delay:
		reaction_timer = 0.0
		_update_target()

	_move_toward_target(delta)


func _update_target() -> void:
	var tickets := get_tree().get_nodes_in_group("tickets")
	if tickets.is_empty():
		current_target_ticket = null
		return

	# Find the most threatening ticket
	var best_ticket: Node2D = null
	var best_threat: float = -1.0

	for ticket in tickets:
		var threat := _calculate_threat(ticket)
		if threat > best_threat:
			best_threat = threat
			best_ticket = ticket

	current_target_ticket = best_ticket

	if current_target_ticket:
		_calculate_target_position()


func _calculate_threat(ticket: Node2D) -> float:
	# Check if we should ignore this ticket
	if ignore_purple_tickets:
		var ticket_dept: int = ticket.department_type
		if ticket_dept == DepartmentDataScript.DepartmentType.MANAGEMENT:
			return -1.0  # Ignore it

	# Security paranoia: treat own tickets as threats too
	var is_own_ticket: bool = ticket.department_type == department_type
	if is_own_ticket and not should_deflect_own_tickets:
		# Let own tickets through (low threat)
		return -0.5

	# Calculate threat based on distance and direction
	var to_ticket: Vector2 = ticket.global_position - global_position
	var ticket_velocity: Vector2 = ticket.linear_velocity

	# How close is it?
	var distance: float = to_ticket.length()

	# Is it moving toward us?
	var approach_speed: float = 0.0
	if is_horizontal:
		# Horizontal paddle cares about Y velocity
		if department_type == DepartmentDataScript.DepartmentType.SERVICE_DESK:
			# Top paddle - ticket approaching if moving up (negative Y)
			approach_speed = -ticket_velocity.y
		else:
			# Bottom paddle - ticket approaching if moving down (positive Y)
			approach_speed = ticket_velocity.y
	else:
		# Vertical paddle cares about X velocity
		if department_type == DepartmentDataScript.DepartmentType.SECURITY:
			# Left paddle - ticket approaching if moving left (negative X)
			approach_speed = -ticket_velocity.x
		else:
			# Right paddle - ticket approaching if moving right (positive X)
			approach_speed = ticket_velocity.x

	# Threat = approaching fast and close
	if approach_speed <= 0:
		return -1.0  # Moving away, not a threat

	var threat: float = approach_speed / (distance + 100.0)

	# Service Desk panic check
	if department_type == DepartmentDataScript.DepartmentType.SERVICE_DESK:
		var ticket_count := get_tree().get_nodes_in_group("tickets").size()
		if ticket_count >= panic_threshold:
			is_panicking = true
			# Panic makes them less accurate
			threat *= randf_range(0.5, 1.5)
		else:
			is_panicking = false

	return threat


func _calculate_target_position() -> void:
	if not current_target_ticket:
		return

	var ticket_pos: Vector2 = current_target_ticket.global_position
	var ticket_vel: Vector2 = current_target_ticket.linear_velocity

	# Predict where the ticket will be
	var predicted_pos: Vector2 = ticket_pos + ticket_vel * prediction_strength

	# Apply accuracy (sometimes miss)
	if randf() > accuracy:
		# Intentional error
		var error: float = randf_range(-100.0, 100.0)
		if is_horizontal:
			predicted_pos.x += error
		else:
			predicted_pos.y += error

	# Extract the relevant axis
	if is_horizontal:
		target_position = predicted_pos.x
	else:
		target_position = predicted_pos.y

	# Clamp to bounds
	target_position = clampf(target_position, min_pos, max_pos)


func _move_toward_target(delta: float) -> void:
	var current_pos: float
	if is_horizontal:
		current_pos = position.x
	else:
		current_pos = position.y

	# Move toward target
	var direction: float = sign(target_position - current_pos)
	var distance: float = abs(target_position - current_pos)

	# Don't move if very close
	if distance < 5.0:
		velocity = Vector2.ZERO
	else:
		var move_amount: float = min(move_speed * delta, distance)
		if is_horizontal:
			position.x += direction * move_amount
			position.x = clampf(position.x, min_pos, max_pos)
			position.y = locked_pos  # Lock Y position
		else:
			position.y += direction * move_amount
			position.y = clampf(position.y, min_pos, max_pos)
			position.x = locked_pos  # Lock X position
