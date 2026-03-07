extends "res://scripts/paddle/paddle.gd"
class_name AIPaddle
## AI-controlled paddle — works for any zone orientation via move_direction / outward_dir.

@export var move_speed: float = 400.0
@export var reaction_delay: float = 0.1
@export var accuracy: float = 0.9
@export var prediction_strength: float = 0.5

# Personality flags
var should_deflect_own_colour: bool = false
var ignore_purple: bool = false
var panic_threshold: int = 3

# Internal state
var target_offset: float = 0.0     # Target position as scalar offset from zone_centre
var reaction_timer: float = 0.0
var current_target_ticket: Node2D = null
var is_panicking: bool = false


func _ready() -> void:
	super._ready()
	_apply_personality()


func _apply_personality() -> void:
	match colour_type:
		ColourData.ColourType.BLUE:
			reaction_delay = 0.05
			accuracy = 0.85
			move_speed = 450.0
			prediction_strength = 0.3

		ColourData.ColourType.GREEN:
			reaction_delay = 0.25
			accuracy = 0.95
			move_speed = 300.0
			prediction_strength = 0.7

		ColourData.ColourType.RED:
			reaction_delay = 0.08
			accuracy = 0.9
			move_speed = 400.0
			prediction_strength = 0.6
			should_deflect_own_colour = true

		ColourData.ColourType.YELLOW:
			reaction_delay = 0.15
			accuracy = 0.8
			move_speed = 350.0
			prediction_strength = 0.4
			ignore_purple = true

		ColourData.ColourType.PURPLE:
			reaction_delay = 0.5
			accuracy = 0.3
			move_speed = 200.0
			prediction_strength = 0.1

		_:  # ORANGE, CYAN, PINK — balanced defaults
			reaction_delay = 0.12
			accuracy = 0.8
			move_speed = 380.0
			prediction_strength = 0.5


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
		var t := _calculate_threat(ticket)
		if t > best_threat:
			best_threat = t
			best_ticket = ticket

	current_target_ticket = best_ticket
	if current_target_ticket:
		_calculate_target_offset()


func _calculate_threat(ticket: Node2D) -> float:
	if ignore_purple and ticket.colour_type == ColourData.ColourType.PURPLE:
		return -1.0

	var is_own: bool = ticket.colour_type == colour_type
	if is_own and not should_deflect_own_colour:
		return -0.5  # Let own colour pass through

	var distance: float = (ticket.global_position - global_position).length()

	# Generic approach speed: positive when ticket moves toward this zone.
	var approach_speed: float = ticket.linear_velocity.dot(outward_dir)
	if approach_speed <= 0:
		return -1.0

	var threat: float = approach_speed / (distance + 100.0)

	# Blue panic: degrades accuracy when many tickets are active.
	if colour_type == ColourData.ColourType.BLUE:
		var count := get_tree().get_nodes_in_group("tickets").size()
		is_panicking = count >= panic_threshold
		if is_panicking:
			threat *= randf_range(0.5, 1.5)

	return threat


func _calculate_target_offset() -> void:
	if not current_target_ticket:
		return

	var predicted_pos: Vector2 = current_target_ticket.global_position \
		+ current_target_ticket.linear_velocity * prediction_strength

	if randf() > accuracy:
		# Jitter perpendicular to the slide axis
		var perp := move_direction.rotated(PI / 2.0)
		predicted_pos += perp * randf_range(-100.0, 100.0)

	target_offset = (predicted_pos - zone_centre).dot(move_direction)
	target_offset = clampf(target_offset, min_offset, max_offset)


func _move_toward_target(delta: float) -> void:
	var current_t := get_slide_offset()
	var dir: float = sign(target_offset - current_t)
	var dist: float = abs(target_offset - current_t)

	if dist < 5.0:
		return

	var step: float = min(move_speed * delta, dist)
	set_slide_offset(current_t + dir * step)
