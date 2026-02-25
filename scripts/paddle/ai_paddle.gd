extends "res://scripts/paddle/paddle.gd"
class_name AIPaddle
## AI-controlled paddle

# ColourData is inherited from Paddle

# AI behaviour parameters
@export var move_speed: float = 400.0
@export var reaction_delay: float = 0.1  # Seconds before reacting to a ticket
@export var accuracy: float = 0.9        # 0.0-1.0, chance to track correctly
@export var prediction_strength: float = 0.5  # How much to predict ticket movement

# Personality traits
var should_deflect_own_colour: bool = false  # Red zone paranoia
var ignore_purple: bool = false              # Yellow zone ignores purple
var panic_threshold: int = 3                 # Blue zone panics with many tickets

# Movement bounds
var min_pos: float = 0.0
var max_pos: float = 0.0
var locked_pos: float = 0.0

# Internal state
var target_position: float = 0.0
var reaction_timer: float = 0.0
var current_target_ticket: Node2D = null
var is_panicking: bool = false


func _ready() -> void:
	super._ready()
	_calculate_movement_bounds()
	_apply_personality()
	if is_horizontal:
		locked_pos = position.y
	else:
		locked_pos = position.x


func _calculate_movement_bounds() -> void:
	var arena_width: float = 1280.0
	var arena_height: float = 720.0
	var zone_length: float = 400.0
	var half_length: float = paddle_length / 2.0
	var half_zone: float = zone_length / 2.0

	if is_horizontal:
		var center_x: float = arena_width / 2.0
		min_pos = center_x - half_zone + half_length
		max_pos = center_x + half_zone - half_length
	else:
		var center_y: float = arena_height / 2.0
		min_pos = center_y - half_zone + half_length
		max_pos = center_y + half_zone - half_length


func _apply_personality() -> void:
	match colour_type:
		ColourData.ColourType.BLUE:
			# Reactive, occasionally panics
			reaction_delay = 0.05
			accuracy = 0.85
			move_speed = 450.0
			prediction_strength = 0.3

		ColourData.ColourType.GREEN:
			# Slow to respond, rarely misses
			reaction_delay = 0.25
			accuracy = 0.95
			move_speed = 300.0
			prediction_strength = 0.7

		ColourData.ColourType.RED:
			# Paranoid, deflects almost everything including own balls
			reaction_delay = 0.08
			accuracy = 0.9
			move_speed = 400.0
			prediction_strength = 0.6
			should_deflect_own_colour = true

		ColourData.ColourType.YELLOW:
			# Distracted, ignores purple balls
			reaction_delay = 0.15
			accuracy = 0.8
			move_speed = 350.0
			prediction_strength = 0.4
			ignore_purple = true

		ColourData.ColourType.PURPLE:
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
	if ignore_purple:
		if ticket.colour_type == ColourData.ColourType.PURPLE:
			return -1.0

	var is_own_colour: bool = ticket.colour_type == colour_type
	if is_own_colour and not should_deflect_own_colour:
		return -0.5  # Let own colour through

	var to_ticket: Vector2 = ticket.global_position - global_position
	var ticket_velocity: Vector2 = ticket.linear_velocity
	var distance: float = to_ticket.length()

	var approach_speed: float = 0.0
	if is_horizontal:
		if colour_type == ColourData.ColourType.BLUE:
			approach_speed = -ticket_velocity.y  # Top paddle: threat moves up (neg Y)
		else:
			approach_speed = ticket_velocity.y   # Bottom paddle: threat moves down
	else:
		if colour_type == ColourData.ColourType.RED:
			approach_speed = -ticket_velocity.x  # Left paddle: threat moves left (neg X)
		else:
			approach_speed = ticket_velocity.x   # Right paddle: threat moves right

	if approach_speed <= 0:
		return -1.0

	var threat: float = approach_speed / (distance + 100.0)

	# Blue zone panic: less accurate when many tickets are in play
	if colour_type == ColourData.ColourType.BLUE:
		var ticket_count := get_tree().get_nodes_in_group("tickets").size()
		if ticket_count >= panic_threshold:
			is_panicking = true
			threat *= randf_range(0.5, 1.5)
		else:
			is_panicking = false

	return threat


func _calculate_target_position() -> void:
	if not current_target_ticket:
		return

	var ticket_pos: Vector2 = current_target_ticket.global_position
	var ticket_vel: Vector2 = current_target_ticket.linear_velocity

	var predicted_pos: Vector2 = ticket_pos + ticket_vel * prediction_strength

	if randf() > accuracy:
		var error: float = randf_range(-100.0, 100.0)
		if is_horizontal:
			predicted_pos.x += error
		else:
			predicted_pos.y += error

	if is_horizontal:
		target_position = predicted_pos.x
	else:
		target_position = predicted_pos.y

	target_position = clampf(target_position, min_pos, max_pos)


func _move_toward_target(delta: float) -> void:
	var current_pos: float
	if is_horizontal:
		current_pos = position.x
	else:
		current_pos = position.y

	var direction: float = sign(target_position - current_pos)
	var distance: float = abs(target_position - current_pos)

	if distance < 5.0:
		velocity = Vector2.ZERO
	else:
		var move_amount: float = min(move_speed * delta, distance)
		if is_horizontal:
			position.x += direction * move_amount
			position.x = clampf(position.x, min_pos, max_pos)
			position.y = locked_pos
		else:
			position.y += direction * move_amount
			position.y = clampf(position.y, min_pos, max_pos)
			position.x = locked_pos
