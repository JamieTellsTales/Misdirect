extends Node2D
class_name ModeSelect
## Mode selection screen — shown before map select.
## Player picks Normal, Endless, or Elimination.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

const MODES: Array = [
	{
		"id": "normal",
		"label": "Normal",
		"desc": ["Timed round.", "Highest score wins."],
		"color": Color(0.4, 0.85, 0.4, 1.0),
	},
	{
		"id": "endless",
		"label": "Endless",
		"desc": ["No timer. 3 lives.", "Wrong catches cost a life.", "Score 100 pts to gain one back."],
		"color": Color(0.4, 0.65, 1.0, 1.0),
	},
	{
		"id": "elimination",
		"label": "Elimination",
		"desc": ["Everyone starts with 3 lives.", "Wrong catches cost a life.", "Zero lives? Your zone seals shut.", "Last zone standing wins."],
		"color": Color(1.0, 0.45, 0.35, 1.0),
	},
]

var selected_index: int = 0
var _card_rects: Array = []
var _confirm_rect: Rect2 = Rect2()
var _back_rect: Rect2 = Rect2()
var _hover_confirm: bool = false
var _hover_back: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for i in MODES.size():
		if MODES[i]["id"] == GameConfig.game_mode:
			selected_index = i
			break


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = get_global_mouse_position()
		_hover_confirm = _confirm_rect.has_point(pos)
		_hover_back    = _back_rect.has_point(pos)
		for i in _card_rects.size():
			if _card_rects[i].has_point(pos):
				if selected_index != i:
					selected_index = i
					AudioManager.play_button_hover()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = get_global_mouse_position()
		for i in _card_rects.size():
			if _card_rects[i].has_point(pos):
				selected_index = i
				_activate()
				return
		if _confirm_rect.has_point(pos):
			_activate()
			return
		if _back_rect.has_point(pos):
			_go_back()
			return

	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		selected_index = (selected_index - 1 + MODES.size()) % MODES.size()
		AudioManager.play_button_hover()

	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		selected_index = (selected_index + 1) % MODES.size()
		AudioManager.play_button_hover()

	if event.is_action_pressed("ui_accept"):
		_activate()

	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _activate() -> void:
	AudioManager.play_button_click()
	GameConfig.game_mode = MODES[selected_index]["id"]
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _go_back() -> void:
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _draw() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var cx: float = sw / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))

	# Title
	var title      := "SELECT GAME MODE"
	var title_size := 40
	var title_w    := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0 + 2, 82),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.45))
	draw_string(font, Vector2(cx - title_w / 2.0, 80),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	# Mode cards
	var card_w: float  = 290.0
	var card_h: float  = 220.0
	var card_gap: float = 30.0
	var total_w: float = MODES.size() * card_w + (MODES.size() - 1) * card_gap
	var cards_x: float = cx - total_w / 2.0
	var cards_y: float = sh / 2.0 - card_h / 2.0 - 30.0

	_card_rects.clear()

	for i in MODES.size():
		var mode: Dictionary = MODES[i]
		var bx: float   = cards_x + i * (card_w + card_gap)
		var by: float   = cards_y
		var is_sel: bool = i == selected_index
		var col: Color   = mode["color"]
		var card_rect := Rect2(bx, by, card_w, card_h)
		_card_rects.append(card_rect)

		# Card background
		var bg_alpha: float = 0.18 if is_sel else 0.0
		draw_rect(card_rect, Color(col.r * bg_alpha, col.g * bg_alpha, col.b * bg_alpha + 0.1, 1.0))
		draw_rect(card_rect, col if is_sel else Color(0.35, 0.35, 0.48, 1.0), false, 2.5 if is_sel else 1.5)

		# Mode label
		var lbl_size := 30
		var lbl_w    := font.get_string_size(mode["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_size).x
		var lbl_col: Color = col if is_sel else Color(0.6, 0.6, 0.68, 1.0)
		draw_string(font, Vector2(bx + card_w / 2.0 - lbl_w / 2.0, by + 48.0),
			mode["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_size, lbl_col)

		# Separator under label
		draw_line(Vector2(bx + 24, by + 58), Vector2(bx + card_w - 24, by + 58),
			Color(col, 0.35) if is_sel else Color(0.3, 0.3, 0.4, 0.4), 1.0)

		# Description lines
		var desc_lines: Array = mode["desc"]
		var desc_size: int    = 14
		var desc_col: Color   = Color(0.78, 0.78, 0.85, 1.0) if is_sel else Color(0.42, 0.42, 0.5, 1.0)
		var desc_y: float     = by + 80.0
		for line in desc_lines:
			var line_w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size).x
			draw_string(font, Vector2(bx + card_w / 2.0 - line_w / 2.0, desc_y),
				line, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size, desc_col)
			desc_y += desc_size + 6.0

		# Selected marker
		if is_sel:
			var sel_lbl  := "▶  SELECTED"
			var sel_size := 12
			var sel_w    := font.get_string_size(sel_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, sel_size).x
			draw_string(font, Vector2(bx + card_w / 2.0 - sel_w / 2.0, by + card_h - 18.0),
				sel_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, sel_size, col)

	# Confirm button
	var confirm_lbl  := "CONFIRM →"
	var confirm_size := 24
	var confirm_w    := font.get_string_size(confirm_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, confirm_size).x
	var confirm_x    := cx - confirm_w / 2.0
	var confirm_y    := cards_y + card_h + 44.0
	_confirm_rect = Rect2(confirm_x - 20, confirm_y - confirm_size, confirm_w + 40, confirm_size + 12)
	var confirm_col: Color = Color(0.35, 0.95, 0.45, 1.0) if _hover_confirm else Color(0.3, 0.8, 0.4, 1.0)
	draw_string(font, Vector2(confirm_x, confirm_y),
		confirm_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, confirm_size, confirm_col)

	# Back button
	var back_lbl  := "← BACK"
	var back_size := 18
	var back_w    := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size).x
	var back_x    := cx - back_w / 2.0
	var back_y    := sh - 52.0
	_back_rect = Rect2(back_x - 16, back_y - back_size, back_w + 32, back_size + 10)
	var back_col: Color = Color(0.55, 0.65, 0.85, 1.0) if _hover_back else Color(0.45, 0.55, 0.75, 1.0)
	draw_string(font, Vector2(back_x, back_y),
		back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size, back_col)

	# Hint
	var hint      := "← →  navigate     Enter / click  confirm     ESC — back"
	var hint_size := 13
	var hint_w    := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, sh - 24.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)
