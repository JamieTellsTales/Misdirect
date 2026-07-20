extends Node2D
class_name ColourSettings
## Accessibility — assign a colour-blind-friendly colour to each zone (including
## the player's). Choices persist device-level via SettingsManager and apply the
## next time a round is built. Drawn entirely via _draw().

const ColourData = preload("res://scripts/resources/colour_data.gd")
const CornerHUD  = preload("res://scripts/ui/corner_hud.gd")

# Zone identities in display order (player GREEN first so it reads as "yours").
const ZONE_ORDER: Array = [
	ColourData.ColourType.GREEN,
	ColourData.ColourType.BLUE,
	ColourData.ColourType.RED,
	ColourData.ColourType.YELLOW,
	ColourData.ColourType.PURPLE,
	ColourData.ColourType.ORANGE,
	ColourData.ColourType.CYAN,
	ColourData.ColourType.PINK,
]

const ROW_START_Y: float = 158.0
const ROW_H:       float = 52.0
const SWATCH_SIZE: float = 30.0
const SWATCH_GAP:  float = 7.0

var _swatch_rects: Array = []   # [{rect, ct, index}]  index -1 = Default
var _back_rect:  Rect2 = Rect2()
var _reset_rect: Rect2 = Rect2()
var _hover_key:  String = ""
var _sel_row:    int = 0        # keyboard-selected zone row


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_sel_row = (_sel_row + 1) % ZONE_ORDER.size()
		AudioManager.play_button_hover()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_sel_row = (_sel_row - 1 + ZONE_ORDER.size()) % ZONE_ORDER.size()
		AudioManager.play_button_hover()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_cycle_row(_sel_row, 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_cycle_row(_sel_row, -1)


func _cycle_row(row: int, dir: int) -> void:
	## Cycle a zone's choice through [Default, palette 0..N-1].
	var ct: int = ZONE_ORDER[row]
	var n: int = ColourData.ACCESSIBLE_PALETTE.size()
	var cur: int = SettingsManager.get_zone_colour_index(ct)   # -1..n-1
	var next: int = wrapi(cur + 1 + dir, 0, n + 1) - 1          # keep in [-1, n-1]
	SettingsManager.set_zone_colour_index(ct, next)
	AudioManager.play_button_click()


func _update_hover(pos: Vector2) -> void:
	var new_key: String = ""
	if _back_rect.has_point(pos):
		new_key = "back"
	elif _reset_rect.has_point(pos):
		new_key = "reset"
	else:
		for e in _swatch_rects:
			if e.rect.has_point(pos):
				new_key = "sw_%d_%d" % [e.ct, e.index]
				break
	if new_key != _hover_key and new_key != "":
		AudioManager.play_button_hover()
	_hover_key = new_key


func _handle_click(pos: Vector2) -> void:
	if _back_rect.has_point(pos):
		_go_back()
		return
	if _reset_rect.has_point(pos):
		AudioManager.play_button_click()
		SettingsManager.reset_zone_colours()
		return
	for e in _swatch_rects:
		if e.rect.has_point(pos):
			AudioManager.play_button_click()
			SettingsManager.set_zone_colour_index(e.ct, e.index)
			return


func _go_back() -> void:
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/settings_screen.tscn")


func _draw() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var cx: float = sw / 2.0
	_swatch_rects.clear()

	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))

	# Header
	var title := "COLOURS & ACCESSIBILITY"
	var tsz: int = 34
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 68), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Pick a colour for each zone — your zone is highlighted. Colours apply on your next game."
	var ssz: int = 15
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(cx - sub_w / 2.0, 98), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.6, 0.7, 0.8, 1.0))

	var options: int = ColourData.ACCESSIBLE_PALETTE.size() + 1   # +1 for Default
	var block_w: float = options * SWATCH_SIZE + (options - 1) * SWATCH_GAP
	var dot_x: float     = cx - 470.0
	var label_x: float   = cx - 440.0
	var swatch_x0: float = cx + 470.0 - block_w   # right-aligned block

	for row in ZONE_ORDER.size():
		var ct: int = ZONE_ORDER[row]
		var row_y: float = ROW_START_Y + row * ROW_H
		var is_sel: bool = row == _sel_row
		var is_player: bool = ct == ColourData.ColourType.GREEN

		# Selected-row highlight band
		if is_sel:
			draw_rect(Rect2(dot_x - 16.0, row_y - ROW_H / 2.0 + 4.0, 970.0, ROW_H - 8.0),
				Color(0.16, 0.18, 0.28, 0.7))

		# Effective current colour dot
		var eff: Color = ColourData.get_color(ct)
		draw_circle(Vector2(dot_x, row_y), 10.0, eff, true, -1.0, true)
		draw_arc(Vector2(dot_x, row_y), 10.0, 0, TAU, 24, eff.lightened(0.3), 1.5, true)

		# Zone label
		var label: String = ColourData.get_colour_name(ct)
		if is_player:
			label += "  (You)"
		draw_string(font, Vector2(label_x, row_y + 6.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19,
			Color(0.85, 0.95, 0.85, 1.0) if is_player else Color(0.72, 0.72, 0.82, 1.0))

		# Swatches: Default (index -1) then palette entries
		var cur_idx: int = SettingsManager.get_zone_colour_index(ct)
		for opt in range(-1, ColourData.ACCESSIBLE_PALETTE.size()):
			var slot: int = opt + 1
			var sx: float = swatch_x0 + slot * (SWATCH_SIZE + SWATCH_GAP)
			var rect := Rect2(sx, row_y - SWATCH_SIZE / 2.0, SWATCH_SIZE, SWATCH_SIZE)
			_swatch_rects.append({"rect": rect, "ct": ct, "index": opt})

			var selected: bool = cur_idx == opt
			var hovered: bool = _hover_key == "sw_%d_%d" % [ct, opt]

			if opt == -1:
				# Default swatch — show the zone's default colour with a "D" marker
				var dcol: Color = ColourData.get_default_color(ct)
				draw_rect(rect, Color(dcol.r, dcol.g, dcol.b, 0.85))
				draw_string(font, Vector2(sx + 9.0, row_y + 5.0), "D",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.6))
			else:
				draw_rect(rect, ColourData.ACCESSIBLE_PALETTE[opt]["color"])

			# Border: bright + thick if selected, lighter on hover
			if selected:
				draw_rect(rect, Color(1, 1, 1, 0.95), false, 2.5)
			elif hovered:
				draw_rect(rect, Color(0.85, 0.85, 0.95, 0.8), false, 2.0)
			else:
				draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)

	# "Default" column caption
	draw_string(font, Vector2(swatch_x0 + 2.0, ROW_START_Y - 22.0), "default",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.6, 1.0))

	# Buttons: Reset (left), Back (centre)
	var btn_y: float = ROW_START_Y + ZONE_ORDER.size() * ROW_H + 18.0

	var reset_lbl := "Reset to defaults"
	var rsz: int = 16
	var rw := font.get_string_size(reset_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, rsz).x
	_reset_rect = Rect2(cx - rw / 2.0 - 16.0, btn_y, rw + 32.0, 34.0)
	var reset_hov := _hover_key == "reset"
	draw_rect(_reset_rect, Color(0.24, 0.18, 0.2, 1.0) if reset_hov else Color(0.16, 0.13, 0.16, 1.0))
	draw_rect(_reset_rect, Color(0.7, 0.5, 0.5, 0.7) if reset_hov else Color(0.4, 0.3, 0.35, 0.6), false, 1.5)
	draw_string(font, Vector2(cx - rw / 2.0, btn_y + 23.0), reset_lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, rsz, Color(0.85, 0.7, 0.7, 1.0))

	var back_lbl := "← BACK"
	var bsz: int = 18
	var bw := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
	var back_x := cx - bw / 2.0
	var back_y := btn_y + 74.0
	_back_rect = Rect2(back_x - 16.0, back_y - bsz, bw + 32.0, bsz + 12.0)
	draw_string(font, Vector2(back_x, back_y), back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz,
		Color(0.6, 0.7, 0.9, 1.0) if _hover_key == "back" else Color(0.45, 0.55, 0.75, 1.0))

	var hint := "↑ ↓  pick zone     ← →  change colour     click a swatch     ESC — back"
	var hsz: int = 13
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz).x
	draw_string(font, Vector2(cx - hw / 2.0, sh - 22.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, hsz, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)
