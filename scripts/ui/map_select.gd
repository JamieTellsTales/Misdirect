extends Node2D
## Map & player count selection screen.
## Inserted between the main menu PLAY button and pre_game_config.
## All drawing via _draw() — no Control nodes.

const ColourData = preload("res://scripts/resources/department_data.gd")

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0

# ── Layout constants ───────────────────────────────────────────────────────────

const CARD_W:   float = 320.0
const CARD_H:   float = 320.0
const CARD_GAP: float = 40.0
const CARD_Y:   float = 100.0  # Top of cards

# Card centres (horizontal layout)
const CARD_CENTRES: Array = [
	Vector2(1280.0 / 2.0 - CARD_W - CARD_GAP, CARD_Y + CARD_H / 2.0),   # triangle
	Vector2(1280.0 / 2.0,                       CARD_Y + CARD_H / 2.0),   # square
	Vector2(1280.0 / 2.0 + CARD_W + CARD_GAP,  CARD_Y + CARD_H / 2.0),   # octagon
]

const MAP_NAMES: Array = ["TRIANGLE", "SQUARE", "OCTAGON"]
const MAP_KEYS:  Array = ["triangle", "square", "octagon"]

# ── State ──────────────────────────────────────────────────────────────────────

var selected_map_index: int = 1   # 0=triangle, 1=square, 2=octagon; default square
var num_players: int = 4

var hover_section: String = ""
var hover_index:   int    = -1

var _card_rects:        Array = []   # [Rect2 × 3]
var _arrow_left_rect:   Rect2 = Rect2()
var _arrow_right_rect:  Rect2 = Rect2()
var _back_rect:         Rect2 = Rect2()
var _next_rect:         Rect2 = Rect2()


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore any previously chosen map/count from GameConfig
	var key_idx := MAP_KEYS.find(GameConfig.selected_map)
	if key_idx >= 0:
		selected_map_index = key_idx
	num_players = GameConfig.num_players
	_clamp_players()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	hover_index   = -1

	for i in _card_rects.size():
		if _card_rects[i].has_point(pos):
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


func _handle_click(pos: Vector2) -> void:
	for i in _card_rects.size():
		if _card_rects[i].has_point(pos):
			selected_map_index = i
			_clamp_players()
			return

	if _arrow_left_rect.has_point(pos):
		var limits: Dictionary = _current_limits()
		num_players = max(limits["min"], num_players - 1)
		return

	if _arrow_right_rect.has_point(pos):
		var limits: Dictionary = _current_limits()
		num_players = min(limits["max"], num_players + 1)
		return

	if _next_rect.has_point(pos):
		GameConfig.selected_map = MAP_KEYS[selected_map_index]
		GameConfig.num_players  = num_players
		get_tree().change_scene_to_file("res://scenes/pre_game_config.tscn")
		return

	if _back_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return


func _clamp_players() -> void:
	var limits := _current_limits()
	num_players = clamp(num_players, limits["min"], limits["max"])


func _current_limits() -> Dictionary:
	return GameConfig.MAP_PLAYER_LIMITS[MAP_KEYS[selected_map_index]]


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_cards()
	_draw_player_count_row()
	_draw_bottom_buttons()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)),
		Color(0.07, 0.07, 0.12, 1.0))
	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var ca: float = 0.07
	draw_circle(Vector2(0, 0),            200, Color(Color.DODGER_BLUE,    ca))
	draw_circle(Vector2(ARENA_WIDTH, 0),  200, Color(Color.CRIMSON,        ca))
	draw_circle(Vector2(0, ARENA_HEIGHT), 200, Color(Color.FOREST_GREEN,   ca))
	draw_circle(Vector2(ARENA_WIDTH, ARENA_HEIGHT), 200, Color(Color.GOLD, ca))
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
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0
	var title := "SELECT MAP"
	var tsz: int = 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 62), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 60), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)
	draw_line(Vector2(180, 78), Vector2(ARENA_WIDTH - 180, 78),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_cards() -> void:
	var font := ThemeDB.fallback_font
	_card_rects.clear()

	for i in 3:
		var centre: Vector2 = CARD_CENTRES[i]
		var rect := Rect2(centre - Vector2(CARD_W / 2.0, CARD_H / 2.0),
			Vector2(CARD_W, CARD_H))
		_card_rects.append(rect)

		var is_selected: bool = (i == selected_map_index)
		var is_hovered:  bool = (hover_section == "card" and hover_index == i)
		var map_key: String   = MAP_KEYS[i]

		# Card background
		var bg_col: Color
		if is_selected:
			bg_col = Color(0.1, 0.18, 0.28, 1.0)
		elif is_hovered:
			bg_col = Color(0.1, 0.12, 0.2, 1.0)
		else:
			bg_col = Color(0.08, 0.08, 0.14, 1.0)
		draw_rect(rect, bg_col)

		# Border
		var brd_col: Color
		if is_selected:
			brd_col = Color(0.35, 0.65, 1.0, 1.0)
		elif is_hovered:
			brd_col = Color(0.3, 0.45, 0.7, 0.85)
		else:
			brd_col = Color(0.25, 0.25, 0.38, 0.6)
		draw_rect(rect, brd_col, false, 2.5 if is_selected else 1.5)

		# Polygon preview
		_draw_map_preview(centre + Vector2(0, -20), map_key, i)

		# Label
		var lbl: String = MAP_NAMES[i]
		var lsz: int = 20 if is_selected else 17
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x
		var lc := Color.WHITE if is_selected else Color(0.7, 0.75, 0.9, 1.0)
		draw_string(font, Vector2(centre.x - lw / 2.0, rect.position.y + CARD_H - 18.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, lc)

		# Player count range hint
		var limits: Dictionary = GameConfig.MAP_PLAYER_LIMITS[map_key]
		var hint := "%d – %d zones" % [limits["min"], limits["max"]]
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(centre.x - hw / 2.0, rect.position.y + CARD_H - 2.0),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.45, 0.6, 0.85, 0.85) if is_selected else Color(0.4, 0.4, 0.55, 0.7))


func _get_preview_verts(map_key: String) -> PackedVector2Array:
	## Vertices are clockwise starting from the bottom-left of the bottom face (side 0).
	match map_key:
		"triangle":
			# Equilateral: h=162, s≈187, side 0 = bottom, side 1 = right, side 2 = left
			return PackedVector2Array([
				Vector2(-94, 72), Vector2(94, 72), Vector2(0, -90),
			])
		"square":
			# Side 0 = bottom, side 1 = right, side 2 = top, side 3 = left
			return PackedVector2Array([
				Vector2(-78, 72),  Vector2(78, 72),
				Vector2(78, -72),  Vector2(-78, -72),
			])
		_:  # octagon — regular, inradius=90, all edges ≈74px
			# Side 0 = bottom, continuing clockwise
			return PackedVector2Array([
				Vector2(-37, 90),  Vector2(37, 90),
				Vector2(90, 37),   Vector2(90, -37),
				Vector2(37, -90),  Vector2(-37, -90),
				Vector2(-90, -37), Vector2(-90, 37),
			])


func _draw_map_preview(centre: Vector2, map_key: String, card_index: int) -> void:
	## Draws the polygon outline and coloured zone dots for the current player count.
	var verts: PackedVector2Array = _get_preview_verts(map_key)
	var n: int = verts.size()

	# Polygon outline (closed loop)
	var poly: PackedVector2Array
	for v in verts:
		poly.append(centre + v)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(0.5, 0.55, 0.75, 0.85), 1.5)

	# Active zone dots — use the num_players for this card only if it's selected;
	# for other cards, show their minimum valid count so the preview is always valid.
	var preview_players: int
	if card_index == selected_map_index:
		preview_players = num_players
	else:
		preview_players = GameConfig.MAP_PLAYER_LIMITS[map_key]["min"]

	# Clamp to this card's valid range
	var limits: Dictionary = GameConfig.MAP_PLAYER_LIMITS[map_key]
	preview_players = clamp(preview_players, limits["min"], limits["max"])

	var sides: Array = GameConfig.MAP_ZONE_SIDES[map_key][preview_players]
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
		draw_circle(dot_pos, 7.0, Color(dot_col, 0.9))
		draw_arc(dot_pos, 7.0, 0, TAU, 12, Color(dot_col.lightened(0.3), 1.0), 1.5)


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
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0
	var row_y: float = CARD_Y + CARD_H + 40.0
	var limits: Dictionary = _current_limits()

	# Label
	var lbl := "ZONES IN PLAY"
	var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(cx - lw / 2.0, row_y),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.65, 0.8, 1.0))

	# ← arrow
	var arr_y: float = row_y + 24.0
	var arr_h: float = 44.0
	var arr_w: float = 44.0
	var can_dec: bool = num_players > limits["min"]
	_arrow_left_rect = Rect2(cx - 130.0, arr_y, arr_w, arr_h)
	_draw_arrow_button(_arrow_left_rect, "←", hover_section == "arrow_left", can_dec)

	# Number
	var num_str := str(num_players)
	var nw := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, Vector2(cx - nw / 2.0, arr_y + 34.0),
		num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)

	# → arrow
	var can_inc: bool = num_players < limits["max"]
	_arrow_right_rect = Rect2(cx + 86.0, arr_y, arr_w, arr_h)
	_draw_arrow_button(_arrow_right_rect, "→", hover_section == "arrow_right", can_inc)

	# Zone dot colour preview row below the counter
	var dot_row_y: float = arr_y + arr_h + 14.0
	var sides: Array = GameConfig.MAP_ZONE_SIDES[MAP_KEYS[selected_map_index]][num_players]
	var dot_spacing: float = 30.0
	var total_w: float = (sides.size() - 1) * dot_spacing
	for slot in sides.size():
		var dot_x: float = cx - total_w / 2.0 + slot * dot_spacing
		var ct: int = _slot_colour(slot)
		var col: Color = ColourData.get_color(ct)
		draw_circle(Vector2(dot_x, dot_row_y + 10.0), 10.0, Color(col, 0.9))
		draw_arc(Vector2(dot_x, dot_row_y + 10.0), 10.0, 0, TAU, 16,
			Color(col.lightened(0.3), 1.0), 1.5)
		# "YOU" label under player dot
		if slot == 0:
			var you_lbl := "YOU"
			var yw := font.get_string_size(you_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(dot_x - yw / 2.0, dot_row_y + 28.0),
				you_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, 0.9))


func _draw_arrow_button(rect: Rect2, label: String, hovered: bool, enabled: bool) -> void:
	var font := ThemeDB.fallback_font
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
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0
	var by: float = ARENA_HEIGHT - 80.0

	# NEXT →
	var nx_w: float = 200.0; var nx_h: float = 52.0
	_next_rect = Rect2(cx + 20.0, by, nx_w, nx_h)
	var nx_hov: bool = hover_section == "next"
	draw_rect(_next_rect, Color(0.15, 0.45, 0.22, 1.0) if nx_hov else Color(0.1, 0.32, 0.15, 1.0))
	draw_rect(_next_rect, Color(0.3, 0.85, 0.45, 0.9), false, 2.0)
	var nx_lbl := "NEXT →"; var nx_sz: int = 22
	var nx_w2 := font.get_string_size(nx_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nx_sz).x
	draw_string(font, Vector2(_next_rect.position.x + (nx_w - nx_w2) / 2.0, by + 35.0),
		nx_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nx_sz, Color.WHITE)

	# ← BACK
	var bk_w: float = 160.0; var bk_h: float = 52.0
	_back_rect = Rect2(cx - bk_w - 40.0, by, bk_w, bk_h)
	var bk_hov: bool = hover_section == "back"
	draw_rect(_back_rect, Color(0.28, 0.28, 0.38, 1.0) if bk_hov else Color(0.18, 0.18, 0.26, 1.0))
	draw_rect(_back_rect, Color(0.4, 0.4, 0.52, 0.7), false, 1.5)
	var bk_lbl := "← BACK"; var bk_sz: int = 20
	var bk_w2 := font.get_string_size(bk_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bk_sz).x
	draw_string(font, Vector2(_back_rect.position.x + (bk_w - bk_w2) / 2.0, by + 34.0),
		bk_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bk_sz, Color(0.75, 0.75, 0.85, 1.0))
