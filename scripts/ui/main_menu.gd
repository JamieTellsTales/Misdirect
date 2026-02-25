extends Node2D
class_name MainMenu
## Title screen — drawn entirely in _draw(), consistent with rest of codebase

const ARENA_WIDTH: float = 1280.0
const ARENA_HEIGHT: float = 720.0

const MENU_ITEMS: Array = ["PLAY", "SETTINGS", "ACHIEVEMENTS", "EXIT"]
const MENU_COLORS: Array = [
	Color.FOREST_GREEN,
	Color.DODGER_BLUE,
	Color.GOLD,
	Color.CRIMSON,
]

var selected_index: int = 0
var popup_state: int = 0  # 0 = none, 1 = settings, 2 = achievements

var title_pulse: float = 0.0
var item_rects: Array = []  # Rect2 per menu item for mouse hit-testing


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	title_pulse += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if popup_state != 0:
		if event.is_action_pressed("ui_cancel"):
			popup_state = 0
		return

	if event is InputEventMouseMotion:
		_update_hover(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		selected_index = (selected_index - 1 + MENU_ITEMS.size()) % MENU_ITEMS.size()

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		selected_index = (selected_index + 1) % MENU_ITEMS.size()

	if event.is_action_pressed("ui_accept"):
		_activate(selected_index)


func _update_hover(pos: Vector2) -> void:
	for i in range(item_rects.size()):
		if item_rects[i].has_point(pos):
			selected_index = i
			return


func _handle_click(pos: Vector2) -> void:
	for i in range(item_rects.size()):
		if item_rects[i].has_point(pos):
			_activate(i)
			return


func _activate(index: int) -> void:
	match index:
		0:
			GameConfig.reset()
			get_tree().change_scene_to_file("res://scenes/pre_game_config.tscn")
		1:
			popup_state = 1
		2:
			popup_state = 2
		3:
			get_tree().quit()


func _draw() -> void:
	_draw_background()
	_draw_title()
	_draw_menu()
	if popup_state != 0:
		_draw_popup()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color(0.07, 0.07, 0.12, 1.0))

	# Faint arena-style octagon as background decoration
	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var half: float = 300.0
	var inset: float = 100.0
	var dec_points: PackedVector2Array = [
		Vector2(cx - half, cy - inset),
		Vector2(cx - inset, cy - half),
		Vector2(cx + inset, cy - half),
		Vector2(cx + half, cy - inset),
		Vector2(cx + half, cy + inset),
		Vector2(cx + inset, cy + half),
		Vector2(cx - inset, cy + half),
		Vector2(cx - half, cy + inset),
	]
	var dec_color := Color(0.18, 0.18, 0.28, 1.0)
	for i in range(dec_points.size()):
		draw_line(dec_points[i], dec_points[(i + 1) % dec_points.size()], dec_color, 1.5)

	# Subtle coloured corner accents matching department colours
	var corner_alpha: float = 0.12
	draw_circle(Vector2(0, 0), 200, Color(Color.DODGER_BLUE, corner_alpha))
	draw_circle(Vector2(ARENA_WIDTH, 0), 200, Color(Color.CRIMSON, corner_alpha))
	draw_circle(Vector2(0, ARENA_HEIGHT), 200, Color(Color.FOREST_GREEN, corner_alpha))
	draw_circle(Vector2(ARENA_WIDTH, ARENA_HEIGHT), 200, Color(Color.GOLD, corner_alpha))


func _draw_title() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0

	var title := "MISDIRECT"
	var title_size: int = 72
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var pulse: float = (sin(title_pulse * 1.8) + 1.0) / 2.0
	var title_color := Color.WHITE.lerp(Color(0.75, 0.85, 1.0, 1.0), pulse * 0.25)

	draw_string(font, Vector2(cx - title_w / 2.0 + 3, 173),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(cx - title_w / 2.0, 170),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	var sub := "Every deflection is a decision"
	var sub_size: int = 20
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2(cx - sub_w / 2.0, 200),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.45, 0.45, 0.58, 1.0))


func _draw_menu() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0
	var item_font_size: int = 36
	var spacing: float = 68.0
	var start_y: float = 310.0

	item_rects.clear()

	for i in range(MENU_ITEMS.size()):
		var label: String = MENU_ITEMS[i]
		var item_y: float = start_y + i * spacing
		var is_sel: bool = i == selected_index

		var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, item_font_size).x
		var label_x: float = cx - label_w / 2.0

		# Mouse hit rect
		item_rects.append(Rect2(label_x - 30, item_y - item_font_size, label_w + 60, item_font_size + 14))

		var col: Color = MENU_COLORS[i] if is_sel else Color(0.45, 0.45, 0.52, 1.0)

		# Selection chevron
		if is_sel:
			draw_string(font, Vector2(label_x - 32, item_y),
				"›", HORIZONTAL_ALIGNMENT_LEFT, -1, item_font_size, col)

		# Shadow then text
		draw_string(font, Vector2(label_x + 2, item_y + 2),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, item_font_size, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(label_x, item_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, item_font_size, col)

	# Navigation hint at bottom
	var hint := "↑ ↓  navigate     Enter / click  select"
	var hint_size: int = 14
	var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, ARENA_HEIGHT - 36.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))


func _draw_popup() -> void:
	# Dim
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color(0, 0, 0, 0.6))

	# Panel
	var box_w: float = 400.0
	var box_h: float = 170.0
	var bx: float = ARENA_WIDTH / 2.0 - box_w / 2.0
	var by: float = ARENA_HEIGHT / 2.0 - box_h / 2.0
	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.07, 0.07, 0.12, 0.97))
	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.5, 0.5, 0.62, 1.0), false, 2.0)

	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0

	var heading: String = MENU_ITEMS[popup_state]
	var h_size: int = 30
	var h_w := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, h_size).x
	draw_string(font, Vector2(cx - h_w / 2.0, by + 55.0),
		heading, HORIZONTAL_ALIGNMENT_LEFT, -1, h_size, Color.WHITE)

	var sub := "Coming soon"
	var s_size: int = 18
	var s_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, s_size).x
	draw_string(font, Vector2(cx - s_w / 2.0, by + 95.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, s_size, Color(0.45, 0.45, 0.58, 1.0))

	var back := "ESC — back"
	var b_size: int = 14
	var b_w := font.get_string_size(back, HORIZONTAL_ALIGNMENT_LEFT, -1, b_size).x
	draw_string(font, Vector2(cx - b_w / 2.0, by + box_h - 22.0),
		back, HORIZONTAL_ALIGNMENT_LEFT, -1, b_size, Color(0.35, 0.35, 0.45, 1.0))
