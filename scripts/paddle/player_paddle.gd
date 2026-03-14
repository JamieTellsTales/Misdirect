extends "res://scripts/paddle/paddle.gd"
class_name PlayerPaddle
## Player-controlled paddle with keyboard input and power-up support.
## Player is always on the bottom (horizontal) zone, so left/right always maps
## correctly regardless of the map shape.

@export var move_speed: float = 500.0

const GRAVITY_RANGE: float = 220.0
const GRAVITY_FORCE: float = 600.0
var gravity_active: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("player_paddle")


func _physics_process(delta: float) -> void:
	var input_dir := _get_input_direction()

	# Move along move_direction (always horizontal for player) with physics velocity
	# so the CharacterBody2D velocity is correct for deflection response.
	velocity = move_direction * input_dir * move_speed
	move_and_slide()

	# Snap back onto the constrained axis (move_and_slide can drift).
	set_slide_offset(get_slide_offset())

	# Gravity power up: hold SPACE to pull nearby balls toward this paddle.
	if GameConfig.selected_power_up == "gravity":
		gravity_active = Input.is_action_pressed("power_up")
		if gravity_active:
			_apply_gravity()
		queue_redraw()
	else:
		gravity_active = false


func _get_input_direction() -> float:
	var dir: float = 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	return dir


func _apply_gravity() -> void:
	var range_sq: float = GRAVITY_RANGE * GRAVITY_RANGE
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = global_position - ball.global_position
		if offset.length_squared() <= range_sq:
			ball.apply_central_force(offset.normalized() * GRAVITY_FORCE)


func _draw() -> void:
	super._draw()
	if GameConfig.selected_power_up == "gravity" and gravity_active:
		var ring_color := Color(paddle_color, 0.35)
		draw_arc(Vector2.ZERO, GRAVITY_RANGE, 0, TAU, 48, ring_color, 2.0)
		draw_circle(Vector2.ZERO, GRAVITY_RANGE, Color(paddle_color, 0.15))
