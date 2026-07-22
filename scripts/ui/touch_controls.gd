extends Node2D
class_name TouchControls
## On-screen touch controls, shown only on touch devices.
##   • Drag anywhere (except the button) to move the paddle — it tracks your finger.
##   • Hold the corner button to use your active (SPACE-slot) power-up.
## Multitouch: movement and the power-up button use separate finger ids, so you
## can do both at once. Positions are converted to world space so they line up
## with the arena in both landscape and portrait.

var paddle: Node = null   # player paddle (may be freed on zone collapse)

var _move_finger:    int = -1
var _powerup_finger: int = -1
var _button_center:  Vector2 = Vector2.ZERO
var _button_radius:  float = 100.0
var _button_visible: bool = false


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	set_process_unhandled_input(visible)
	set_process(visible)
	z_index = 5


func _process(_delta: float) -> void:
	queue_redraw()


func _screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _active_powerup_id() -> String:
	if GameConfig.power_up_slots.is_empty():
		return ""
	var id: String = GameConfig.power_up_slots[0]
	if id != "" and GameConfig.powerup_kind(id) == "active":
		return id
	return ""


func _paddle_valid() -> bool:
	return paddle != null and is_instance_valid(paddle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var wp: Vector2 = _screen_to_world(event.position)
		if event.pressed:
			if _button_visible and wp.distance_to(_button_center) <= _button_radius:
				_powerup_finger = event.index
				if _paddle_valid():
					paddle.touch_powerup_held = true
			else:
				_move_finger = event.index
				if _paddle_valid():
					paddle.touch_move_to(wp)
		else:
			if event.index == _powerup_finger:
				_powerup_finger = -1
				if _paddle_valid():
					paddle.touch_powerup_held = false
			elif event.index == _move_finger:
				_move_finger = -1
				if _paddle_valid():
					paddle.touch_move_end()
	elif event is InputEventScreenDrag:
		if event.index == _move_finger and _paddle_valid():
			paddle.touch_move_to(_screen_to_world(event.position))


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_button_radius = clampf(vp.x * 0.12, 90.0, 220.0)

	var pid: String = _active_powerup_id()
	_button_visible = pid != ""
	if not _button_visible:
		return

	var m: float = _button_radius * 0.5
	_button_center = Vector2(vp.x - _button_radius - m, vp.y - _button_radius - m)

	var held: bool = _paddle_valid() and paddle.touch_powerup_held
	draw_circle(_button_center, _button_radius,
		Color(0.3, 0.6, 1.0, 0.45 if held else 0.22), true, -1.0, true)
	draw_arc(_button_center, _button_radius, 0, TAU, 48,
		Color(0.55, 0.75, 1.0, 0.95 if held else 0.7), 3.0, true)

	var font := FontManager.get_font()
	var label: String = _powerup_label(pid)
	var fsz: int = int(_button_radius * 0.26)
	var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	draw_string(font, _button_center + Vector2(-lw / 2.0, fsz * 0.35), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)


func _powerup_label(id: String) -> String:
	for pu in GameConfig.POWER_UPS:
		if pu["id"] == id:
			return pu["label"]
	return id
