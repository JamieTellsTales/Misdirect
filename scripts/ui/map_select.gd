extends Node2D
## Map & player count selection screen.
## Inserted between the main menu PLAY button and pre_game_config.
## All drawing via _draw() — no Control nodes.

const ColourData = preload("res://scripts/resources/colour_data.gd")
const CornerHUD  = preload("res://scripts/ui/corner_hud.gd")

# ── Layout constants ───────────────────────────────────────────────────────────

const CARD_W:       float = 260.0
const CARD_H:       float = 200.0
const CARD_COL_GAP: float = 20.0   # horizontal gap between columns
const CARD_ROW_GAP: float = 15.0   # vertical gap between rows
const CARDS_TOP_Y:  float = 90.0

const MAP_NAMES: Array = ["TRIANGLE", "SQUARE", "PENTAGON", "HEXAGON", "HEPTAGON", "OCTAGON"]
const MAP_KEYS:  Array = ["triangle", "square", "pentagon", "hexagon", "heptagon", "octagon"]

# ── State ──────────────────────────────────────────────────────────────────────

var selected_map_index: int = 1   # 0=triangle, 1=square, 2=octagon; default square
var num_players: int = 4

var hover_section: String = ""
var hover_index:   int    = -1
var _prev_hover: String   = ""

var _card_rects:        Array = []   # [Rect2 × 3]
var _arrow_left_rect:   Rect2 = Rect2()
var _arrow_right_rect:  Rect2 = Rect2()
var _back_rect:         Rect2 = Rect2()
var _next_rect:         Rect2 = Rect2()


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore any previously chosen map/count from GameConfig, falling back to
	# triangle (always unlocked) if the saved map is no longer accessible.
	var key_idx := MAP_KEYS.find(GameConfig.selected_map)
	if key_idx >= 0 and StatsManager.is_map_unlocked(MAP_KEYS[key_idx]):
		selected_map_index = key_idx
	else:
		selected_map_index = 0
		GameConfig.selected_map = "triangle"
	num_players = GameConfig.num_players
	_clamp_players()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

	if event.is_action_pressed("ui_accept"):
		AudioManager.play_button_click()
		GameConfig.selected_map = MAP_KEYS[selected_map_index]
		GameConfig.num_players  = num_players
		get_tree().change_scene_to_file("res://scenes/pre_game_config.tscn")

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	hover_index   = -1

	for i in _card_rects.size():
		if _card_rects[i].has_point(pos):
			if StatsManager.is_map_unlocked(MAP_KEYS[i]):
				hover_section = "card"
				hover_index   = i
			return

	if _arrow_left_rect.has_point(pos):
		hover_section = "arrow_left"
	elif _arrow_right_rect.has_point(pos):
		hover_section = "arrow_right"
	elif _next_rect.has_point(pos):
		hover_section = "next"
	elif _back_rect.has_point(pos):
		hover_section = "back"

	if hover_section != _prev_hover and hover_section != "":
		AudioManager.play_button_hover()
	_prev_hover = hover_section


func _handle_click(pos: Vector2) -> void:
	for i in _card_rects.size():
		if _card_rects[i].has_point(pos):
			if StatsManager.is_map_unlocked(MAP_KEYS[i]):
				AudioManager.play_button_click()
				selected_map_index = i
				_clamp_players()
			return

	if _arrow_left_rect.has_point(pos):
		if num_players > 2:
			AudioManager.play_button_click()
			num_players -= 1
		return

	if _arrow_right_rect.has_point(pos):
		if num_players < 8:
			AudioManager.play_button_click()
			num_players += 1
		return

	if _next_rect.has_point(pos):
		AudioManager.play_button_click()
		GameConfig.selected_map = MAP_KEYS[selected_map_index]
		GameConfig.num_players  = num_players
		get_tree().change_scene_to_file("res://scenes/pre_game_config.tscn")
		return

	if _back_rect.has_point(pos):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")
		return


func _clamp_players() -> void:
	var valid: Array = _current_valid_players()
	if valid.has(num_players):
		return
	# Snap to the nearest valid count.
	var best: int = valid[0]
	for v: int in valid:
		if abs(v - num_players) < abs(best - num_players):
			best = v
	num_players = best


func _current_valid_players() -> Array:
	return GameConfig.MAP_VALID_PLAYERS[MAP_KEYS[selected_map_index]]


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_cards()
	_draw_player_count_row()
	_draw_bottom_buttons()


func _draw_background() -> void:
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)),
		Color(0.07, 0.07, 0.12, 1.0))
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0
	var ca: float = 0.07
	draw_circle(Vector2(0, 0),   200, Color(Color.DODGER_BLUE,    ca))
	draw_circle(Vector2(sw, 0),  200, Color(Color.CRIMSON,        ca))
	draw_circle(Vector2(0, sh),  200, Color(Color.FOREST_GREEN,   ca))
	draw_circle(Vector2(sw, sh), 200, Color(Color.GOLD, ca))
	# Subtle octagon grid lines
	var half: float = 380.0; var inset: float = 130.0
	var pts: PackedVector2Array = [
		Vector2(cx - half, cy - inset), Vector2(cx - inset, cy - half),
		Vector2(cx + inset, cy - half), Vector2(cx + half, cy - inset),
		Vector2(cx + half, cy + inset), Vector2(cx + inset, cy + half),
		Vector2(cx - inset, cy + half), Vector2(cx - half, cy + inset),
	]
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.18, 0.18, 0.28, 1.0), 1.5)


func _draw_header() -> void:
	var font := FontManager.get_font()
	var cx: float = get_viewport_rect().size.x / 2.0
	var title := "SELECT MAP"
	var tsz: int = 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 62), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 60), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)
	draw_line(Vector2(cx - 460, 78), Vector2(cx + 460, 78),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_cards() -> void:
	var font := FontManager.get_font()
	_card_rects.clear()

	var cx: float = get_viewport_rect().size.x / 2.0
	var card_centres: Array = [
		Vector2(cx - CARD_W - CARD_COL_GAP, CARDS_TOP_Y + CARD_H / 2.0),
		Vector2(cx,                          CARDS_TOP_Y + CARD_H / 2.0),
		Vector2(cx + CARD_W + CARD_COL_GAP, CARDS_TOP_Y + CARD_H / 2.0),
		Vector2(cx - CARD_W - CARD_COL_GAP, CARDS_TOP_Y + CARD_H + CARD_ROW_GAP + CARD_H / 2.0),
		Vector2(cx,                          CARDS_TOP_Y + CARD_H + CARD_ROW_GAP + CARD_H / 2.0),
		Vector2(cx + CARD_W + CARD_COL_GAP, CARDS_TOP_Y + CARD_H + CARD_ROW_GAP + CARD_H / 2.0),
	]

	for i in 6:
		var centre: Vector2 = card_centres[i]
		var rect := Rect2(centre - Vector2(CARD_W / 2.0, CARD_H / 2.0),
			Vector2(CARD_W, CARD_H))
		_card_rects.append(rect)

		var map_key: String    = MAP_KEYS[i]
		var is_locked: bool    = not StatsManager.is_map_unlocked(map_key)
		var is_selected: bool  = (i == selected_map_index)
		var is_hovered: bool   = (hover_section == "card" and hover_index == i)
		var supported: bool    = GameConfig.MAP_VALID_PLAYERS[map_key].has(num_players)

		# Card background
		var bg_col: Color
		if is_locked:
			bg_col = Color(0.05, 0.05, 0.08, 1.0)
		elif not supported:
			bg_col = Color(0.06, 0.06, 0.09, 1.0)
		elif is_selected:
			bg_col = Color(0.1, 0.18, 0.28, 1.0)
		elif is_hovered:
			bg_col = Color(0.1, 0.12, 0.2, 1.0)
		else:
			bg_col = Color(0.08, 0.08, 0.14, 1.0)
		draw_rect(rect, bg_col)

		# Border
		var brd_col: Color
		if is_locked:
			brd_col = Color(0.2, 0.18, 0.22, 0.35)
		elif not supported:
			brd_col = Color(0.18, 0.18, 0.22, 0.5)
		elif is_selected:
			brd_col = Color(0.35, 0.65, 1.0, 1.0)
		elif is_hovered:
			brd_col = Color(0.3, 0.45, 0.7, 0.85)
		else:
			brd_col = Color(0.25, 0.25, 0.38, 0.6)
		draw_rect(rect, brd_col, false, 2.5 if is_selected else 1.5)

		# Polygon preview — dimmed for locked, hidden when count not supported
		_draw_map_preview(centre + Vector2(0, -20), map_key, not is_locked and supported, is_locked)

		# Label (map name)
		var lbl: String = MAP_NAMES[i]
		var lsz: int = 20 if is_selected else 17
		var lc: Color
		if is_locked:
			lc = Color(0.3, 0.28, 0.34, 1.0)
		elif not supported:
			lc = Color(0.35, 0.35, 0.42, 1.0)
		elif is_selected:
			lc = Color.WHITE
		else:
			lc = Color(0.7, 0.75, 0.9, 1.0)
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x
		draw_string(font, Vector2(centre.x - lw / 2.0, rect.position.y + CARD_H - 10.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, lc)

		# Lock overlay: "LOCKED" + unlock hint
		if is_locked:
			var req: Dictionary   = GameConfig.MAP_UNLOCK_REQUIREMENTS.get(map_key, {})
			var req_wins: int     = req.get("wins", 0)
			var prev_key: String  = req.get("prev", "")
			var done_wins: int    = StatsManager.map_wins.get(prev_key, 0)
			var prev_name: String = prev_key.capitalize()

			var lock_lbl := "LOCKED"
			var ll_sz: int = 13
			var ll_w := font.get_string_size(lock_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, ll_sz).x
			draw_string(font, Vector2(centre.x - ll_w / 2.0, rect.position.y + CARD_H - 52.0),
				lock_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, ll_sz, Color(0.65, 0.5, 0.2, 0.9))

			var hint := "%d / %d wins on %s" % [done_wins, req_wins, prev_name]
			var hl_sz: int = 11
			var hl_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hl_sz).x
			draw_string(font, Vector2(centre.x - hl_w / 2.0, rect.position.y + CARD_H - 36.0),
				hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hl_sz, Color(0.5, 0.42, 0.28, 0.8))



func _get_preview_verts(map_key: String) -> PackedVector2Array:
	## Vertices clockwise from bottom-left of side 0. Scaled to fit within card.
	match map_key:
		"triangle":
			# Equilateral flat-bottom, ~104px wide, ~90px tall
			return PackedVector2Array([
				Vector2(-52, 40), Vector2(52, 40), Vector2(0, -50),
			])
		"square":
			# True square, 80×80px
			return PackedVector2Array([
				Vector2(-40, 40),  Vector2(40, 40),
				Vector2(40, -40),  Vector2(-40, -40),
			])
		"pentagon":
			# Regular pentagon, flat bottom
			return PackedVector2Array([
				Vector2(-29, 40), Vector2(29, 40),
				Vector2(47, -15), Vector2(0, -50),
				Vector2(-47, -15),
			])
		"hexagon":
			# Regular hexagon, flat bottom
			return PackedVector2Array([
				Vector2(-22, 38), Vector2(22, 38),
				Vector2(44, 0),   Vector2(22, -38),
				Vector2(-22, -38), Vector2(-44, 0),
			])
		"heptagon":
			# Regular heptagon, flat bottom
			return PackedVector2Array([
				Vector2(-19, 40), Vector2(19, 40),
				Vector2(43, 10),  Vector2(35, -28),
				Vector2(0, -44),  Vector2(-35, -28),
				Vector2(-43, 10),
			])
		_:  # octagon — regular, flat bottom
			return PackedVector2Array([
				Vector2(-20, 50),  Vector2(20, 50),
				Vector2(50, 20),   Vector2(50, -20),
				Vector2(20, -50),  Vector2(-20, -50),
				Vector2(-50, -20), Vector2(-50, 20),
			])


func _draw_map_preview(centre: Vector2, map_key: String, supported: bool, locked: bool = false) -> void:
	## Draws the polygon outline and coloured zone dots for the current player count.
	var verts: PackedVector2Array = _get_preview_verts(map_key)
	var n: int = verts.size()

	# Polygon outline (closed loop)
	var poly: PackedVector2Array
	for v in verts:
		poly.append(centre + v)
	var outline := poly.duplicate()
	outline.append(poly[0])
	var outline_col: Color
	if locked:
		outline_col = Color(0.28, 0.26, 0.32, 0.45)
	elif supported:
		outline_col = Color(0.5, 0.55, 0.75, 0.85)
	else:
		outline_col = Color(0.25, 0.25, 0.32, 0.5)
	draw_polyline(outline, outline_col, 1.5)

	# Zone dots — only shown when this map supports the current player count.
	if not supported:
		return

	var sides: Array = GameConfig.MAP_ZONE_SIDES[map_key][num_players]
	for slot in sides.size():
		var side_idx: int = sides[slot]
		var a: Vector2 = centre + verts[side_idx]
		var b: Vector2 = centre + verts[(side_idx + 1) % n]
		var mid: Vector2 = (a + b) / 2.0
		var edge_dir: Vector2 = (b - a).normalized()
		var outward: Vector2 = Vector2(-edge_dir.y, edge_dir.x)
		var dot_pos: Vector2 = mid + outward * 12.0
		var ct: int = _slot_colour(slot)
		var dot_col: Color = ColourData.get_color(ct)
		draw_circle(dot_pos, 7.0, Color(dot_col, 0.9), true, -1.0, true)
		draw_arc(dot_pos, 7.0, 0, TAU, 32, Color(dot_col.lightened(0.3), 1.0), 1.0, true)


func _slot_colour(slot: int) -> int:
	const SLOTS: Array = [
		ColourData.ColourType.GREEN,
		ColourData.ColourType.BLUE,
		ColourData.ColourType.RED,
		ColourData.ColourType.YELLOW,
		ColourData.ColourType.PURPLE,
		ColourData.ColourType.ORANGE,
		ColourData.ColourType.CYAN,
		ColourData.ColourType.PINK,
	]
	return SLOTS[slot] if slot < SLOTS.size() else 0


func _draw_player_count_row() -> void:
	var font := FontManager.get_font()
	var cx: float = get_viewport_rect().size.x / 2.0
	var row_y: float = CARDS_TOP_Y + 2.0 * CARD_H + CARD_ROW_GAP + 22.0

	# Label
	var lbl := "ZONES IN PLAY"
	var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(cx - lw / 2.0, row_y),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.65, 0.8, 1.0))

	# ← arrow
	var arr_y: float = row_y + 22.0
	var arr_h: float = 44.0
	var arr_w: float = 44.0
	var can_dec: bool = num_players > 2
	_arrow_left_rect = Rect2(cx - 130.0, arr_y, arr_w, arr_h)
	_draw_arrow_button(_arrow_left_rect, "←", hover_section == "arrow_left", can_dec)

	# Number
	var num_str := str(num_players)
	var nw := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, Vector2(cx - nw / 2.0, arr_y + 34.0),
		num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)

	# → arrow
	var can_inc: bool = num_players < 8
	_arrow_right_rect = Rect2(cx + 86.0, arr_y, arr_w, arr_h)
	_draw_arrow_button(_arrow_right_rect, "→", hover_section == "arrow_right", can_inc)

	# Zone dot colour preview — only shown when selected map supports current count
	var map_key_sel: String = MAP_KEYS[selected_map_index]
	if GameConfig.MAP_VALID_PLAYERS[map_key_sel].has(num_players):
		var dot_row_y: float = arr_y + arr_h + 14.0
		var sides: Array = GameConfig.MAP_ZONE_SIDES[map_key_sel][num_players]
		var dot_spacing: float = 30.0
		var total_w: float = (sides.size() - 1) * dot_spacing
		for slot in sides.size():
			var dot_x: float = cx - total_w / 2.0 + slot * dot_spacing
			var ct: int = _slot_colour(slot)
			var col: Color = ColourData.get_color(ct)
			draw_circle(Vector2(dot_x, dot_row_y + 10.0), 10.0, Color(col, 0.9), true, -1.0, true)
			draw_arc(Vector2(dot_x, dot_row_y + 10.0), 10.0, 0, TAU, 48,
				Color(col.lightened(0.3), 1.0), 1.0, true)
			# "YOU" label under player dot
			if slot == 0:
				var you_lbl := "YOU"
				var yw := font.get_string_size(you_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				draw_string(font, Vector2(dot_x - yw / 2.0, dot_row_y + 36.0),
					you_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, 0.9))
	else:
		# Show a subtle "not supported" hint
		var dot_row_y: float = arr_y + arr_h + 14.0
		var hint := "not supported by selected map"
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(cx - hw / 2.0, dot_row_y + 14.0),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.45, 0.52, 1.0))


func _draw_arrow_button(rect: Rect2, label: String, hovered: bool, enabled: bool) -> void:
	var font := FontManager.get_font()
	if enabled:
		draw_rect(rect,
			Color(0.25, 0.35, 0.55, 1.0) if hovered else Color(0.15, 0.22, 0.38, 1.0))
		draw_rect(rect, Color(0.35, 0.55, 0.9, 0.85), false, 1.5)
	else:
		draw_rect(rect, Color(0.1, 0.1, 0.16, 1.0))
		draw_rect(rect, Color(0.25, 0.25, 0.32, 0.4), false, 1.5)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font,
		Vector2(rect.position.x + (rect.size.x - lw) / 2.0, rect.position.y + 30.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color.WHITE if enabled else Color(0.35, 0.35, 0.42, 1.0))


func _draw_bottom_buttons() -> void:
	var font := FontManager.get_font()
	var cx: float = get_viewport_rect().size.x / 2.0
	var by: float = get_viewport_rect().size.y - 54.0   # Smaller buttons sit closer to the bottom edge

	# NEXT →
	var nx_w: float = 150.0; var nx_h: float = 36.0
	_next_rect = Rect2(cx + 16.0, by, nx_w, nx_h)
	var nx_hov: bool = hover_section == "next"
	draw_rect(_next_rect, Color(0.15, 0.45, 0.22, 1.0) if nx_hov else Color(0.1, 0.32, 0.15, 1.0))
	draw_rect(_next_rect, Color(0.3, 0.85, 0.45, 0.9), false, 1.5)
	var nx_lbl := "NEXT →"; var nx_sz: int = 17
	var nx_w2 := font.get_string_size(nx_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nx_sz).x
	draw_string(font, Vector2(_next_rect.position.x + (nx_w - nx_w2) / 2.0, by + 24.0),
		nx_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nx_sz, Color.WHITE)

	# ← BACK
	var bk_w: float = 120.0; var bk_h: float = 36.0
	_back_rect = Rect2(cx - bk_w - 32.0, by, bk_w, bk_h)
	var bk_hov: bool = hover_section == "back"
	draw_rect(_back_rect, Color(0.28, 0.28, 0.38, 1.0) if bk_hov else Color(0.18, 0.18, 0.26, 1.0))
	draw_rect(_back_rect, Color(0.4, 0.4, 0.52, 0.7), false, 1.5)
	var bk_lbl := "← BACK"; var bk_sz: int = 15
	var bk_w2 := font.get_string_size(bk_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bk_sz).x
	draw_string(font, Vector2(_back_rect.position.x + (bk_w - bk_w2) / 2.0, by + 23.0),
		bk_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bk_sz, Color(0.75, 0.75, 0.85, 1.0))

	CornerHUD.draw_on(self)
