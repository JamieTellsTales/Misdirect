extends Node2D
## Profile selection screen — switch between existing profiles, create a new one,
## or delete a non-active profile (with confirmation).
## All drawing done via _draw() consistent with the rest of the UI codebase.

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0
const COL_LEFT:     float = 180.0
const COL_RIGHT:    float = ARENA_WIDTH - 180.0
const CARD_H:       float = 84.0
const CARD_GAP:     float = 16.0

# ── State ─────────────────────────────────────────────────────────────────────

# Profile whose delete confirmation prompt is currently visible (empty = none)
var _confirm_delete_id: String = ""

# Mouse state
var hover_section: String = ""   # "select_N", "delete_N", "confirm_yes", "confirm_no",
                                  # "new_profile", "back"
var hover_index:   int    = -1

# Rects populated each draw call
var _select_rects:  Array = []   # Rect2 per non-active profile
var _delete_rects:  Array = []   # Rect2 per deletable profile
var _confirm_yes_rect: Rect2 = Rect2()
var _confirm_no_rect:  Rect2 = Rect2()
var _new_profile_rect: Rect2 = Rect2()
var _back_rect:        Rect2 = Rect2()

# Stats cache: id -> {wins, losses, points} (loaded once per profile on screen open)
var _stats_cache: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_stats_cache()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	hover_index   = -1

	# Confirm buttons have priority if shown
	if not _confirm_delete_id.is_empty():
		if _confirm_yes_rect.has_point(pos):
			hover_section = "confirm_yes"
			return
		if _confirm_no_rect.has_point(pos):
			hover_section = "confirm_no"
			return

	# Per-profile SELECT and DELETE buttons
	var non_active_i: int = 0
	for i in ProfileManager.profiles.size():
		var p: Dictionary = ProfileManager.profiles[i]
		if p["id"] == ProfileManager.active_id:
			continue
		if non_active_i < _select_rects.size() and _select_rects[non_active_i].has_point(pos):
			hover_section = "select"
			hover_index   = i
			return
		if non_active_i < _delete_rects.size() and _delete_rects[non_active_i].has_point(pos):
			hover_section = "delete"
			hover_index   = i
			return
		non_active_i += 1

	if _new_profile_rect.has_point(pos):
		hover_section = "new_profile"
	elif _back_rect.has_point(pos):
		hover_section = "back"


func _handle_click(pos: Vector2) -> void:
	# Confirm / cancel deletion
	if not _confirm_delete_id.is_empty():
		if _confirm_yes_rect.has_point(pos):
			ProfileManager.delete_profile(_confirm_delete_id)
			_confirm_delete_id = ""
			_load_stats_cache()
			return
		if _confirm_no_rect.has_point(pos):
			_confirm_delete_id = ""
			return
		# Click anywhere else cancels too
		_confirm_delete_id = ""
		return

	# Per-profile buttons
	var non_active_i: int = 0
	for i in ProfileManager.profiles.size():
		var p: Dictionary = ProfileManager.profiles[i]
		if p["id"] == ProfileManager.active_id:
			continue
		if non_active_i < _select_rects.size() and _select_rects[non_active_i].has_point(pos):
			ProfileManager.switch_profile(p["id"])
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return
		if non_active_i < _delete_rects.size() and _delete_rects[non_active_i].has_point(pos):
			if ProfileManager.can_delete(p["id"]):
				_confirm_delete_id = p["id"]
			return
		non_active_i += 1

	if _new_profile_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/profile_setup.tscn")
	elif _back_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _load_stats_cache() -> void:
	## Peek at each profile's stats.cfg to show wins/losses/points without
	## switching the active profile. Reads raw ConfigFile values.
	_stats_cache.clear()
	for p in ProfileManager.profiles:
		var cfg := ConfigFile.new()
		var path := ProfileManager.profile_dir(p["id"]) + "stats.cfg"
		var data: Dictionary = {"wins": 0, "losses": 0, "points": 0}
		if cfg.load(path) == OK:
			data["wins"]   = cfg.get_value("stats", "wins",   0)
			data["losses"] = cfg.get_value("stats", "losses", 0)
			data["points"] = cfg.get_value("stats", "points", 0)
		_stats_cache[p["id"]] = data


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_profile_cards()
	_draw_bottom_buttons()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)),
		Color(0.07, 0.07, 0.12, 1.0))

	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var half: float = 380.0
	var inset: float = 130.0
	var pts: PackedVector2Array = [
		Vector2(cx - half, cy - inset), Vector2(cx - inset, cy - half),
		Vector2(cx + inset, cy - half), Vector2(cx + half, cy - inset),
		Vector2(cx + half, cy + inset), Vector2(cx + inset, cy + half),
		Vector2(cx - inset, cy + half), Vector2(cx - half, cy + inset),
	]
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.18, 0.18, 0.28, 1.0), 1.5)

	var ca: float = 0.07
	draw_circle(Vector2(0, 0), 200, Color(Color.DODGER_BLUE, ca))
	draw_circle(Vector2(ARENA_WIDTH, 0), 200, Color(Color.CRIMSON, ca))
	draw_circle(Vector2(0, ARENA_HEIGHT), 200, Color(Color.FOREST_GREEN, ca))
	draw_circle(Vector2(ARENA_WIDTH, ARENA_HEIGHT), 200, Color(Color.GOLD, ca))


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0

	var title := "PLAYER PROFILES"
	var tsz: int = 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	draw_line(Vector2(COL_LEFT, 90), Vector2(COL_RIGHT, 90),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_profile_cards() -> void:
	var font := ThemeDB.fallback_font
	_select_rects.clear()
	_delete_rects.clear()

	var start_y: float = 110.0
	var non_active_i: int = 0

	for i in ProfileManager.profiles.size():
		var p: Dictionary  = ProfileManager.profiles[i]
		var is_active: bool = p["id"] == ProfileManager.active_id
		var is_confirm: bool = p["id"] == _confirm_delete_id

		var card_y: float = start_y + i * (CARD_H + CARD_GAP)
		var card_rect := Rect2(COL_LEFT, card_y, COL_RIGHT - COL_LEFT, CARD_H)

		# Card background
		var card_bg: Color
		var card_brd: Color
		if is_active:
			card_bg  = Color(0.1, 0.18, 0.12, 1.0)
			card_brd = Color(0.3, 0.85, 0.45, 0.9)
		elif is_confirm:
			card_bg  = Color(0.18, 0.08, 0.08, 1.0)
			card_brd = Color(0.85, 0.3, 0.3, 0.9)
		else:
			card_bg  = Color(0.1, 0.1, 0.16, 1.0)
			card_brd = Color(0.3, 0.3, 0.42, 0.6)
		draw_rect(card_rect, card_bg)
		draw_rect(card_rect, card_brd, false, 2.0)

		# Profile name
		var nsz: int = 24
		draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 34.0), p["name"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, nsz,
			Color.WHITE if is_active else Color(0.75, 0.75, 0.85, 1.0))

		# Stats summary
		var stats: Dictionary = _stats_cache.get(p["id"], {"wins": 0, "losses": 0, "points": 0})
		var stat_text := "%d wins  ·  %d losses  ·  %d pts" % [
			stats["wins"], stats["losses"], stats["points"]]
		draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 58.0), stat_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.5, 0.75, 0.55, 1.0) if is_active else Color(0.45, 0.45, 0.55, 1.0))

		if is_active:
			# ACTIVE badge (right side)
			var badge := "ACTIVE"
			var bsz: int = 14
			var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
			draw_string(font, Vector2(COL_RIGHT - 20.0 - bw, card_y + 34.0), badge,
				HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color(0.3, 0.9, 0.45, 1.0))

		elif is_confirm:
			# Inline delete confirmation
			var prompt := "Delete this profile?"
			var psz: int = 16
			draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 34.0), p["name"] + "  —",
				HORIZONTAL_ALIGNMENT_LEFT, -1, nsz, Color(0.9, 0.55, 0.55, 1.0))
			draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 34.0 + nsz + 2.0), prompt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, psz, Color(0.8, 0.5, 0.5, 1.0))

			# YES button
			var yes_w: float = 72.0
			var yes_h: float = 30.0
			var yes_x: float = COL_RIGHT - 180.0
			var yes_y: float = card_y + (CARD_H - yes_h) / 2.0
			_confirm_yes_rect = Rect2(yes_x, yes_y, yes_w, yes_h)
			var yes_hov: bool = hover_section == "confirm_yes"
			draw_rect(_confirm_yes_rect,
				Color(0.55, 0.12, 0.12, 1.0) if yes_hov else Color(0.38, 0.08, 0.08, 1.0))
			draw_rect(_confirm_yes_rect, Color(0.85, 0.3, 0.3, 0.9), false, 1.5)
			var yw := font.get_string_size("DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(yes_x + (yes_w - yw) / 2.0, yes_y + 21.0),
				"DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

			# NO button
			var no_w: float = 72.0
			var no_x: float = COL_RIGHT - 95.0
			_confirm_no_rect = Rect2(no_x, yes_y, no_w, yes_h)
			var no_hov: bool = hover_section == "confirm_no"
			draw_rect(_confirm_no_rect,
				Color(0.28, 0.28, 0.38, 1.0) if no_hov else Color(0.18, 0.18, 0.26, 1.0))
			draw_rect(_confirm_no_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)
			var nw := font.get_string_size("CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(no_x + (no_w - nw) / 2.0, yes_y + 21.0),
				"CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.8, 1.0))

		else:
			# SELECT button
			var sel_w: float = 90.0
			var sel_h: float = 30.0
			var sel_x: float = COL_RIGHT - 200.0
			var sel_y: float = card_y + (CARD_H - sel_h) / 2.0
			var sel_rect := Rect2(sel_x, sel_y, sel_w, sel_h)

			var sel_hov: bool = hover_section == "select" and hover_index == i
			draw_rect(sel_rect,
				Color(0.15, 0.45, 0.2, 1.0) if sel_hov else Color(0.1, 0.3, 0.14, 1.0))
			draw_rect(sel_rect, Color(0.3, 0.85, 0.45, 0.85), false, 1.5)
			var sw := font.get_string_size("SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, Vector2(sel_x + (sel_w - sw) / 2.0, sel_y + 21.0),
				"SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

			# DELETE button
			var del_w: float = 80.0
			var del_x: float = COL_RIGHT - 95.0
			var del_rect := Rect2(del_x, sel_y, del_w, sel_h)
			var can_del: bool = ProfileManager.can_delete(p["id"])
			var del_hov: bool = can_del and hover_section == "delete" and hover_index == i

			if can_del:
				draw_rect(del_rect,
					Color(0.42, 0.1, 0.1, 1.0) if del_hov else Color(0.28, 0.08, 0.08, 1.0))
				draw_rect(del_rect, Color(0.75, 0.25, 0.25, 0.85), false, 1.5)
			else:
				draw_rect(del_rect, Color(0.12, 0.12, 0.18, 1.0))
				draw_rect(del_rect, Color(0.28, 0.28, 0.35, 0.4), false, 1.5)

			var dw := font.get_string_size("DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(del_x + (del_w - dw) / 2.0, sel_y + 21.0),
				"DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.9, 0.5, 0.5, 1.0) if can_del else Color(0.3, 0.3, 0.38, 1.0))

			if not is_confirm:
				_select_rects.append(sel_rect)
				_delete_rects.append(del_rect)
			non_active_i += 1


func _draw_bottom_buttons() -> void:
	var font := ThemeDB.fallback_font
	var cx: float  = ARENA_WIDTH / 2.0
	# Position below last card + gap
	var cards_bottom: float = 110.0 + ProfileManager.profiles.size() * (CARD_H + CARD_GAP) + 20.0

	# NEW PROFILE button (centred)
	var np_w: float = 220.0
	var np_h: float = 48.0
	_new_profile_rect = Rect2(cx - np_w / 2.0, cards_bottom, np_w, np_h)

	var np_hov: bool = hover_section == "new_profile"
	draw_rect(_new_profile_rect,
		Color(0.18, 0.28, 0.48, 1.0) if np_hov else Color(0.12, 0.18, 0.3, 1.0))
	draw_rect(_new_profile_rect, Color(0.35, 0.55, 0.9, 0.85), false, 2.0)

	var np_lbl := "+ NEW PROFILE"
	var np_sz: int = 20
	var np_w2 := font.get_string_size(np_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, np_sz).x
	draw_string(font, Vector2(cx - np_w2 / 2.0, cards_bottom + 32.0), np_lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, np_sz,
		Color.WHITE if np_hov else Color(0.75, 0.85, 1.0, 1.0))

	# BACK button (bottom-left)
	var bw: float = 120.0
	var bh: float = 36.0
	_back_rect = Rect2(COL_LEFT, cards_bottom + 6.0, bw, bh)

	var back_hov: bool = hover_section == "back"
	draw_rect(_back_rect,
		Color(0.35, 0.35, 0.45, 1.0) if back_hov else Color(0.2, 0.2, 0.28, 1.0))
	draw_rect(_back_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)

	var bl  := "← Back"
	var blsz := 18
	var blw  := font.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, blsz).x
	draw_string(font, Vector2(COL_LEFT + (bw - blw) / 2.0, _back_rect.position.y + 25.0), bl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, blsz, Color(0.7, 0.7, 0.8, 1.0))
