extends "res://scripts/paddle/paddle.gd"
class_name PlayerPaddle
## Player-controlled paddle with keyboard input and power-up support.
## Player is always on the bottom (horizontal) zone, so left/right always maps
## correctly regardless of the map shape.

@export var move_speed: float = 500.0

const GRAVITY_RANGE: float = 220.0
const GRAVITY_FORCE: float = 600.0
var gravity_active:      bool = false
var antigravity_active:  bool = false
var cyclone_active:      bool = false


func _ready() -> void:
	super._ready()
	add_to_group("player_paddle")


func _physics_process(_delta: float) -> void:
	var input_dir := _get_input_direction()

	# Move along move_direction (always horizontal for player) with physics velocity
	# so the CharacterBody2D velocity is correct for deflection response.
	velocity = move_direction * input_dir * move_speed
	move_and_slide()

	# Snap back onto the constrained axis (move_and_slide can drift).
	set_slide_offset(get_slide_offset())

	# Hold-activated power-ups: check each slot key.
	gravity_active     = _is_slot_key_held("gravity")
	antigravity_active = _is_slot_key_held("anti_gravity")
	cyclone_active     = _is_slot_key_held("cyclone")

	if gravity_active:
		_apply_gravity()
	if antigravity_active:
		_apply_antigravity()
	if cyclone_active:
		_apply_cyclone()
	queue_redraw()


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


func _apply_antigravity() -> void:
	## Repels all balls within range away from the paddle.
	var range_sq: float = GRAVITY_RANGE * GRAVITY_RANGE
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = global_position - ball.global_position
		if offset.length_squared() <= range_sq:
			ball.apply_central_force(-offset.normalized() * GRAVITY_FORCE)


func _apply_cyclone() -> void:
	## Spins all balls in range tangentially around the paddle position.
	var range_sq: float = GRAVITY_RANGE * GRAVITY_RANGE
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = ball.global_position - global_position
		if offset.length_squared() <= range_sq and offset.length_squared() > 0.0:
			# Perpendicular to the offset vector (clockwise spin)
			var tangent: Vector2 = Vector2(-offset.y, offset.x).normalized()
			ball.apply_central_force(tangent * GRAVITY_FORCE * 1.5)


func _is_slot_key_held(pu_id: String) -> bool:
	## Returns true if the slot containing pu_id has its activation key held.
	for slot_idx in GameConfig.POWER_UP_SLOT_DEFS.size():
		if GameConfig.power_up_slots[slot_idx] == pu_id:
			var def: Dictionary = GameConfig.POWER_UP_SLOT_DEFS[slot_idx]
			return Input.is_key_pressed(def["key_primary"]) or Input.is_key_pressed(def["key_alt"])
	return false


func _draw() -> void:
	super._draw()

	if gravity_active:
		# Blue-tinted inward pull ring
		draw_circle(Vector2.ZERO, GRAVITY_RANGE, Color(0.3, 0.6, 1.0, 0.10))
		draw_arc(Vector2.ZERO, GRAVITY_RANGE, 0, TAU, 48, Color(0.3, 0.6, 1.0, 0.55), 2.0)

	if antigravity_active:
		# Orange repulsion ring with outward burst lines
		draw_circle(Vector2.ZERO, GRAVITY_RANGE, Color(1.0, 0.45, 0.1, 0.10))
		draw_arc(Vector2.ZERO, GRAVITY_RANGE, 0, TAU, 48, Color(1.0, 0.5, 0.15, 0.7), 2.5)
		for i in 8:
			var angle: float = i * TAU / 8.0
			var inner: Vector2 = Vector2.from_angle(angle) * (GRAVITY_RANGE * 0.82)
			var outer: Vector2 = Vector2.from_angle(angle) * (GRAVITY_RANGE * 1.05)
			draw_line(inner, outer, Color(1.0, 0.5, 0.15, 0.55), 1.5)

	if cyclone_active:
		# Purple spinning-arc ring
		draw_circle(Vector2.ZERO, GRAVITY_RANGE, Color(0.65, 0.2, 1.0, 0.10))
		draw_arc(Vector2.ZERO, GRAVITY_RANGE, 0, TAU, 48, Color(0.7, 0.3, 1.0, 0.7), 2.5)
		# Spiral arcs to suggest rotation
		for i in 4:
			var start_a: float = i * TAU / 4.0
			var end_a:   float = start_a + TAU * 0.18
			draw_arc(Vector2.ZERO, GRAVITY_RANGE * 0.6, start_a, end_a, 12, Color(0.75, 0.4, 1.0, 0.5), 2.0)
			draw_arc(Vector2.ZERO, GRAVITY_RANGE * 0.35, start_a + 0.4, end_a + 0.4, 10, Color(0.75, 0.4, 1.0, 0.35), 1.5)
