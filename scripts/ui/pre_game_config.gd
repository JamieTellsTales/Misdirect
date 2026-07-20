extends Node2D
class_name PreGameConfig
## Pre-game configuration screen — drawn entirely via _draw()
## Player assigns power-ups to key slots and selects modifiers before play.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

# ── Layout ───────────────────────────────────────────────────────────────────
const COL_LEFT:      float = 180.0
const COL_LABEL:     float = 210.0
const ROW_HEIGHT:    float = 52.0
const SECTION_GAP:   float = 36.0

# Modifier chip grid
const MOD_COLS:      int   = 4
const MOD_CHIP_H:    float = 38.0
const MOD_CHIP_GAP_X: float = 10.0
const MOD_CHIP_GAP_Y: float = 10.0

# Slot row column positions
const SLOT_KEY_X:    float = 202.0   # left edge of key label box
const SLOT_KEY_W:    float = 148.0   # width of key label box
const SLOT_KEY_H:    float = 32.0    # height of key label box
const SLOT_ASSIGN_X: float = 362.0   # left edge of power-up dropdown
const SLOT_ASSIGN_W: float = 200.0   # width of dropdown area
const SLOT_STATUS_X: float = 578.0   # left edge of status / BUY SLOT area

# Picker overlay dimensions
const PICKER_X:        float = 220.0
const PICKER_W:        float = 840.0
const PICKER_ROW_H:    float = 50.0
const PICKER_HEADER_H: float = 54.0
const PICKER_PAD:      float = 14.0

# ── State ────────────────────────────────────────────────────────────────────
var slot_start_y:    float = 0.0
var modifier_start_y: float = 0.0
var play_button_rect: Rect2 = Rect2()
var back_button_rect: Rect2 = Rect2()

var hover_section: String = ""
var hover_index:   int    = -1
var _prev_hover_section: String = ""
var _prev_hover_index:   int    = -1

# Slot UI hit-rects (populated each draw frame)
var _slot_assign_rects:      Array = []   # [{rect, slot_idx}]
var _slot_buy_rects:         Array = []   # [{rect, slot_idx}]
var _modifier_chip_rects:    Array = []   # Rect2 per modifier (index matches MODIFIERS)
var _modifier_section_end_y: float = 0.0 # Bottom of chip grid; used by buttons

# Picker state
var _open_slot_picker:    int   = -1   # slot whose picker is open; -1 = none
var _picker_option_rects: Array = []   # [{rect, pu_id}]
var _picker_buy_rects:    Array = []   # [{rect, pu_id, price}]


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore last slot assignments for this profile
	var saved: Array = StatsManager.last_power_up_slots
	for i in GameConfig.POWER_UP_SLOT_DEFS.size():
		var pu_id: String = saved[i] if i < saved.size() else ""
		# Keep the saved assignment only if it's owned AND its kind matches this
		# slot (active power-ups in the active slot, passives in passive slots).
		var kind_ok: bool = pu_id == "" or GameConfig.powerup_kind(pu_id) == GameConfig.slot_kind(i)
		if pu_id == "" or (StatsManager.is_powerup_unlocked(pu_id) and kind_ok):
			GameConfig.power_up_slots[i] = pu_id
		else:
			GameConfig.power_up_slots[i] = ""
	# Restore modifiers
	GameConfig.active_modifiers = []
	for mod_id in StatsManager.last_modifiers:
		var found: Dictionary = {}
		for m in GameConfig.MODIFIERS:
			if m["id"] == mod_id:
				found = m
				break
		if not found.is_empty() and _is_modifier_unlocked(found) \
				and GameConfig.is_modifier_compatible(mod_id):
			GameConfig.active_modifiers.append(mod_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

	if event.is_action_pressed("ui_cancel"):
		if _open_slot_picker >= 0:
			_open_slot_picker = -1
			get_viewport().set_input_as_handled()
			return
		get_tree().change_scene_to_file("res://scenes/map_select.tscn")

	if event.is_action_pressed("ui_accept") and _open_slot_picker < 0:
		_start_game()


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	hover_index   = -1

	# Picker overlay captures hover when open
	if _open_slot_picker >= 0:
		for i in _picker_option_rects.size():
			if _picker_option_rects[i].rect.has_point(pos):
				hover_section = "picker_option"
				hover_index   = i
				return
		for i in _picker_buy_rects.size():
			if _picker_buy_rects[i].rect.has_point(pos):
				hover_section = "picker_buy"
				hover_index   = i
				return
		return  # Picker absorbs all hover

	# Slot BUY SLOT buttons
	for entry in _slot_buy_rects:
		if entry.rect.has_point(pos):
			hover_section = "slot_buy"
			hover_index   = entry.slot_idx
			return

	# Slot assignment areas (only unlocked slots)
	for entry in _slot_assign_rects:
		if entry.rect.has_point(pos):
			hover_section = "slot_assign"
			hover_index   = entry.slot_idx
			return

	# Modifier chips
	for i in _modifier_chip_rects.size():
		if _modifier_chip_rects[i].has_point(pos):
			hover_section = "modifier"
			hover_index   = i
			return

	if play_button_rect.has_point(pos):
		hover_section = "play"
		return
	if back_button_rect.has_point(pos):
		hover_section = "back"

	if hover_section != "" and (hover_section != _prev_hover_section or hover_index != _prev_hover_index):
		AudioManager.play_button_hover()
	_prev_hover_section = hover_section
	_prev_hover_index   = hover_index


func _handle_click(pos: Vector2) -> void:
	# Picker captures all clicks when open
	if _open_slot_picker >= 0:
		# Option rows (select power-up into the slot)
		for entry in _picker_option_rects:
			if entry.rect.has_point(pos):
				AudioManager.play_button_click()
				_assign_to_slot(_open_slot_picker, entry.pu_id)
				_open_slot_picker = -1
				return
		# BUY buttons inside picker
		for entry in _picker_buy_rects:
			if entry.rect.has_point(pos):
				AudioManager.play_button_click()
				StatsManager.unlock_powerup(entry.pu_id, entry.price)
				return  # Stay open so player can now select it
		# Clicked outside picker — dismiss
		_open_slot_picker = -1
		return

	# Slot BUY SLOT buttons
	for entry in _slot_buy_rects:
		if entry.rect.has_point(pos):
			AudioManager.play_button_click()
			var def: Dictionary = GameConfig.POWER_UP_SLOT_DEFS[entry.slot_idx]
			StatsManager.unlock_slot(entry.slot_idx, def["unlock_price"])
			return

	# Slot assignment areas — open picker
	for entry in _slot_assign_rects:
		if entry.rect.has_point(pos):
			AudioManager.play_button_click()
			_open_slot_picker = entry.slot_idx
			return

	# Modifier chips
	for i in _modifier_chip_rects.size():
		if _modifier_chip_rects[i].has_point(pos):
			var mod: Dictionary = GameConfig.MODIFIERS[i]
			if _is_modifier_unlocked(mod) and GameConfig.is_modifier_compatible(mod["id"]):
				AudioManager.play_button_click()
				GameConfig.toggle_modifier(mod["id"])
			return

	if play_button_rect.has_point(pos):
		_start_game()
	elif back_button_rect.has_point(pos):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _assign_to_slot(slot_idx: int, pu_id: String) -> void:
	## Assign a power-up to a slot. If it was already in another slot, clear that slot.
	for i in GameConfig.power_up_slots.size():
		if i != slot_idx and GameConfig.power_up_slots[i] == pu_id:
			GameConfig.power_up_slots[i] = ""
	GameConfig.power_up_slots[slot_idx] = pu_id


func _start_game() -> void:
	AudioManager.play_button_click()
	StatsManager.save_last_slot_selections(GameConfig.power_up_slots, GameConfig.active_modifiers)
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_power_up_slots()
	_draw_modifiers()
	_draw_buttons()
	if _open_slot_picker >= 0:
		_draw_slot_picker()
	CornerHUD.draw_on(self)


func _draw_background() -> void:
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0
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
	var ca: float = 0.08
	draw_circle(Vector2(0, 0), 200, Color(Color.DODGER_BLUE, ca))
	draw_circle(Vector2(sw, 0), 200, Color(Color.CRIMSON, ca))
	draw_circle(Vector2(0, sh), 200, Color(Color.FOREST_GREEN, ca))
	draw_circle(Vector2(sw, sh), 200, Color(Color.GOLD, ca))


func _draw_header() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	var cx: float = sw / 2.0

	var title := "MISDIRECT"
	var tsz: int = 48
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Pre-Game Setup"
	var ssz: int = 20
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(cx - sub_w / 2.0, 100), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.58, 1.0))

	var pts_text := "%d tokens available" % StatsManager.tokens
	var pts_sz: int = 16
	var pts_w := font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_sz).x
	draw_string(font, Vector2(sw - COL_LEFT - pts_w, 98), pts_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pts_sz, Color(0.4, 0.9, 0.4, 1.0))

	draw_line(Vector2(COL_LEFT, 115), Vector2(sw - COL_LEFT, 115),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


# ── Power-up slots section ────────────────────────────────────────────────────

func _draw_power_up_slots() -> void:
	var font := FontManager.get_font()
	slot_start_y = 160.0
	_slot_assign_rects.clear()
	_slot_buy_rects.clear()

	_draw_section_header(font, "POWER-UP SLOTS", "one active (hold SPACE) + two passive (always on)", slot_start_y - 30.0)

	var level: int = StatsManager.get_level()

	for i in GameConfig.POWER_UP_SLOT_DEFS.size():
		var def: Dictionary     = GameConfig.POWER_UP_SLOT_DEFS[i]
		var row_y: float        = slot_start_y + i * ROW_HEIGHT
		var level_ok: bool      = level >= def["unlock_level"]
		var slot_owned: bool    = StatsManager.is_slot_unlocked(i)
		var can_afford: bool    = StatsManager.tokens >= def["unlock_price"]
		var assigned_id: String = GameConfig.power_up_slots[i]
		var is_hovered_assign: bool = hover_section == "slot_assign" and hover_index == i
		var is_hovered_buy:    bool = hover_section == "slot_buy"    and hover_index == i

		# ── Key label box ────────────────────────────────────────────────────
		var key_box_y: float = row_y - SLOT_KEY_H / 2.0
		var key_rect := Rect2(SLOT_KEY_X, key_box_y, SLOT_KEY_W, SLOT_KEY_H)
		var key_bg: Color
		if not slot_owned:
			key_bg = Color(0.1, 0.1, 0.15, 1.0)
		else:
			key_bg = Color(0.15, 0.22, 0.32, 1.0)
		draw_rect(key_rect, key_bg)
		draw_rect(key_rect, Color(0.3, 0.4, 0.55, 0.6) if slot_owned else Color(0.22, 0.22, 0.3, 0.5), false, 1.5)

		var key_col: Color = Color(0.6, 0.75, 0.9, 1.0) if slot_owned else Color(0.3, 0.3, 0.38, 1.0)
		var key_sz: int = 13
		var key_tw := font.get_string_size(def["key_label"], HORIZONTAL_ALIGNMENT_LEFT, -1, key_sz).x
		var key_tx: float = SLOT_KEY_X + (SLOT_KEY_W - key_tw) / 2.0
		draw_string(font, Vector2(key_tx, row_y + 5.0), def["key_label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, key_sz, key_col)

		# ── Assignment area or lock info ──────────────────────────────────────
		if slot_owned:
			# Clickable dropdown showing assigned power-up
			var label_str: String
			if assigned_id == "":
				label_str = "— Empty —"
			else:
				label_str = _power_up_label(assigned_id)
			var assign_rect := Rect2(SLOT_ASSIGN_X, key_box_y, SLOT_ASSIGN_W, SLOT_KEY_H)
			var assign_bg: Color
			if is_hovered_assign:
				assign_bg = Color(0.18, 0.3, 0.42, 1.0)
			elif assigned_id != "":
				assign_bg = Color(0.12, 0.22, 0.16, 1.0)
			else:
				assign_bg = Color(0.1, 0.1, 0.16, 1.0)
			draw_rect(assign_rect, assign_bg)
			var bord_col: Color
			if assigned_id != "":
				bord_col = Color(0.3, 0.7, 0.45, 0.8)
			elif is_hovered_assign:
				bord_col = Color(0.4, 0.55, 0.7, 0.9)
			else:
				bord_col = Color(0.28, 0.28, 0.38, 0.5)
			draw_rect(assign_rect, bord_col, false, 1.5)

			var lbl_col: Color = Color(0.9, 1.0, 0.9, 1.0) if assigned_id != "" else Color(0.42, 0.42, 0.5, 1.0)
			var lbl_sz: int = 14
			draw_string(font, Vector2(SLOT_ASSIGN_X + 10.0, row_y + 5.0), label_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz, lbl_col)
			# Dropdown arrow
			var arr_x: float = SLOT_ASSIGN_X + SLOT_ASSIGN_W - 18.0
			draw_string(font, Vector2(arr_x, row_y + 5.0), "▾",
				HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz, Color(0.5, 0.6, 0.7, 0.8))

			_slot_assign_rects.append({"rect": assign_rect, "slot_idx": i})

		elif level_ok:
			# Level met, but slot not yet purchased — show BUY SLOT button
			var lock_hint := "Slot unlocked by level — pay to activate"
			draw_string(font, Vector2(SLOT_ASSIGN_X, row_y + 5.0), lock_hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.55, 0.35, 0.9))

			# BUY SLOT button
			var btn_w: float = 170.0
			var btn_h: float = 28.0
			var btn_y: float = row_y - btn_h / 2.0
			var btn_rect := Rect2(SLOT_STATUS_X, btn_y, btn_w, btn_h)
			var btn_bg: Color
			var btn_tc: Color
			if can_afford:
				btn_bg = Color(0.2, 0.52, 0.25, 1.0) if is_hovered_buy else Color(0.13, 0.36, 0.17, 1.0)
				btn_tc = Color.WHITE
			else:
				btn_bg = Color(0.14, 0.14, 0.2, 1.0)
				btn_tc = Color(0.35, 0.35, 0.42, 1.0)
			draw_rect(btn_rect, btn_bg)
			var btn_brd: Color = Color(0.35, 0.85, 0.45, 0.85) if can_afford else Color(0.25, 0.25, 0.35, 0.5)
			draw_rect(btn_rect, btn_brd, false, 1.5)
			var buy_lbl := "UNLOCK  %d tokens" % def["unlock_price"]
			var buy_sz: int = 13
			var buy_tw := font.get_string_size(buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_sz).x
			draw_string(font, Vector2(SLOT_STATUS_X + (btn_w - buy_tw) / 2.0, row_y + 5.0),
				buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_sz, btn_tc)
			if can_afford:
				_slot_buy_rects.append({"rect": btn_rect, "slot_idx": i})

		else:
			# Level not met — grey out with requirement text
			var req_text := "Level %d required  (you are level %d)" % [def["unlock_level"], level]
			draw_string(font, Vector2(SLOT_ASSIGN_X, row_y + 5.0), req_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.45, 0.28, 0.9))

	modifier_start_y = slot_start_y + GameConfig.POWER_UP_SLOT_DEFS.size() * ROW_HEIGHT + SECTION_GAP + 40.0


func _slot_pickable_powerups(slot_idx: int) -> Array:
	## Power-ups offered for a slot: "None" plus every power-up whose kind matches
	## the slot's kind (active slot lists active abilities, passive slots passives).
	var kind: String = GameConfig.slot_kind(slot_idx)
	var out: Array = []
	for pu in GameConfig.POWER_UPS:
		if pu["id"] == "" or pu.get("kind", "") == kind:
			out.append(pu)
	return out


func _draw_slot_picker() -> void:
	## Draw the power-up picker overlay for _open_slot_picker.
	var font := FontManager.get_font()
	_picker_option_rects.clear()
	_picker_buy_rects.clear()

	var options: Array = _slot_pickable_powerups(_open_slot_picker)
	var n_rows: int    = options.size()
	var picker_h: float = PICKER_HEADER_H + n_rows * PICKER_ROW_H + PICKER_PAD * 2.0
	var sh: float = get_viewport_rect().size.y
	var sw: float = get_viewport_rect().size.x
	var picker_y: float = (sh - picker_h) / 2.0

	# Dimmer
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.0, 0.0, 0.0, 0.6))

	# Panel background
	draw_rect(Rect2(PICKER_X, picker_y, PICKER_W, picker_h), Color(0.1, 0.1, 0.16, 1.0))
	draw_rect(Rect2(PICKER_X, picker_y, PICKER_W, picker_h), Color(0.35, 0.45, 0.65, 0.85), false, 2.0)

	# Header
	var kind: String = GameConfig.slot_kind(_open_slot_picker)
	var title_str: String = "Choose an ACTIVE power-up" if kind == "active" else "Choose a PASSIVE power-up"
	var title_sz: int = 20
	var title_w := font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz).x
	var header_cx: float = PICKER_X + PICKER_W / 2.0
	draw_string(font, Vector2(header_cx - title_w / 2.0, picker_y + 34.0), title_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz, Color(0.75, 0.85, 1.0, 1.0))
	draw_line(
		Vector2(PICKER_X + 16.0, picker_y + PICKER_HEADER_H),
		Vector2(PICKER_X + PICKER_W - 16.0, picker_y + PICKER_HEADER_H),
		Color(0.3, 0.35, 0.5, 0.6), 1.0)

	# Power-up rows (includes "None" at index 0 with id "")
	for i in n_rows:
		var pu: Dictionary  = options[i]
		var pu_id: String   = pu["id"]
		var row_y: float    = picker_y + PICKER_HEADER_H + PICKER_PAD + i * PICKER_ROW_H
		var mid_y: float    = row_y + PICKER_ROW_H / 2.0
		var row_rect := Rect2(PICKER_X + 8.0, row_y, PICKER_W - 16.0, PICKER_ROW_H)

		var is_current: bool   = GameConfig.power_up_slots[_open_slot_picker] == pu_id
		var is_owned: bool     = StatsManager.is_powerup_unlocked(pu_id)
		var is_hov_opt: bool   = hover_section == "picker_option" and hover_index == i
		var can_buy: bool      = (not is_owned) and pu_id != "" and StatsManager.tokens >= pu["price"]
		var can_afford: bool   = StatsManager.tokens >= pu.get("price", 0)

		# Row background
		var row_bg: Color
		if is_current:
			row_bg = Color(0.12, 0.28, 0.18, 1.0)
		elif is_hov_opt and is_owned:
			row_bg = Color(0.15, 0.2, 0.3, 1.0)
		else:
			row_bg = Color(0.0, 0.0, 0.0, 0.0)
		if row_bg.a > 0.0:
			draw_rect(row_rect, row_bg)
		if is_current:
			draw_rect(row_rect, Color(0.3, 0.75, 0.45, 0.7), false, 1.5)

		# Selection dot
		var dot_x: float = PICKER_X + 28.0
		if is_current:
			draw_circle(Vector2(dot_x, mid_y), 5.0, Color(0.3, 0.9, 0.45, 1.0))
		else:
			draw_arc(Vector2(dot_x, mid_y), 5.0, 0.0, TAU, 16,
				Color(0.35, 0.35, 0.5, 0.6) if is_owned else Color(0.25, 0.25, 0.32, 0.5), 1.5)

		# Power-up name
		var name_col: Color
		if is_current:
			name_col = Color(0.9, 1.0, 0.9, 1.0)
		elif is_owned:
			name_col = Color(0.72, 0.72, 0.85, 1.0) if not is_hov_opt else Color(0.9, 0.9, 1.0, 1.0)
		else:
			name_col = Color(0.38, 0.38, 0.45, 1.0)
		var name_sz: int = 18
		draw_string(font, Vector2(PICKER_X + 46.0, mid_y + 6.0), pu["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_sz, name_col)

		# Description
		if is_owned or pu_id == "":
			var desc_col: Color = Color(0.5, 0.58, 0.5, 1.0) if is_current else Color(0.38, 0.38, 0.48, 1.0)
			draw_string(font, Vector2(PICKER_X + 280.0, mid_y + 6.0), pu["desc"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, desc_col)
		else:
			# Not owned — show price and maybe BUY button
			var price: int = pu.get("price", 0)
			var price_col: Color = Color(0.9, 0.78, 0.25, 1.0) if can_afford else Color(0.4, 0.4, 0.45, 1.0)
			draw_string(font, Vector2(PICKER_X + 280.0, mid_y + 6.0), "%d tokens" % price,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, price_col)

			var btn_w: float = 72.0
			var btn_h: float = 26.0
			var btn_x: float = PICKER_X + PICKER_W - btn_w - 20.0
			var btn_y2: float = mid_y - btn_h / 2.0
			var btn_rect2 := Rect2(btn_x, btn_y2, btn_w, btn_h)
			var is_hov_buy: bool = hover_section == "picker_buy" and hover_index == i
			var bbg: Color = Color(0.2, 0.55, 0.25, 1.0) if (is_hov_buy and can_afford) else (Color(0.13, 0.38, 0.17, 1.0) if can_afford else Color(0.14, 0.14, 0.2, 1.0))
			draw_rect(btn_rect2, bbg)
			var bbrd: Color = Color(0.35, 0.88, 0.45, 0.85) if can_afford else Color(0.25, 0.25, 0.35, 0.5)
			draw_rect(btn_rect2, bbrd, false, 1.5)
			var buy_lbl := "BUY"
			var buy_sz: int = 14
			var buy_w := font.get_string_size(buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_sz).x
			var btc: Color = Color.WHITE if can_afford else Color(0.35, 0.35, 0.42, 1.0)
			draw_string(font, Vector2(btn_x + (btn_w - buy_w) / 2.0, mid_y + 5.0), buy_lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, buy_sz, btc)
			if can_afford:
				_picker_buy_rects.append({"rect": btn_rect2, "pu_id": pu_id, "price": price, "index": i})

		# Register option rect for owned items (and "None")
		if is_owned or pu_id == "":
			_picker_option_rects.append({"rect": row_rect, "pu_id": pu_id})
		else:
			_picker_option_rects.append({"rect": Rect2(), "pu_id": pu_id})  # non-clickable placeholder

	# Close hint
	var close_hint := "Click outside or press Esc to cancel"
	var ch_sz: int = 12
	var ch_w := font.get_string_size(close_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, ch_sz).x
	draw_string(font, Vector2(header_cx - ch_w / 2.0, picker_y + picker_h - 8.0), close_hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ch_sz, Color(0.35, 0.35, 0.45, 0.8))


# ── Modifiers section ─────────────────────────────────────────────────────────

func _draw_modifiers() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	_modifier_chip_rects.clear()

	draw_line(Vector2(COL_LEFT, modifier_start_y - 48.0),
		Vector2(sw - COL_LEFT, modifier_start_y - 48.0),
		Color(0.3, 0.3, 0.4, 0.4), 1.0)

	_draw_section_header(font, "MODIFIERS", "hover for description — toggle to activate", modifier_start_y - 30.0)

	# Chip grid dimensions
	var usable_w: float  = sw - COL_LEFT * 2.0
	var chip_w: float    = (usable_w - MOD_CHIP_GAP_X * (MOD_COLS - 1)) / MOD_COLS
	var level: int       = StatsManager.get_level()

	for i in GameConfig.MODIFIERS.size():
		var mod: Dictionary  = GameConfig.MODIFIERS[i]
		var col: int         = i % MOD_COLS
		var row: int         = i / MOD_COLS
		var chip_x: float    = COL_LEFT + col * (chip_w + MOD_CHIP_GAP_X)
		var chip_y: float    = modifier_start_y + row * (MOD_CHIP_H + MOD_CHIP_GAP_Y)
		var chip_rect        := Rect2(chip_x, chip_y, chip_w, MOD_CHIP_H)
		_modifier_chip_rects.append(chip_rect)

		var is_active:     bool = GameConfig.has_modifier(mod["id"])
		var is_hovered:    bool = hover_section == "modifier" and hover_index == i
		var is_unlocked:   bool = _is_modifier_unlocked(mod)
		var is_compatible: bool = GameConfig.is_modifier_compatible(mod["id"])
		# Disabled = can't be toggled right now (locked OR wrong game mode).
		var is_disabled:   bool = not is_unlocked or not is_compatible

		# Chip background
		var bg: Color
		if is_disabled:
			bg = Color(0.09, 0.09, 0.13, 1.0)
		elif is_active:
			bg = Color(0.1, 0.28, 0.14, 1.0)
		elif is_hovered:
			bg = Color(0.16, 0.17, 0.26, 1.0)
		else:
			bg = Color(0.11, 0.11, 0.18, 1.0)
		draw_rect(chip_rect, bg)

		# Chip border
		var border: Color
		if is_disabled:
			border = Color(0.22, 0.22, 0.28, 0.5)
		elif is_active:
			border = Color(0.35, 0.88, 0.48, 0.85)
		elif is_hovered:
			border = Color(0.45, 0.5, 0.7, 0.8)
		else:
			border = Color(0.28, 0.28, 0.4, 0.55)
		draw_rect(chip_rect, border, false, 1.5)

		# Checkbox / lock / incompatible indicator on the left
		var check_cx: float = chip_x + 16.0
		var check_cy: float = chip_y + MOD_CHIP_H / 2.0
		if not is_unlocked:
			# Lock icon (small padlock drawn with lines)
			draw_arc(Vector2(check_cx, check_cy - 2.0), 5.0, PI, TAU, 10, Color(0.35, 0.35, 0.42, 0.8), 1.5)
			draw_rect(Rect2(check_cx - 5.0, check_cy - 1.0, 10.0, 8.0), Color(0.28, 0.28, 0.35, 0.8))
		elif not is_compatible:
			# Unavailable in this mode — draw a small "no" bar.
			draw_line(Vector2(check_cx - 6.0, check_cy), Vector2(check_cx + 6.0, check_cy),
				Color(0.5, 0.4, 0.3, 0.8), 2.0)
		else:
			# Small checkbox
			var cb_half: float = 7.0
			var cb_rect := Rect2(check_cx - cb_half, check_cy - cb_half, cb_half * 2.0, cb_half * 2.0)
			draw_rect(cb_rect, Color(0.2, 0.7, 0.35, 1.0) if is_active else Color(0.12, 0.12, 0.18, 1.0))
			draw_rect(cb_rect, Color(0.35, 0.95, 0.5, 1.0) if is_active else Color(0.32, 0.32, 0.45, 0.7), false, 1.5)
			if is_active:
				draw_string(font, Vector2(check_cx - 5.0, check_cy + 5.0), "✓",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

		# Label text
		var label_col: Color
		if is_disabled:
			label_col = Color(0.32, 0.32, 0.38, 1.0)
		elif is_active:
			label_col = Color(0.95, 1.0, 0.95, 1.0)
		elif is_hovered:
			label_col = Color(0.85, 0.85, 0.95, 1.0)
		else:
			label_col = Color(0.6, 0.6, 0.72, 1.0)
		var lbl_sz: int = 14
		draw_string(font, Vector2(chip_x + 30.0, chip_y + MOD_CHIP_H / 2.0 + 5.0),
			mod["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz, label_col)

		# Right-edge hint: unlock level if locked, or "timed only" if wrong mode
		var hint_text: String = ""
		if not is_unlocked:
			hint_text = "Lv %d" % mod.get("unlock_level", 0)
		elif not is_compatible:
			hint_text = "timed only"
		if hint_text != "":
			var lh_sz: int = 11
			var lh_w: float = font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, lh_sz).x
			draw_string(font, Vector2(chip_x + chip_w - lh_w - 8.0, chip_y + MOD_CHIP_H / 2.0 + 4.0),
				hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, lh_sz, Color(0.55, 0.45, 0.25, 0.85))

	# Track where chips end
	var n_rows: int = ceili(float(GameConfig.MODIFIERS.size()) / float(MOD_COLS))
	_modifier_section_end_y = modifier_start_y + n_rows * (MOD_CHIP_H + MOD_CHIP_GAP_Y) - MOD_CHIP_GAP_Y

	# Tooltip bar — show description of hovered modifier
	if hover_section == "modifier" and hover_index >= 0 and hover_index < GameConfig.MODIFIERS.size():
		var hov_mod: Dictionary = GameConfig.MODIFIERS[hover_index]
		var tip_y: float        = _modifier_section_end_y + 10.0
		var tip_h: float        = 32.0
		var is_ul: bool         = _is_modifier_unlocked(hov_mod)
		var tip_bg_col: Color   = Color(0.1, 0.14, 0.22, 0.95) if is_ul else Color(0.1, 0.1, 0.14, 0.95)
		var sw2: float = get_viewport_rect().size.x
		draw_rect(Rect2(COL_LEFT, tip_y, sw2 - COL_LEFT * 2.0, tip_h), tip_bg_col)
		draw_rect(Rect2(COL_LEFT, tip_y, sw2 - COL_LEFT * 2.0, tip_h),
			Color(0.35, 0.45, 0.65, 0.6) if is_ul else Color(0.3, 0.3, 0.4, 0.4), false, 1.0)

		var is_compat: bool = GameConfig.is_modifier_compatible(hov_mod["id"])
		var tip_text: String
		if not is_ul:
			var req: int = hov_mod.get("unlock_level", 0)
			tip_text = "%s — Unlocks at level %d  (you are level %d)" % [hov_mod["label"], req, level]
		elif not is_compat:
			tip_text = "%s — Only available in timed modes (Normal)" % hov_mod["label"]
		else:
			tip_text = "%s — %s" % [hov_mod["label"], hov_mod["desc"]]
		draw_string(font, Vector2(COL_LEFT + 14.0, tip_y + 21.0), tip_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.75, 0.85, 1.0, 1.0) if (is_ul and is_compat) else Color(0.55, 0.5, 0.35, 0.9))


func _draw_buttons() -> void:
	var font := FontManager.get_font()
	var cx: float = get_viewport_rect().size.x / 2.0

	# Leave room for the tooltip bar (32px) + spacing
	var btn_y: float = _modifier_section_end_y + 56.0
	var play_w: float = 200.0
	var play_h: float = 52.0
	play_button_rect = Rect2(cx - play_w / 2.0, btn_y, play_w, play_h)

	var play_hover: bool = hover_section == "play"
	var play_bg := Color(0.15, 0.55, 0.2, 1.0) if play_hover else Color(0.1, 0.4, 0.15, 1.0)
	draw_rect(play_button_rect, play_bg)
	draw_rect(play_button_rect, Color(0.3, 0.9, 0.4, 0.9), false, 2.0)

	var play_text := "PLAY"
	var psz: int = 28
	var pw := font.get_string_size(play_text, HORIZONTAL_ALIGNMENT_LEFT, -1, psz).x
	draw_string(font, Vector2(cx - pw / 2.0, btn_y + 34.0), play_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, psz, Color.WHITE)

	var back_w: float = 120.0
	var back_h: float = 36.0
	back_button_rect = Rect2(COL_LEFT, btn_y + 8.0, back_w, back_h)

	var back_hover: bool = hover_section == "back"
	var back_col := Color(0.35, 0.35, 0.45, 1.0) if back_hover else Color(0.2, 0.2, 0.28, 1.0)
	draw_rect(back_button_rect, back_col)
	draw_rect(back_button_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)

	var back_text := "← Back"
	var bsz: int = 18
	var bw := font.get_string_size(back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
	draw_string(font, Vector2(COL_LEFT + (back_w - bw) / 2.0, btn_y + 28.0), back_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color(0.7, 0.7, 0.8, 1.0))


# ── Helpers ──────────────────────────────────────────────────────────────────

func _power_up_label(pu_id: String) -> String:
	for pu in GameConfig.POWER_UPS:
		if pu["id"] == pu_id:
			return pu["label"]
	return pu_id


func _is_modifier_unlocked(mod: Dictionary) -> bool:
	if not mod.has("unlock_level"):
		return true
	return StatsManager.get_level() >= mod["unlock_level"]


func _draw_locked_modifier_row(_font: Font, _mod: Dictionary, _row_y: float) -> void:
	pass  # Replaced by chip grid — kept to avoid break if called from legacy code


func _draw_checkbox_locked(center: Vector2) -> void:
	var box_half: float = 10.0
	var rect := Rect2(center - Vector2(box_half, box_half), Vector2(box_half * 2, box_half * 2))
	draw_rect(rect, Color(0.1, 0.1, 0.15, 1.0))
	draw_rect(rect, Color(0.28, 0.28, 0.35, 0.5), false, 2.0)


func _draw_section_header(font: Font, title: String, subtitle: String, y: float) -> void:
	var tsz: int = 22
	draw_string(font, Vector2(COL_LABEL, y), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.75, 0.75, 0.85, 1.0))
	var ssz: int = 14
	var subtitle_x: float = COL_LABEL + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x + 16.0
	draw_string(font, Vector2(subtitle_x, y - 2.0), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.55, 1.0))


func _draw_checkbox(center: Vector2, checked: bool, hovered: bool) -> void:
	var box_half: float = 10.0
	var rect := Rect2(center - Vector2(box_half, box_half), Vector2(box_half * 2, box_half * 2))
	var bg := Color(0.2, 0.7, 0.35, 1.0) if checked else Color(0.12, 0.12, 0.18, 1.0)
	if hovered and not checked:
		bg = Color(0.18, 0.18, 0.28, 1.0)
	draw_rect(rect, bg)
	var border := Color(0.45, 0.45, 0.6, 1.0) if not checked else Color(0.35, 0.95, 0.5, 1.0)
	draw_rect(rect, border, false, 2.0)
	if checked:
		var font := FontManager.get_font()
		draw_string(font, center + Vector2(-6, 7), "✓",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_option_text(_font: Font, _label: String, _desc: String,
		_row_y: float, _active: bool, _hovered: bool) -> void:
	pass  # Replaced by chip grid — kept to avoid break if called from legacy code
