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

const ROW_START_Y: float = 144.0
const ROW_H:       float = 44.0
const SWATCH_SIZE: float = 30.0
const SWATCH_GAP:  float = 7.0

## Accessibility toggles shown below the colour grid.
const TOGGLES: Array = [
	{"label": "Reduced motion", "desc": "No screen shake, hit-stop, trails or flashing"},
	{"label": "Ball symbols",   "desc": "A distinct shape per colour on balls & zones"},
]

var _swatch_rects: Array = []   # [{rect, ct, index}]  index -1 = Default
var _toggle_rects: Array = []   # [{rect, idx}]
var _back_rect:  Rect2 = Rect2()
var _reset_rect: Rect2 = Rect2()
var _hover_key:  String = ""
var _sel_row:    int = 0        # keyboard cursor: 0..7 zones, then toggles


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_dedupe_colours()


func _dedupe_colours() -> void:
	## Enforce one-colour-per-zone: if any palette colour is assigned to more than
	## one zone (e.g. from older saves), keep the first in display order and reset
	## the rest to their default.
	var seen: Dictionary = {}
	var changed: bool = false
	for ct in ZONE_ORDER:
		var idx: int = SettingsManager.get_zone_colour_index(ct)
		if idx < 0:
			continue
		if seen.has(idx):
			SettingsManager.zone_colours.erase(ct)
			changed = true
		else:
			seen[idx] = ct
	if changed:
		SettingsManager.save_settings()


func _colour_owner(palette_index: int) -> int:
	## The ColourType currently using this palette index, or -1 if unused.
	for key in SettingsManager.zone_colours:
		if int(SettingsManager.zone_colours[key]) == palette_index:
			return int(key)
	return -1


func _available_options(ct: int) -> Array:
	## Options this zone may cycle to: Default plus palette colours not taken by
	## another zone.
	var out: Array = [-1]
	for i in range(ColourData.ACCESSIBLE_PALETTE.size()):
		var owner: int = _colour_owner(i)
		if owner == -1 or owner == ct:
			out.append(i)
	return out


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

	var total: int = ZONE_ORDER.size() + TOGGLES.size()
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_sel_row = (_sel_row + 1) % total
		AudioManager.play_button_hover()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_sel_row = (_sel_row - 1 + total) % total
		AudioManager.play_button_hover()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if _sel_row < ZONE_ORDER.size():
			_cycle_row(_sel_row, 1)
		else:
			_toggle_setting(_sel_row - ZONE_ORDER.size())
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if _sel_row < ZONE_ORDER.size():
			_cycle_row(_sel_row, -1)
		else:
			_toggle_setting(_sel_row - ZONE_ORDER.size())
	elif event.is_action_pressed("ui_accept") and _sel_row >= ZONE_ORDER.size():
		_toggle_setting(_sel_row - ZONE_ORDER.size())


func _toggle_value(idx: int) -> bool:
	return SettingsManager.reduced_motion if idx == 0 else SettingsManager.ball_symbols


func _toggle_setting(idx: int) -> void:
	if idx == 0:
		SettingsManager.reduced_motion = not SettingsManager.reduced_motion
	elif idx == 1:
		SettingsManager.ball_symbols = not SettingsManager.ball_symbols
	SettingsManager.save_settings()
	AudioManager.play_button_click()


func _cycle_row(row: int, dir: int) -> void:
	## Cycle a zone through its available options (Default + colours not taken).
	var ct: int = ZONE_ORDER[row]
	var opts: Array = _available_options(ct)
	var cur: int = SettingsManager.get_zone_colour_index(ct)
	var pos: int = opts.find(cur)
	if pos == -1:
		pos = 0
	var next: int = opts[wrapi(pos + dir, 0, opts.size())]
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
		if new_key == "":
			for e in _toggle_rects:
				if e.rect.has_point(pos):
					new_key = "tog_%d" % e.idx
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
	for e in _toggle_rects:
		if e.rect.has_point(pos):
			_toggle_setting(e.idx)
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
	_toggle_rects.clear()

	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))

	# Header
	var title := "COLOURS & ACCESSIBILITY"
	var tsz: int = 34
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 68), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Pick a colour for each player — each colour can only be used once. Applies on your next game."
	var ssz: int = 15
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(cx - sub_w / 2.0, 98), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.6, 0.7, 0.8, 1.0))

	var options: int = ColourData.ACCESSIBLE_PALETTE.size() + 1   # +1 for Default
	var block_w: float = options * SWATCH_SIZE + (options - 1) * SWATCH_GAP
	var dot_x: float     = cx - 470.0
	var label_x: float   = cx - 440.0
	var swatch_x0: float = cx + 470.0 - block_w   # right-aligned block

	# Which palette index is currently taken by which zone (for uniqueness).
	var used_by: Dictionary = {}
	for uz in ZONE_ORDER:
		var ui: int = SettingsManager.get_zone_colour_index(uz)
		if ui >= 0:
			used_by[ui] = uz

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

		# Zone label — Player 1 (You), Player 2, …
		var label: String = "Player %d" % (row + 1)
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

			var selected: bool = cur_idx == opt
			# A palette colour used by a DIFFERENT player can't be picked here.
			var taken_other: bool = opt >= 0 and used_by.get(opt, ct) != ct

			if opt == -1:
				# Default swatch — show the zone's default colour with a "D" marker
				var dcol: Color = ColourData.get_default_color(ct)
				draw_rect(rect, Color(dcol.r, dcol.g, dcol.b, 0.85))
				draw_string(font, Vector2(sx + 9.0, row_y + 5.0), "D",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.6))
			elif taken_other:
				# Greyed with an ✕ — taken by another player.
				var pc: Color = ColourData.ACCESSIBLE_PALETTE[opt]["color"]
				draw_rect(rect, Color(pc.r, pc.g, pc.b, 0.20))
				var m: float = 8.0
				draw_line(rect.position + Vector2(m, m), rect.position + Vector2(SWATCH_SIZE - m, SWATCH_SIZE - m), Color(0.7, 0.7, 0.75, 0.7), 1.5, true)
				draw_line(rect.position + Vector2(SWATCH_SIZE - m, m), rect.position + Vector2(m, SWATCH_SIZE - m), Color(0.7, 0.7, 0.75, 0.7), 1.5, true)
			else:
				draw_rect(rect, ColourData.ACCESSIBLE_PALETTE[opt]["color"])

			var hovered: bool = _hover_key == "sw_%d_%d" % [ct, opt]
			# Border: bright + thick if selected, dim if taken, lighter on hover
			if selected:
				draw_rect(rect, Color(1, 1, 1, 0.95), false, 2.5)
			elif taken_other:
				draw_rect(rect, Color(0.3, 0.3, 0.36, 0.6), false, 1.0)
			elif hovered:
				draw_rect(rect, Color(0.85, 0.85, 0.95, 0.8), false, 2.0)
			else:
				draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)

			# Only selectable swatches are clickable / hoverable.
			if not taken_other:
				_swatch_rects.append({"rect": rect, "ct": ct, "index": opt})

	# "Default" column caption
	draw_string(font, Vector2(swatch_x0 + 2.0, ROW_START_Y - 22.0), "default",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.6, 1.0))

	# ── Accessibility toggles ─────────────────────────────────────────────────
	var tog_y0: float = ROW_START_Y + ZONE_ORDER.size() * ROW_H + 6.0
	draw_line(Vector2(dot_x - 16.0, tog_y0 - 12.0), Vector2(cx + 470.0, tog_y0 - 12.0),
		Color(0.3, 0.3, 0.4, 0.4), 1.0)
	for ti in TOGGLES.size():
		var ty: float = tog_y0 + 14.0 + ti * ROW_H
		var is_tsel: bool = _sel_row == ZONE_ORDER.size() + ti
		if is_tsel:
			draw_rect(Rect2(dot_x - 16.0, ty - ROW_H / 2.0 + 2.0, 970.0, ROW_H - 6.0),
				Color(0.16, 0.18, 0.28, 0.7))
		var on: bool = _toggle_value(ti)
		draw_string(font, Vector2(label_x, ty - 2.0), TOGGLES[ti]["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.85, 0.9, 1.0, 1.0))
		draw_string(font, Vector2(label_x, ty + 15.0), TOGGLES[ti]["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.55, 0.65, 1.0))

		# ON / OFF pill (right side, aligned with swatch block)
		var pill_w: float = 108.0
		var pill_h: float = 30.0
		var pill_x: float = cx + 470.0 - pill_w
		var pill_rect := Rect2(pill_x, ty - pill_h / 2.0, pill_w, pill_h)
		_toggle_rects.append({"rect": pill_rect, "idx": ti})
		var hov: bool = _hover_key == "tog_%d" % ti
		draw_rect(pill_rect, Color(0.14, 0.15, 0.22, 1.0))
		draw_rect(pill_rect, Color(0.5, 0.6, 0.8, 0.7) if (hov or is_tsel) else Color(0.35, 0.35, 0.5, 0.6), false, 1.5)
		var half: float = pill_w / 2.0
		if on:
			draw_rect(Rect2(pill_x + half, ty - pill_h / 2.0, half, pill_h), Color(0.12, 0.5, 0.2, 0.9))
		else:
			draw_rect(Rect2(pill_x, ty - pill_h / 2.0, half, pill_h), Color(0.3, 0.3, 0.4, 0.5))
		var off_col: Color = Color(0.9, 0.9, 1.0, 1.0) if not on else Color(0.45, 0.45, 0.55, 1.0)
		var on_col: Color  = Color(0.9, 1.0, 0.9, 1.0) if on else Color(0.45, 0.45, 0.55, 1.0)
		draw_string(font, Vector2(pill_x + (half - font.get_string_size("OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) / 2.0, ty + 5.0),
			"OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, off_col)
		draw_string(font, Vector2(pill_x + half + (half - font.get_string_size("ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) / 2.0, ty + 5.0),
			"ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, on_col)

	# Buttons: Reset (left), Back (centre)
	var btn_y: float = tog_y0 + 14.0 + TOGGLES.size() * ROW_H + 8.0

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
	var back_y := btn_y + 62.0
	_back_rect = Rect2(back_x - 16.0, back_y - bsz, bw + 32.0, bsz + 12.0)
	draw_string(font, Vector2(back_x, back_y), back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz,
		Color(0.6, 0.7, 0.9, 1.0) if _hover_key == "back" else Color(0.45, 0.55, 0.75, 1.0))

	var hint := "↑ ↓  select     ← →  change     click to set     ESC — back"
	var hsz: int = 13
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz).x
	draw_string(font, Vector2(cx - hw / 2.0, sh - 22.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, hsz, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)
