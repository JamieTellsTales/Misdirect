extends Node2D
class_name TouchControls
## On-screen touch controls, shown only on touch devices. Two schemes (player's
## choice in Settings → Colours & Accessibility):
##   • joystick — touch anywhere in the lower band; a floating stick appears and
##                you push left/right to move (analog: further = faster).
##   • slide    — a pad along the bottom; your finger maps 1:1 to paddle position.
## Plus a power-up button (bottom-right, when an active power-up is equipped) and
## a pause button (top-right). Uses _input so Control nodes can't swallow touches.
## event.position is already canvas-space, so it's used raw.

signal pause_requested

var paddle: Node = null

# Joystick
var _joy_finger: int = -1
var _joy_base:   Vector2 = Vector2.ZERO
var _joy_knob:   Vector2 = Vector2.ZERO
var _joy_max:    float = 120.0

# Slide pad
var _slide_finger: int = -1
var _slide_x0: float = 0.0
var _slide_w:  float = 100.0
var _slide_y:  float = 0.0
var _slide_x:  float = 0.0
var _slide_knob: float = 0.5

# Corner buttons
var _powerup_finger: int = -1
var _pause_center: Vector2 = Vector2.ZERO
var _pause_radius: float = 44.0
var _pu_center_l: Vector2 = Vector2.ZERO   # power-up buttons on both bottom corners
var _pu_center_r: Vector2 = Vector2.ZERO
var _pu_radius:  float = 90.0
var _pu_visible: bool = false

var _hint_time: float = 6.0


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	set_process_input(visible)
	set_process(visible)
	z_index = 5


func _scheme() -> String:
	return "slide" if SettingsManager.touch_scheme == "slide" else "joystick"


func _process(delta: float) -> void:
	# Re-apply the joystick each frame so movement is sustained while held.
	if _joy_finger != -1:
		_apply_joy()
	if _hint_time > 0.0 and not _moving():
		_hint_time -= delta
	queue_redraw()


func _moving() -> bool:
	return _joy_finger != -1 or _slide_finger != -1


func _paddle_valid() -> bool:
	return paddle != null and is_instance_valid(paddle)


func _active_powerup_id() -> String:
	if GameConfig.power_up_slots.is_empty():
		return ""
	var id: String = GameConfig.power_up_slots[0]
	if id != "" and GameConfig.powerup_kind(id) == "active":
		return id
	return ""


# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			_joy_knob = event.position
			_apply_joy()
		elif event.index == _slide_finger:
			_slide_x = event.position.x
			_update_slide()


func _on_press(index: int, wp: Vector2) -> void:
	if wp.distance_to(_pause_center) <= _pause_radius:
		pause_requested.emit()
		return
	if _pu_visible and (wp.distance_to(_pu_center_l) <= _pu_radius or wp.distance_to(_pu_center_r) <= _pu_radius):
		_powerup_finger = index
		if _paddle_valid():
			paddle.touch_powerup_held = true
		return

	# Only the lower part of the screen is a movement control (play field stays tap-safe).
	var vp: Vector2 = get_viewport_rect().size
	if wp.y < vp.y * 0.45:
		return

	_hint_time = 0.0
	if _scheme() == "slide":
		_slide_finger = index
		_slide_x = wp.x
		_update_slide()
	else:
		_joy_finger = index
		_joy_base = wp
		_joy_knob = wp
		_apply_joy()


func _on_release(index: int) -> void:
	if index == _powerup_finger:
		_powerup_finger = -1
		if _paddle_valid():
			paddle.touch_powerup_held = false
	elif index == _joy_finger:
		_joy_finger = -1
		if _paddle_valid():
			paddle.touch_clear()
	elif index == _slide_finger:
		_slide_finger = -1
		if _paddle_valid():
			paddle.touch_clear()


func _apply_joy() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_joy_max = minf(vp.x, vp.y) * 0.085
	# Digital: any push past the dead zone = full speed in that direction.
	var dx: float = _joy_knob.x - _joy_base.x
	var dead: float = _joy_max * 0.18
	var dir: float = 0.0
	if dx > dead:
		dir = 1.0
	elif dx < -dead:
		dir = -1.0
	if _paddle_valid():
		paddle.touch_set_dir(dir)


func _update_slide() -> void:
	_slide_knob = clampf((_slide_x - _slide_x0) / maxf(_slide_w, 1.0), 0.0, 1.0)
	if _paddle_valid():
		paddle.touch_set_fraction(_slide_knob)


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var short: float = minf(vp.x, vp.y)

	_draw_hint(vp, short)

	# Pause (top-right)
	_pause_radius = clampf(short * 0.05, 34.0, 80.0)
	var pgap: float = _pause_radius * 0.7
	_pause_center = Vector2(vp.x - _pause_radius - pgap, _pause_radius + pgap)
	_draw_pause()

	# Power-up (both side edges, mid-height) — only when an active power-up is
	# equipped. In portrait the arena fills the top, so drop the buttons into the
	# lower empty band; in landscape the sides are clear, so keep them centred.
	var pid: String = _active_powerup_id()
	_pu_visible = pid != ""
	_pu_radius = clampf(short * 0.075, 48.0, 110.0)
	if _pu_visible:
		var pug: float = _pu_radius * 0.5
		var pu_y: float = vp.y * (0.58 if vp.y > vp.x else 0.32)
		_pu_center_l = Vector2(_pu_radius + pug, pu_y)
		_pu_center_r = Vector2(vp.x - _pu_radius - pug, pu_y)
		_draw_powerup(pid, _pu_center_l)
		_draw_powerup(pid, _pu_center_r)

	if _scheme() == "slide":
		_draw_slide_pad(vp, short)
	elif _joy_finger != -1:
		_draw_joystick(short)


func _draw_hint(vp: Vector2, short: float) -> void:
	if _hint_time <= 0.0:
		return
	var font := FontManager.get_font()
	var hint := "Hold and slide to move" if _scheme() == "slide" else "Touch the bottom and push left / right to move"
	var hsz: int = int(short * 0.03)
	var a: float = clampf(_hint_time, 0.0, 1.0) * 0.85
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz).x
	draw_string(font, Vector2(vp.x / 2.0 - hw / 2.0, vp.y * 0.62), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, hsz, Color(0.7, 0.85, 0.75, a))


func _draw_pause() -> void:
	draw_circle(_pause_center, _pause_radius, Color(0.1, 0.1, 0.16, 0.55), true, -1.0, true)
	draw_arc(_pause_center, _pause_radius, 0, TAU, 40, Color(0.6, 0.65, 0.8, 0.8), 2.5, true)
	var bw: float = _pause_radius * 0.16
	var bh: float = _pause_radius * 0.7
	var g: float = _pause_radius * 0.24
	var c := Color(0.85, 0.88, 1.0, 0.9)
	draw_rect(Rect2(_pause_center + Vector2(-g - bw, -bh / 2.0), Vector2(bw, bh)), c)
	draw_rect(Rect2(_pause_center + Vector2(g, -bh / 2.0), Vector2(bw, bh)), c)


func _draw_powerup(pid: String, centre: Vector2) -> void:
	var held: bool = _paddle_valid() and paddle.touch_powerup_held
	draw_circle(centre, _pu_radius, Color(0.3, 0.6, 1.0, 0.45 if held else 0.2), true, -1.0, true)
	draw_arc(centre, _pu_radius, 0, TAU, 48, Color(0.55, 0.75, 1.0, 0.95 if held else 0.65), 3.0, true)
	var font := FontManager.get_font()
	var label := _powerup_label(pid)
	var fsz: int = int(_pu_radius * 0.26)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	draw_string(font, centre + Vector2(-lw / 2.0, fsz * 0.35), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)


func _draw_joystick(short: float) -> void:
	var base_r: float = _joy_max
	draw_circle(_joy_base, base_r, Color(0.4, 0.7, 1.0, 0.12), true, -1.0, true)
	draw_arc(_joy_base, base_r, 0, TAU, 40, Color(0.5, 0.7, 1.0, 0.5), 2.5, true)
	# horizontal guide
	draw_line(_joy_base + Vector2(-base_r, 0), _joy_base + Vector2(base_r, 0), Color(0.6, 0.8, 1.0, 0.3), 1.5, true)
	var d: Vector2 = _joy_knob - _joy_base
	if d.length() > base_r:
		d = d.normalized() * base_r
	var kc: Vector2 = _joy_base + d
	var kr: float = base_r * 0.42
	draw_circle(kc, kr, Color(0.4, 0.75, 1.0, 0.6), true, -1.0, true)
	draw_arc(kc, kr, 0, TAU, 32, Color(0.65, 0.85, 1.0, 0.95), 3.0, true)


func _draw_slide_pad(vp: Vector2, short: float) -> void:
	_slide_y = vp.y - short * 0.11
	_slide_x0 = vp.x * 0.07
	_slide_w = vp.x * 0.82
	var active: bool = _slide_finger != -1
	if not active and _paddle_valid():
		var rng: float = paddle.max_offset - paddle.min_offset
		if rng > 0.0:
			_slide_knob = clampf((paddle.get_slide_offset() - paddle.min_offset) / rng, 0.0, 1.0)

	var track_h: float = short * 0.02
	draw_rect(Rect2(_slide_x0, _slide_y - track_h / 2.0, _slide_w, track_h), Color(0.2, 0.25, 0.35, 0.5))
	draw_rect(Rect2(_slide_x0, _slide_y - track_h / 2.0, _slide_w, track_h), Color(0.45, 0.55, 0.75, 0.6), false, 1.5)

	var knob_r: float = short * 0.05
	var kx: float = _slide_x0 + _slide_knob * _slide_w
	var kc := Vector2(kx, _slide_y)
	draw_circle(kc, knob_r, Color(0.35, 0.7, 1.0, 0.6 if active else 0.35), true, -1.0, true)
	draw_arc(kc, knob_r, 0, TAU, 40, Color(0.55, 0.8, 1.0, 0.95 if active else 0.75), 3.0, true)


func _powerup_label(id: String) -> String:
	for pu in GameConfig.POWER_UPS:
		if pu["id"] == id:
			return pu["label"]
	return id
