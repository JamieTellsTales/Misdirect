extends "res://scripts/paddle/paddle.gd"
class_name PlayerPaddle
## Player-controlled paddle with keyboard input and power up support

@export var move_speed: float = 500.0

var min_pos: float = 0.0
var max_pos: float = 0.0
var locked_pos: float = 0.0

# Gravity power up visual
var gravity_active: bool = false
const GRAVITY_RANGE: float = 220.0
const GRAVITY_FORCE: float = 600.0


func _ready() -> void:
	super._ready()
	add_to_group("player_paddle")
	_calculate_movement_bounds()
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


func _physics_process(delta: float) -> void:
	var input_dir := _get_input_direction()

	if is_horizontal:
		velocity.x = input_dir * move_speed
		velocity.y = 0
	else:
		velocity.x = 0
		velocity.y = input_dir * move_speed

	move_and_slide()
	_clamp_and_lock_position()

	# Gravity power up: spacebar pulls nearby balls toward this paddle
	if GameConfig.selected_power_up == "gravity":
		gravity_active = Input.is_action_pressed("power_up")
		if gravity_active:
			_apply_gravity()
		queue_redraw()
	else:
		gravity_active = false


func _get_input_direction() -> float:
	var direction: float = 0.0

	if is_horizontal:
		if Input.is_action_pressed("move_left"):
			direction -= 1.0
		if Input.is_action_pressed("move_right"):
			direction += 1.0
	else:
		if Input.is_action_pressed("move_up"):
			direction -= 1.0
		if Input.is_action_pressed("move_down"):
			direction += 1.0

	return direction


func _clamp_and_lock_position() -> void:
	if is_horizontal:
		position.x = clampf(position.x, min_pos, max_pos)
		position.y = locked_pos
	else:
		position.y = clampf(position.y, min_pos, max_pos)
		position.x = locked_pos


func _apply_gravity() -> void:
	var range_sq: float = GRAVITY_RANGE * GRAVITY_RANGE
	for ticket in get_tree().get_nodes_in_group("tickets"):
		var offset: Vector2 = global_position - ticket.global_position
		if offset.length_squared() <= range_sq:
			ticket.apply_central_force(offset.normalized() * GRAVITY_FORCE)


func _draw() -> void:
	# Draw base paddle
	super._draw()

	# Gravity power up: show active range when spacebar is held
	if GameConfig.selected_power_up == "gravity" and gravity_active:
		var ring_color := Color(paddle_color, 0.35)
		draw_arc(Vector2.ZERO, GRAVITY_RANGE, 0, TAU, 48, ring_color, 2.0)
		var glow := Color(paddle_color, 0.15)
		draw_circle(Vector2.ZERO, GRAVITY_RANGE, glow)
