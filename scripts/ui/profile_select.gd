extends Node2D
## Profile selection screen — switch, rename, delete, or create profiles.
## All drawing done via _draw() consistent with the rest of the UI codebase.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

var _sw: float = 1280.0
var _sh: float = 720.0
const COL_LEFT:     float = 180.0
var _COL_RIGHT: float = 1280.0 - 180.0
const CARD_H:       float = 96.0
const CARD_GAP:     float = 16.0
const MAX_NAME:     int   = 20
const HEADER_H:     float = 100.0   # fixed header height
const FOOTER_H:     float = 80.0    # fixed footer height
const SCROLL_SPEED: float = 32.0

# ── State ─────────────────────────────────────────────────────────────────────

var _confirm_delete_id: String = ""
var _rename_id:         String = ""
var _rename_text:       String = ""
var _rename_cursor_timer:   float = 0.0
var _rename_cursor_visible: bool  = true

# Mouse hover
var hover_section: String = ""
var hover_index:   int    = -1
var _prev_hover_section: String = ""
var _prev_hover_index:   int    = -1

# Rects populated each draw call
var _select_rects:       Array = []
var _delete_rects:       Array = []
var _rename_rects:       Array = []
var _confirm_yes_rect:   Rect2 = Rect2()
var _confirm_no_rect:    Rect2 = Rect2()
var _rename_save_rect:   Rect2 = Rect2()
var _rename_cancel_rect: Rect2 = Rect2()
var _new_profile_rect:   Rect2 = Rect2()
var _back_rect:          Rect2 = Rect2()

# Scroll
var _scroll_offset: float = 0.0

# Drag reorder
var _mouse_down:       bool    = false
var _mouse_down_pos:   Vector2 = Vector2.ZERO
var _drag_profile_idx: int     = -1
var _drag_current_pos: Vector2 = Vector2.ZERO
var _drag_active:      bool    = false
var _drag_insert_idx:  int     = -1

# Stats cache: id -> {wins, losses, tokens, level, xp_in}
var _stats_cache: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_stats_cache()


func _process(delta: float) -> void:
	if not _rename_id.is_empty():
		_rename_cursor_timer += delta
		if _rename_cursor_timer >= 0.5:
			_rename_cursor_timer = 0.0
			_rename_cursor_visible = not _rename_cursor_visible
	queue_redraw()


func _max_scroll() -> float:
	var scroll_area_h: float = _sh - HEADER_H - FOOTER_H
	var content_h: float = float(ProfileManager.profiles.size()) * (CARD_H + CARD_GAP)
	return maxf(0.0, content_h - scroll_area_h)


func _unhandled_input(event: InputEvent) -> void:
	# ── Rename text input ──────────────────────────────────────────────────────
	if not _rename_id.is_empty():
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_rename_id = ""
				_rename_text = ""
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_commit_rename()
				return
			if event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE:
				if _rename_text.length() > 0:
					_rename_text = _rename_text.left(_rename_text.length() - 1)
				_rename_cursor_visible = true
				_rename_cursor_timer = 0.0
				return
			if event.unicode > 0 and _rename_text.length() < MAX_NAME:
				var ch := char(event.unicode)
				if _is_allowed_char(ch):
					_rename_text += ch
					_rename_cursor_visible = true
					_rename_cursor_timer = 0.0
			return  # Eat all other key input while renaming
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position())
		return

	# ── Mouse wheel scroll ─────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset = maxf(0.0, _scroll_offset - SCROLL_SPEED * 3)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_offset = minf(_max_scroll(), _scroll_offset + SCROLL_SPEED * 3)
				return

	# ── Mouse button press / release ───────────────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_mouse_down(get_global_mouse_position())
		else:
			_on_mouse_up(get_global_mouse_position())
		return

	# ── Mouse motion ───────────────────────────────────────────────────────────
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
		_update_drag(get_global_mouse_position())
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_mouse_down(pos: Vector2) -> void:
	if not _confirm_delete_id.is_empty():
		_handle_click(pos)
		return
	_mouse_down       = true
	_mouse_down_pos   = pos
	_drag_active      = false
	_drag_profile_idx = _card_index_at(pos)


func _on_mouse_up(pos: Vector2) -> void:
	if _drag_active and _drag_profile_idx >= 0:
		_commit_drag_reorder()
	else:
		_handle_click(pos)
	_mouse_down       = false
	_drag_active      = false
	_drag_profile_idx = -1
	_drag_insert_idx  = -1
	queue_redraw()


func _update_drag(pos: Vector2) -> void:
	if not _mouse_down or _drag_profile_idx < 0:
		return
	if not _drag_active:
		if pos.distance_to(_mouse_down_pos) > 6.0:
			_drag_active = true
	if _drag_active:
		_drag_current_pos = pos
		_drag_insert_idx  = _insert_idx_at(pos)
		queue_redraw()


func _card_index_at(pos: Vector2) -> int:
	if pos.y < HEADER_H or pos.y > _sh - FOOTER_H:
		return -1
	var content_y: float = pos.y + _scroll_offset - HEADER_H
	if content_y < 0.0:
		return -1
	var idx: int = int(content_y / (CARD_H + CARD_GAP))
	if idx < 0 or idx >= ProfileManager.profiles.size():
		return -1
	var card_top: float = HEADER_H + float(idx) * (CARD_H + CARD_GAP) - _scroll_offset
	if pos.y >= card_top and pos.y <= card_top + CARD_H:
		return idx
	return -1


func _insert_idx_at(pos: Vector2) -> int:
	var content_y: float = pos.y + _scroll_offset - HEADER_H
	var n: int = ProfileManager.profiles.size()
	for i in range(n):
		var mid_y: float = float(i) * (CARD_H + CARD_GAP) + (CARD_H + CARD_GAP) / 2.0
		if content_y < mid_y:
			return i
	return n


func _commit_drag_reorder() -> void:
	var n: int    = ProfileManager.profiles.size()
	var from_idx: int = _drag_profile_idx
	var to_idx:   int = _drag_insert_idx  # may be 0..n (n = insert at end)
	if to_idx > from_idx:
		to_idx -= 1
	to_idx = clampi(to_idx, 0, n - 1)  # clamp after adjustment
	if to_idx == from_idx:
		return
	var item = ProfileManager.profiles[from_idx]
	ProfileManager.profiles.remove_at(from_idx)
	ProfileManager.profiles.insert(to_idx, item)
	ProfileManager._save_index()


func _is_allowed_char(ch: String) -> bool:
	var code := ch.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or \
		   (code >= 48 and code <= 57) or \
		   code == 32 or code == 45 or code == 39 or code == 95


func _commit_rename() -> void:
	var trimmed := _rename_text.strip_edges()
	if trimmed.length() > 0:
		ProfileManager.rename_profile(_rename_id, trimmed)
		_load_stats_cache()
	_rename_id = ""
	_rename_text = ""


func _update_hover(pos: Vector2) -> void:
	if _drag_active:
		hover_section = ""
		hover_index   = -1
		return

	hover_section = ""
	hover_index   = -1

	if not _rename_id.is_empty():
		if _rename_save_rect.has_point(pos):
			hover_section = "rename_save"
		elif _rename_cancel_rect.has_point(pos):
			hover_section = "rename_cancel"
		return

	if not _confirm_delete_id.is_empty():
		if _confirm_yes_rect.has_point(pos):
			hover_section = "confirm_yes"
			return
		if _confirm_no_rect.has_point(pos):
			hover_section = "confirm_no"
			return

	var non_active_i: int = 0
	for i in ProfileManager.profiles.size():
		var p: Dictionary = ProfileManager.profiles[i]
		var is_active: bool = p["id"] == ProfileManager.active_id
		if i < _rename_rects.size() and _rename_rects[i].has_point(pos):
			hover_section = "rename"
			hover_index   = i
			return
		if not is_active:
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

	if hover_section != "" and (hover_section != _prev_hover_section or hover_index != _prev_hover_index):
		AudioManager.play_button_hover()
	_prev_hover_section = hover_section
	_prev_hover_index   = hover_index


func _handle_click(pos: Vector2) -> void:
	if not _rename_id.is_empty():
		if _rename_save_rect.has_point(pos):
			AudioManager.play_button_click()
			_commit_rename()
		elif _rename_cancel_rect.has_point(pos):
			AudioManager.play_button_click()
			_rename_id = ""
			_rename_text = ""
		return

	if not _confirm_delete_id.is_empty():
		if _confirm_yes_rect.has_point(pos):
			AudioManager.play_button_click()
			ProfileManager.delete_profile(_confirm_delete_id)
			_confirm_delete_id = ""
			_load_stats_cache()
			return
		if _confirm_no_rect.has_point(pos):
			AudioManager.play_button_click()
			_confirm_delete_id = ""
			return
		_confirm_delete_id = ""
		return

	var non_active_i: int = 0
	for i in ProfileManager.profiles.size():
		var p: Dictionary   = ProfileManager.profiles[i]
		var is_active: bool = p["id"] == ProfileManager.active_id

		if i < _rename_rects.size() and _rename_rects[i].has_point(pos):
			AudioManager.play_button_click()
			_rename_id   = p["id"]
			_rename_text = p["name"]
			_rename_cursor_visible = true
			_rename_cursor_timer   = 0.0
			return

		if not is_active:
			if non_active_i < _select_rects.size() and _select_rects[non_active_i].has_point(pos):
				AudioManager.play_button_click()
				ProfileManager.switch_profile(p["id"])
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
				return
			if non_active_i < _delete_rects.size() and _delete_rects[non_active_i].has_point(pos):
				if ProfileManager.can_delete(p["id"]):
					AudioManager.play_button_click()
					_confirm_delete_id = p["id"]
				return
			non_active_i += 1

	if _new_profile_rect.has_point(pos):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/profile_setup.tscn")
	elif _back_rect.has_point(pos):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _load_stats_cache() -> void:
	_stats_cache.clear()
	for p in ProfileManager.profiles:
		var cfg  := ConfigFile.new()
		var path := ProfileManager.profile_dir(p["id"]) + "stats.cfg"
		var data: Dictionary = {"wins": 0, "losses": 0, "tokens": 0, "level": 0, "xp_in": 0}
		if cfg.load(path) == OK:
			data["wins"]   = cfg.get_value("stats", "wins",   0)
			data["losses"] = cfg.get_value("stats", "losses", 0)
			data["tokens"] = cfg.get_value("stats", "tokens", 0)
			var xp: int    = cfg.get_value("stats", "xp",     0)
			data["level"]  = mini(xp / 100, 999)
			data["xp_in"]  = xp % 100 if data["level"] < 999 else 99
		_stats_cache[p["id"]] = data


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_sw = get_viewport_rect().size.x
	_sh = get_viewport_rect().size.y
	_COL_RIGHT = _sw - 180.0
	_scroll_offset = clampf(_scroll_offset, 0.0, _max_scroll())
	_draw_background()
	_draw_profile_cards()
	# Fixed overlays drawn after cards so they cover anything that scrolled under them
	_draw_header()
	_draw_footer()
	_draw_scrollbar()
	if _drag_active and _drag_profile_idx >= 0:
		_draw_drag_ghost()
	CornerHUD.draw_on(self)


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(_sw, _sh)),
		Color(0.07, 0.07, 0.12, 1.0))
	var cx: float = _sw / 2.0
	var cy: float = _sh / 2.0
	var half: float = 380.0; var inset: float = 130.0
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
	draw_circle(Vector2(_sw, 0), 200, Color(Color.CRIMSON, ca))
	draw_circle(Vector2(0, _sh), 200, Color(Color.FOREST_GREEN, ca))
	draw_circle(Vector2(_sw, _sh), 200, Color(Color.GOLD, ca))


func _draw_header() -> void:
	# Opaque background covers any cards that have scrolled into the header area
	draw_rect(Rect2(0.0, 0.0, _sw, HEADER_H), Color(0.07, 0.07, 0.12, 1.0))
	var font := FontManager.get_font()
	var cx: float = _sw / 2.0
	var title := "PLAYER PROFILES"
	var tsz: int = 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)
	draw_line(Vector2(COL_LEFT, 90), Vector2(_COL_RIGHT, 90),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_footer() -> void:
	var font := FontManager.get_font()
	var cx: float    = _sw / 2.0
	var footer_y: float = _sh - FOOTER_H

	# Separator + opaque background
	draw_line(Vector2(0, footer_y), Vector2(_sw, footer_y), Color(0.3, 0.3, 0.4, 0.8), 1.0)
	draw_rect(Rect2(0, footer_y, _sw, FOOTER_H), Color(0.07, 0.07, 0.12, 1.0))

	var btn_top: float = footer_y + 8.0

	# NEW PROFILE
	var np_w: float = 220.0; var np_h: float = 48.0
	_new_profile_rect = Rect2(cx - np_w / 2.0, btn_top, np_w, np_h)
	var np_hov: bool = hover_section == "new_profile"
	draw_rect(_new_profile_rect,
		Color(0.18, 0.28, 0.48, 1.0) if np_hov else Color(0.12, 0.18, 0.3, 1.0))
	draw_rect(_new_profile_rect, Color(0.35, 0.55, 0.9, 0.85), false, 2.0)
	var np_lbl := "+ NEW PROFILE"; var np_sz: int = 20
	var np_lw := font.get_string_size(np_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, np_sz).x
	draw_string(font, Vector2(cx - np_lw / 2.0, btn_top + 32.0), np_lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, np_sz,
		Color.WHITE if np_hov else Color(0.75, 0.85, 1.0, 1.0))

	# BACK
	var bw: float = 120.0; var bh: float = 36.0
	_back_rect = Rect2(COL_LEFT, btn_top + 6.0, bw, bh)
	var back_hov: bool = hover_section == "back"
	draw_rect(_back_rect,
		Color(0.35, 0.35, 0.45, 1.0) if back_hov else Color(0.2, 0.2, 0.28, 1.0))
	draw_rect(_back_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)
	var bl := "← Back"; var blsz := 18
	var blw := font.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, blsz).x
	draw_string(font, Vector2(COL_LEFT + (bw - blw) / 2.0, _back_rect.position.y + 25.0), bl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, blsz, Color(0.7, 0.7, 0.8, 1.0))


func _draw_scrollbar() -> void:
	var scroll_area_h: float = _sh - HEADER_H - FOOTER_H
	var content_h: float     = float(ProfileManager.profiles.size()) * (CARD_H + CARD_GAP)
	if content_h <= scroll_area_h:
		return
	var track_h: float = scroll_area_h - 8.0
	var thumb_h: float = maxf(24.0, track_h * (scroll_area_h / content_h))
	var thumb_t: float = _scroll_offset / maxf(1.0, content_h - scroll_area_h)
	var thumb_y: float = HEADER_H + 4.0 + thumb_t * (track_h - thumb_h)
	draw_rect(Rect2(_sw - 8.0, HEADER_H + 4.0, 4.0, track_h), Color(0.2, 0.2, 0.3, 0.6))
	draw_rect(Rect2(_sw - 8.0, thumb_y, 4.0, thumb_h), Color(0.55, 0.55, 0.7, 0.9))


func _draw_profile_cards() -> void:
	var font := FontManager.get_font()
	_select_rects.clear()
	_delete_rects.clear()
	_rename_rects.clear()

	var non_active_i: int = 0

	for i in ProfileManager.profiles.size():
		var p: Dictionary    = ProfileManager.profiles[i]
		var is_active: bool  = p["id"] == ProfileManager.active_id
		var is_confirm: bool = p["id"] == _confirm_delete_id
		var is_renaming: bool = p["id"] == _rename_id

		# Screen-space Y for this card (accounts for scroll)
		var card_y: float  = HEADER_H + float(i) * (CARD_H + CARD_GAP) - _scroll_offset
		var card_w: float  = _COL_RIGHT - COL_LEFT
		var card_rect := Rect2(COL_LEFT, card_y, card_w, CARD_H)

		# Skip drawing if fully outside scroll area, but maintain rect arrays
		var in_view: bool = card_y + CARD_H > HEADER_H and card_y < _sh - FOOTER_H

		if not in_view:
			_rename_rects.append(Rect2())
			if not is_active:
				_select_rects.append(Rect2())
				_delete_rects.append(Rect2())
				non_active_i += 1
			continue

		# Card background
		var card_bg: Color
		var card_brd: Color
		if _drag_active and i == _drag_profile_idx:
			# Ghost placeholder — dimmed slot while card is being dragged
			card_bg  = Color(0.06, 0.06, 0.09, 0.4)
			card_brd = Color(0.2, 0.2, 0.3, 0.3)
			draw_rect(card_rect, card_bg)
			draw_rect(card_rect, card_brd, false, 1.0)
			_rename_rects.append(Rect2())
			if not is_active:
				_select_rects.append(Rect2())
				_delete_rects.append(Rect2())
				non_active_i += 1
			continue

		if is_renaming:
			card_bg  = Color(0.1, 0.15, 0.22, 1.0)
			card_brd = Color(0.35, 0.55, 0.9, 0.9)
		elif is_active:
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

		# Drag handle — three small lines on the left edge
		if not is_renaming and not is_confirm:
			for di in range(3):
				var dy: float = card_y + CARD_H / 2.0 - 4.0 + float(di) * 4.0
				draw_line(Vector2(COL_LEFT + 6.0, dy), Vector2(COL_LEFT + 14.0, dy),
					Color(0.35, 0.35, 0.5, 0.45), 1.5)

		if is_renaming:
			# ── Inline rename form ─────────────────────────────────────────────
			draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 22.0), "RENAME",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.65, 0.9, 0.9))

			var box_x: float = COL_LEFT + 20.0
			var box_w: float = card_w - 230.0
			var box_y: float = card_y + 34.0
			var box_h: float = 34.0
			draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.08, 0.12, 0.2, 1.0))
			draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.35, 0.55, 0.9, 0.85), false, 1.5)

			var display := _rename_text + ("█" if _rename_cursor_visible else " ")
			draw_string(font, Vector2(box_x + 10.0, box_y + 24.0), display,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 1.0, 1.0))

			var sv_w: float = 80.0; var sv_h: float = 34.0
			var sv_x: float = _COL_RIGHT - 185.0
			var sv_y: float = card_y + 31.0
			_rename_save_rect = Rect2(sv_x, sv_y, sv_w, sv_h)
			var sv_valid: bool = _rename_text.strip_edges().length() > 0
			var sv_hov: bool   = hover_section == "rename_save"
			if sv_valid:
				draw_rect(_rename_save_rect,
					Color(0.15, 0.5, 0.22, 1.0) if sv_hov else Color(0.1, 0.35, 0.15, 1.0))
				draw_rect(_rename_save_rect, Color(0.3, 0.85, 0.45, 0.9), false, 1.5)
			else:
				draw_rect(_rename_save_rect, Color(0.12, 0.12, 0.18, 1.0))
				draw_rect(_rename_save_rect, Color(0.3, 0.3, 0.38, 0.4), false, 1.5)
			var svlbl := "SAVE"
			var svw := font.get_string_size(svlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(sv_x + (sv_w - svw) / 2.0, sv_y + 23.0), svlbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color.WHITE if sv_valid else Color(0.35, 0.35, 0.42, 1.0))

			var cn_w: float = 80.0
			var cn_x: float = _COL_RIGHT - 95.0
			_rename_cancel_rect = Rect2(cn_x, sv_y, cn_w, sv_h)
			var cn_hov: bool = hover_section == "rename_cancel"
			draw_rect(_rename_cancel_rect,
				Color(0.28, 0.28, 0.38, 1.0) if cn_hov else Color(0.18, 0.18, 0.26, 1.0))
			draw_rect(_rename_cancel_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)
			var cnlbl := "CANCEL"
			var cnw := font.get_string_size(cnlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(cn_x + (cn_w - cnw) / 2.0, sv_y + 23.0), cnlbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.8, 1.0))

			_rename_rects.append(Rect2())

		elif is_confirm:
			# ── Delete confirmation ────────────────────────────────────────────
			var nsz: int = 22
			draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 32.0), p["name"] + "  —",
				HORIZONTAL_ALIGNMENT_LEFT, -1, nsz, Color(0.9, 0.55, 0.55, 1.0))
			draw_string(font, Vector2(COL_LEFT + 20.0, card_y + 58.0), "Delete this profile?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.5, 0.5, 1.0))

			var btn_h: float = 30.0; var btn_y: float = card_y + (CARD_H - btn_h) / 2.0

			var yes_w: float = 80.0; var yes_x: float = _COL_RIGHT - 185.0
			_confirm_yes_rect = Rect2(yes_x, btn_y, yes_w, btn_h)
			var yes_hov: bool = hover_section == "confirm_yes"
			draw_rect(_confirm_yes_rect,
				Color(0.55, 0.12, 0.12, 1.0) if yes_hov else Color(0.38, 0.08, 0.08, 1.0))
			draw_rect(_confirm_yes_rect, Color(0.85, 0.3, 0.3, 0.9), false, 1.5)
			var yw := font.get_string_size("DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(yes_x + (yes_w - yw) / 2.0, btn_y + 21.0),
				"DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

			var no_w: float = 80.0; var no_x: float = _COL_RIGHT - 95.0
			_confirm_no_rect = Rect2(no_x, btn_y, no_w, btn_h)
			var no_hov: bool = hover_section == "confirm_no"
			draw_rect(_confirm_no_rect,
				Color(0.28, 0.28, 0.38, 1.0) if no_hov else Color(0.18, 0.18, 0.26, 1.0))
			draw_rect(_confirm_no_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)
			var nw := font.get_string_size("CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(no_x + (no_w - nw) / 2.0, btn_y + 21.0),
				"CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.8, 1.0))

			_rename_rects.append(Rect2())

		else:
			# ── Normal card ────────────────────────────────────────────────────
			var nsz: int = 24
			draw_string(font, Vector2(COL_LEFT + 22.0, card_y + 32.0), p["name"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, nsz,
				Color.WHITE if is_active else Color(0.75, 0.75, 0.85, 1.0))

			var stats: Dictionary = _stats_cache.get(p["id"],
				{"wins": 0, "losses": 0, "tokens": 0, "level": 0, "xp_in": 0})
			var stat_text := "Lv %d  ·  %d wins  ·  %d losses  ·  %d tokens" % [
				stats["level"], stats["wins"], stats["losses"], stats["tokens"]]
			draw_string(font, Vector2(COL_LEFT + 22.0, card_y + 54.0), stat_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.5, 0.75, 0.55, 1.0) if is_active else Color(0.45, 0.45, 0.55, 1.0))

			# XP bar
			var bar_x: float = COL_LEFT + 12.0
			var bar_w: float = card_w - 24.0
			var bar_y: float = card_y + CARD_H - 16.0
			var bar_h: float = 5.0
			var xp_fill: float = float(stats["xp_in"]) / 100.0 if stats["level"] < 999 else 1.0
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.12, 0.12, 0.22, 1.0))
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.3, 0.3, 0.5, 0.5), false, 1.0)
			if xp_fill > 0.0:
				var fill_col := Color(0.3, 0.85, 0.45, 1.0) if is_active else Color(0.25, 0.6, 0.85, 1.0)
				draw_rect(Rect2(bar_x, bar_y, bar_w * xp_fill, bar_h), fill_col)

			var btn_h: float = 30.0
			var btn_y: float = card_y + (CARD_H - btn_h) / 2.0

			if is_active:
				var badge := "ACTIVE"
				var bsz: int = 13
				var bw2 := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
				draw_string(font, Vector2(_COL_RIGHT - 20.0 - bw2, card_y + 24.0), badge,
					HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color(0.3, 0.9, 0.45, 1.0))

				var rn_w: float = 80.0; var rn_x: float = _COL_RIGHT - 100.0
				var rn_y: float = card_y + 42.0
				var rn_rect := Rect2(rn_x, rn_y, rn_w, 26.0)
				var rn_hov: bool = hover_section == "rename" and hover_index == i
				draw_rect(rn_rect,
					Color(0.22, 0.32, 0.52, 1.0) if rn_hov else Color(0.14, 0.2, 0.34, 1.0))
				draw_rect(rn_rect, Color(0.35, 0.55, 0.85, 0.75), false, 1.5)
				var rnlbl := "RENAME"
				var rnw := font.get_string_size(rnlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_string(font, Vector2(rn_x + (rn_w - rnw) / 2.0, rn_y + 19.0), rnlbl,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.75, 0.85, 1.0, 1.0) if rn_hov else Color(0.55, 0.65, 0.85, 1.0))
				_rename_rects.append(rn_rect)

			else:
				# RENAME
				var rn_w: float = 80.0; var rn_x: float = _COL_RIGHT - 90.0
				var rn_rect := Rect2(rn_x, btn_y, rn_w, btn_h)
				var rn_hov: bool = hover_section == "rename" and hover_index == i
				draw_rect(rn_rect,
					Color(0.22, 0.32, 0.52, 1.0) if rn_hov else Color(0.14, 0.2, 0.34, 1.0))
				draw_rect(rn_rect, Color(0.35, 0.55, 0.85, 0.75), false, 1.5)
				var rnlbl := "RENAME"
				var rnw := font.get_string_size(rnlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_string(font, Vector2(rn_x + (rn_w - rnw) / 2.0, btn_y + 21.0), rnlbl,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.75, 0.85, 1.0, 1.0) if rn_hov else Color(0.55, 0.65, 0.85, 1.0))
				_rename_rects.append(rn_rect)

				# DELETE
				var del_w: float = 80.0; var del_x: float = _COL_RIGHT - 180.0
				var del_rect := Rect2(del_x, btn_y, del_w, btn_h)
				var can_del: bool = ProfileManager.can_delete(p["id"])
				var del_hov: bool = can_del and hover_section == "delete" and hover_index == i
				if can_del:
					draw_rect(del_rect,
						Color(0.42, 0.1, 0.1, 1.0) if del_hov else Color(0.28, 0.08, 0.08, 1.0))
					draw_rect(del_rect, Color(0.75, 0.25, 0.25, 0.85), false, 1.5)
				else:
					draw_rect(del_rect, Color(0.12, 0.12, 0.18, 1.0))
					draw_rect(del_rect, Color(0.28, 0.28, 0.35, 0.4), false, 1.5)
				var dw := font.get_string_size("DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_string(font, Vector2(del_x + (del_w - dw) / 2.0, btn_y + 21.0),
					"DELETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.9, 0.5, 0.5, 1.0) if can_del else Color(0.3, 0.3, 0.38, 1.0))

				# SELECT
				var sel_w: float = 90.0; var sel_x: float = _COL_RIGHT - 280.0
				var sel_rect := Rect2(sel_x, btn_y, sel_w, btn_h)
				var sel_hov: bool = hover_section == "select" and hover_index == i
				draw_rect(sel_rect,
					Color(0.15, 0.45, 0.2, 1.0) if sel_hov else Color(0.1, 0.3, 0.14, 1.0))
				draw_rect(sel_rect, Color(0.3, 0.85, 0.45, 0.85), false, 1.5)
				var sw := font.get_string_size("SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(font, Vector2(sel_x + (sel_w - sw) / 2.0, btn_y + 21.0),
					"SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

				_select_rects.append(sel_rect)
				_delete_rects.append(del_rect)
				non_active_i += 1


func _draw_drag_ghost() -> void:
	var font := FontManager.get_font()
	var n: int = ProfileManager.profiles.size()
	if _drag_profile_idx < 0 or _drag_profile_idx >= n:
		return

	# Insertion indicator line
	var line_y: float = HEADER_H + float(_drag_insert_idx) * (CARD_H + CARD_GAP) \
		- CARD_GAP / 2.0 - _scroll_offset
	line_y = clampf(line_y, HEADER_H + 2.0, _sh - FOOTER_H - 2.0)
	draw_line(Vector2(COL_LEFT, line_y), Vector2(_COL_RIGHT, line_y),
		Color(0.35, 0.7, 1.0, 0.9), 2.5)
	# Small arrow nubs at the ends
	draw_line(Vector2(COL_LEFT, line_y - 4), Vector2(COL_LEFT, line_y + 4),
		Color(0.35, 0.7, 1.0, 0.9), 2.0)
	draw_line(Vector2(_COL_RIGHT, line_y - 4), Vector2(_COL_RIGHT, line_y + 4),
		Color(0.35, 0.7, 1.0, 0.9), 2.0)

	# Ghost card following cursor
	var p: Dictionary = ProfileManager.profiles[_drag_profile_idx]
	var card_w: float  = _COL_RIGHT - COL_LEFT
	var ghost_y: float = _drag_current_pos.y - CARD_H / 2.0
	var ghost_rect := Rect2(COL_LEFT, ghost_y, card_w, CARD_H)
	draw_rect(ghost_rect, Color(0.14, 0.22, 0.38, 0.92))
	draw_rect(ghost_rect, Color(0.35, 0.7, 1.0, 0.9), false, 2.0)
	draw_string(font, Vector2(COL_LEFT + 22.0, ghost_y + 36.0), p["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.85, 0.92, 1.0, 0.95))
	draw_string(font, Vector2(COL_LEFT + 22.0, ghost_y + 58.0), "drag to reorder",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.6, 0.85, 0.65))
