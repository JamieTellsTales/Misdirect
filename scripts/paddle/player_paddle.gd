extends "res://scripts/paddle/paddle.gd"
class_name PlayerPaddle
## Player-controlled paddle with keyboard/mouse input

@export var move_speed: float = 500.0

var min_pos: float = 0.0
var max_pos: float = 0.0
var locked_pos: float = 0.0  # Position on the locked axis


func _ready() -> void:
	super._ready()
	_calculate_movement_bounds()
	# Store the initial position on the axis we don't move
	if is_horizontal:
		locked_pos = position.y
	else:
		locked_pos = position.x


func _calculate_movement_bounds() -> void:
	# Calculate movement limits based on fixed zone length
	# Paddles can only move within their zone (centered on screen edge)
	var arena_width: float = 1280.0
	var arena_height: float = 720.0
	var zone_length: float = 400.0  # Fixed zone width for fairness
	var half_length: float = paddle_length / 2.0
	var half_zone: float = zone_length / 2.0

	if is_horizontal:
		# Horizontal paddle moves left/right (X axis) within zone
		var center_x: float = arena_width / 2.0
		min_pos = center_x - half_zone + half_length
		max_pos = center_x + half_zone - half_length
	else:
		# Vertical paddle moves up/down (Y axis) within zone
		var center_y: float = arena_height / 2.0
		min_pos = center_y - half_zone + half_length
		max_pos = center_y + half_zone - half_length


func _physics_process(delta: float) -> void:
	var input_dir := _get_input_direction()

	if is_horizontal:
		# Move along X axis only
		velocity.x = input_dir * move_speed
		velocity.y = 0
	else:
		# Move along Y axis only
		velocity.x = 0
		velocity.y = input_dir * move_speed

	move_and_slide()
	_clamp_and_lock_position()


func _get_input_direction() -> float:
	var direction: float = 0.0

	# Support both arrow keys and WASD
	if is_horizontal:
		# Left/Right or A/D
		if Input.is_action_pressed("move_left"):
			direction -= 1.0
		if Input.is_action_pressed("move_right"):
			direction += 1.0
	else:
		# Up/Down or W/S
		if Input.is_action_pressed("move_up"):
			direction -= 1.0
		if Input.is_action_pressed("move_down"):
			direction += 1.0

	return direction


func _clamp_and_lock_position() -> void:
	if is_horizontal:
		# Clamp X movement, lock Y position
		position.x = clampf(position.x, min_pos, max_pos)
		position.y = locked_pos
	else:
		# Clamp Y movement, lock X position
		position.y = clampf(position.y, min_pos, max_pos)
		position.x = locked_pos
