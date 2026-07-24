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

# Touch control (set by TouchControls). Two schemes:
#   • buttons — touch_dir is -1 / 0 / +1 (hold left/right), moves like the keyboard.
#   • slide   — touch_offset_active + a target offset the paddle snaps to (1:1 pad).
var touch_powerup_held: bool = false
var touch_dir: float = 0.0
var _touch_offset_active: bool = false
var _touch_offset_target: float = 0.0


func touch_set_dir(d: float) -> void:
	touch_dir = clampf(d, -1.0, 1.0)


func touch_set_fraction(f: float) -> void:
	## Absolute slide pad: 0 = full left, 1 = full right.
	_touch_offset_active = true
	_touch_offset_target = lerpf(min_offset, max_offset, clampf(f, 0.0, 1.0))


func touch_clear() -> void:
	touch_dir = 0.0
	_touch_offset_active = false


func _ready() -> void:
	super._ready()
	add_to_group("player_paddle")
	# Hyper Paddle (passive): double movement speed.
	if GameConfig.has_power_up_in_slot("hyper_paddle"):
		move_speed *= 2.0


func _physics_process(delta: float) -> void:
	if _touch_offset_active:
		# Slide pad — snap to the target offset (1:1), with a capped velocity for
		# the ball's deflection blend.
		var cur: float = get_slide_offset()
		var raw_v: float = (_touch_offset_target - cur) / maxf(delta, 0.0001)
		var maxv: float = move_speed * 3.0 * arena_scale
		velocity = move_direction * clampf(raw_v, -maxv, maxv)
		set_slide_offset(_touch_offset_target)
	else:
		# Keyboard, or the touch left/right buttons (touch_dir).
		var input_dir: float = touch_dir if touch_dir != 0.0 else _get_input_direction()
		velocity = move_direction * input_dir * move_speed * arena_scale
		move_and_slide()
		set_slide_offset(get_slide_offset())

	# Hold-activated power-ups: keyboard key OR the on-screen touch button.
	gravity_active     = _is_powerup_held("gravity")
	antigravity_active = _is_powerup_held("anti_gravity")
	cyclone_active     = _is_powerup_held("cyclone")

	if gravity_active:
		_apply_gravity()
	if antigravity_active:
		_apply_antigravity()
	if cyclone_active:
		_apply_cyclone()
	queue_redraw()


func _is_powerup_held(pu_id: String) -> bool:
	if touch_powerup_held and not GameConfig.power_up_slots.is_empty() \
			and GameConfig.power_up_slots[0] == pu_id:
		return true
	return _is_slot_key_held(pu_id)


func _get_input_direction() -> float:
	var dir: float = 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	return dir


func _apply_gravity() -> void:
	var g_range: float = GRAVITY_RANGE * arena_scale
	var range_sq: float = g_range * g_range
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = global_position - ball.global_position
		if offset.length_squared() <= range_sq:
			ball.apply_central_force(offset.normalized() * GRAVITY_FORCE * arena_scale)


func _apply_antigravity() -> void:
	## Repels all balls within range away from the paddle.
	var g_range: float = GRAVITY_RANGE * arena_scale
	var range_sq: float = g_range * g_range
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = global_position - ball.global_position
		if offset.length_squared() <= range_sq:
			ball.apply_central_force(-offset.normalized() * GRAVITY_FORCE * arena_scale)


func _apply_cyclone() -> void:
	## Spins all balls in range tangentially around the paddle position.
	var g_range: float = GRAVITY_RANGE * arena_scale
	var range_sq: float = g_range * g_range
	for ball in get_tree().get_nodes_in_group("balls"):
		var offset: Vector2 = ball.global_position - global_position
		if offset.length_squared() <= range_sq and offset.length_squared() > 0.0:
			# Perpendicular to the offset vector (clockwise spin)
			var tangent: Vector2 = Vector2(-offset.y, offset.x).normalized()
			ball.apply_central_force(tangent * GRAVITY_FORCE * arena_scale * 1.5)


func _is_slot_key_held(pu_id: String) -> bool:
	## Returns true if the active slot holding pu_id has its key held.
	## Only active-kind slots have keys; passive slots are always-on and skipped.
	for slot_idx in GameConfig.POWER_UP_SLOT_DEFS.size():
		if GameConfig.power_up_slots[slot_idx] == pu_id:
			var def: Dictionary = GameConfig.POWER_UP_SLOT_DEFS[slot_idx]
			if def.get("kind", "active") != "active":
				continue
			return Input.is_key_pressed(def["key_primary"]) or Input.is_key_pressed(def.get("key_alt", KEY_NONE))
	return false


func _draw() -> void:
	super._draw()

	var g_range: float = GRAVITY_RANGE * arena_scale

	if gravity_active:
		# Blue-tinted inward pull ring
		draw_circle(Vector2.ZERO, g_range, Color(0.3, 0.6, 1.0, 0.10))
		draw_arc(Vector2.ZERO, g_range, 0, TAU, 48, Color(0.3, 0.6, 1.0, 0.55), 2.0)

	if antigravity_active:
		# Orange repulsion ring with outward burst lines
		draw_circle(Vector2.ZERO, g_range, Color(1.0, 0.45, 0.1, 0.10))
		draw_arc(Vector2.ZERO, g_range, 0, TAU, 48, Color(1.0, 0.5, 0.15, 0.7), 2.5)
		for i in 8:
			var angle: float = i * TAU / 8.0
			var inner: Vector2 = Vector2.from_angle(angle) * (g_range * 0.82)
			var outer: Vector2 = Vector2.from_angle(angle) * (g_range * 1.05)
			draw_line(inner, outer, Color(1.0, 0.5, 0.15, 0.55), 1.5)

	if cyclone_active:
		# Purple spinning-arc ring
		draw_circle(Vector2.ZERO, g_range, Color(0.65, 0.2, 1.0, 0.10))
		draw_arc(Vector2.ZERO, g_range, 0, TAU, 48, Color(0.7, 0.3, 1.0, 0.7), 2.5)
		# Spiral arcs to suggest rotation
		for i in 4:
			var start_a: float = i * TAU / 4.0
			var end_a:   float = start_a + TAU * 0.18
			draw_arc(Vector2.ZERO, g_range * 0.6, start_a, end_a, 12, Color(0.75, 0.4, 1.0, 0.5), 2.0)
			draw_arc(Vector2.ZERO, g_range * 0.35, start_a + 0.4, end_a + 0.4, 10, Color(0.75, 0.4, 1.0, 0.35), 1.5)
