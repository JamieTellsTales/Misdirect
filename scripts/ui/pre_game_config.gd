extends Node2D
class_name PreGameConfig
## Pre-game configuration screen — drawn entirely via _draw()
## Player selects one Power Up and any number of Modifiers before play.

const ARENA_WIDTH: float = 1280.0
const ARENA_HEIGHT: float = 720.0

# ── Layout ───────────────────────────────────────────────────────────────────
const COL_LEFT: float = 180.0    # Left margin for option rows
const COL_RADIO: float = 180.0   # Radio/checkbox circle centre X
const COL_LABEL: float = 210.0   # Label start X
const COL_DESC: float = 420.0    # Description start X
const ROW_HEIGHT: float = 52.0
const SECTION_GAP: float = 36.0

# Sections start Y positions (calculated in _draw)
var power_up_start_y: float = 0.0
var modifier_start_y: float = 0.0
var play_button_rect: Rect2 = Rect2()
var back_button_rect: Rect2 = Rect2()

# Mouse state
var hover_section: String = ""  # "power_up", "buy", "modifier", "play", "back"
var hover_index: int = -1

# Buy rects for locked power-ups — populated each draw frame
var _pu_buy_rects: Array = []  # Array of {rect, id, price, index}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore last selections for this profile, filtering out anything no longer unlocked.
	if StatsManager.is_powerup_unlocked(StatsManager.last_power_up):
		GameConfig.selected_power_up = StatsManager.last_power_up
	else:
		GameConfig.selected_power_up = ""
	GameConfig.active_modifiers = []
	for mod_id in StatsManager.last_modifiers:
		var found: Dictionary = {}
		for m in GameConfig.MODIFIERS:
			if m["id"] == mod_id:
				found = m
				break
		if not found.is_empty() and _is_modifier_unlocked(found):
			GameConfig.active_modifiers.append(mod_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/map_select.tscn")

	if event.is_action_pressed("ui_accept"):
		_start_game()


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	hover_index = -1

	# BUY buttons on locked power-up rows take priority
	for entry in _pu_buy_rects:
		if entry.rect.has_point(pos):
			hover_section = "buy"
			hover_index = entry.index
			return

	for i in GameConfig.POWER_UPS.size():
		var pu: Dictionary = GameConfig.POWER_UPS[i]
		var row_y: float = power_up_start_y + i * ROW_HEIGHT
		var rect := Rect2(COL_RADIO - 16, row_y - 20, ARENA_WIDTH - COL_RADIO - 60, 40)
		if rect.has_point(pos):
			if StatsManager.is_powerup_unlocked(pu["id"]):
				hover_section = "power_up"
				hover_index = i
			return

	for i in GameConfig.MODIFIERS.size():
		var mod: Dictionary = GameConfig.MODIFIERS[i]
		var row_y: float = modifier_start_y + i * ROW_HEIGHT
		var rect := Rect2(COL_RADIO - 16, row_y - 20, ARENA_WIDTH - COL_RADIO - 60, 40)
		if rect.has_point(pos):
			if _is_modifier_unlocked(mod):
				hover_section = "modifier"
				hover_index = i
			return

	if play_button_rect.has_point(pos):
		hover_section = "play"
		return

	if back_button_rect.has_point(pos):
		hover_section = "back"


func _handle_click(pos: Vector2) -> void:
	# BUY buttons on locked power-ups
	for entry in _pu_buy_rects:
		if entry.rect.has_point(pos):
			StatsManager.unlock_powerup(entry.id, entry.price)
			return

	# Power up (radio — one at a time, click again to deselect; locked items ignored)
	for i in GameConfig.POWER_UPS.size():
		var pu: Dictionary = GameConfig.POWER_UPS[i]
		var row_y: float = power_up_start_y + i * ROW_HEIGHT
		var rect := Rect2(COL_RADIO - 16, row_y - 20, ARENA_WIDTH - COL_RADIO - 60, 40)
		if rect.has_point(pos):
			if StatsManager.is_powerup_unlocked(pu["id"]):
				GameConfig.set_power_up(pu["id"])
			return

	# Modifiers (checkbox — toggle; locked modifiers are ignored)
	for i in GameConfig.MODIFIERS.size():
		var mod: Dictionary = GameConfig.MODIFIERS[i]
		var row_y: float = modifier_start_y + i * ROW_HEIGHT
		var rect := Rect2(COL_RADIO - 16, row_y - 20, ARENA_WIDTH - COL_RADIO - 60, 40)
		if rect.has_point(pos):
			if _is_modifier_unlocked(mod):
				GameConfig.toggle_modifier(mod["id"])
			return

	if play_button_rect.has_point(pos):
		_start_game()

	if back_button_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _start_game() -> void:
	StatsManager.save_last_selections(GameConfig.selected_power_up, GameConfig.active_modifiers)
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_power_ups()
	_draw_modifiers()
	_draw_buttons()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color(0.07, 0.07, 0.12, 1.0))

	# Faint decoration matching main menu style
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

	var ca: float = 0.08
	draw_circle(Vector2(0, 0), 200, Color(Color.DODGER_BLUE, ca))
	draw_circle(Vector2(ARENA_WIDTH, 0), 200, Color(Color.CRIMSON, ca))
	draw_circle(Vector2(0, ARENA_HEIGHT), 200, Color(Color.FOREST_GREEN, ca))
	draw_circle(Vector2(ARENA_WIDTH, ARENA_HEIGHT), 200, Color(Color.GOLD, ca))


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0

	var title := "MISDIRECT"
	var tsz: int = 48
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Pre-Game Setup"
	var ssz: int = 20
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(cx - sw / 2.0, 100), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.58, 1.0))

	# Points balance — top-right, above the divider line
	var pts_text := "%d pts available" % StatsManager.points
	var pts_sz: int = 16
	var pts_w := font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_sz).x
	draw_string(font, Vector2(ARENA_WIDTH - COL_LEFT - pts_w, 98), pts_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pts_sz, Color(0.4, 0.9, 0.4, 1.0))

	draw_line(Vector2(COL_LEFT, 115), Vector2(ARENA_WIDTH - COL_LEFT, 115),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_power_ups() -> void:
	var font := ThemeDB.fallback_font
	power_up_start_y = 160.0
	_pu_buy_rects.clear()

	# Section header
	_draw_section_header(font, "POWER UP", "select one", power_up_start_y - 30.0)

	for i in GameConfig.POWER_UPS.size():
		var pu: Dictionary = GameConfig.POWER_UPS[i]
		var row_y: float = power_up_start_y + i * ROW_HEIGHT
		var is_unlocked: bool = StatsManager.is_powerup_unlocked(pu["id"])
		var is_selected: bool = GameConfig.selected_power_up == pu["id"]
		var is_hovered: bool = hover_section == "power_up" and hover_index == i

		if is_unlocked:
			_draw_radio(Vector2(COL_RADIO, row_y), is_selected, is_hovered)
			_draw_option_text(font, pu["label"], pu["desc"], row_y, is_selected, is_hovered)
		else:
			_draw_radio(Vector2(COL_RADIO, row_y), false, false, true)
			_draw_locked_power_up_row(font, pu, row_y, i)

	# Calculate where modifiers section begins
	modifier_start_y = power_up_start_y + GameConfig.POWER_UPS.size() * ROW_HEIGHT + SECTION_GAP + 40.0


func _draw_modifiers() -> void:
	var font := ThemeDB.fallback_font

	draw_line(Vector2(COL_LEFT, modifier_start_y - 48.0),
		Vector2(ARENA_WIDTH - COL_LEFT, modifier_start_y - 48.0),
		Color(0.3, 0.3, 0.4, 0.4), 1.0)

	_draw_section_header(font, "MODIFIERS", "add as many as you like", modifier_start_y - 30.0)

	for i in GameConfig.MODIFIERS.size():
		var mod: Dictionary = GameConfig.MODIFIERS[i]
		var row_y: float = modifier_start_y + i * ROW_HEIGHT
		var is_active: bool = GameConfig.has_modifier(mod["id"])
		var is_hovered: bool = hover_section == "modifier" and hover_index == i

		if _is_modifier_unlocked(mod):
			_draw_checkbox(Vector2(COL_RADIO, row_y), is_active, is_hovered)
			_draw_option_text(font, mod["label"], mod["desc"], row_y, is_active, is_hovered)
		else:
			_draw_checkbox_locked(Vector2(COL_RADIO, row_y))
			_draw_locked_modifier_row(font, mod, row_y)


func _draw_buttons() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0

	var btn_y: float = modifier_start_y + GameConfig.MODIFIERS.size() * ROW_HEIGHT + 50.0
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

	# Back button (smaller, bottom-left area)
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


func _is_modifier_unlocked(mod: Dictionary) -> bool:
	## Returns true if the modifier has no unlock_wins gate, or the player has enough wins.
	if not mod.has("unlock_wins"):
		return true
	return StatsManager.wins >= mod["unlock_wins"]


func _draw_locked_modifier_row(font: Font, mod: Dictionary, row_y: float) -> void:
	## Renders a locked modifier row: dimmed label + "Unlocks at X wins" hint.
	draw_string(font, Vector2(COL_LABEL, row_y + 7.0), mod["label"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.35, 0.35, 0.42, 1.0))

	var req_wins: int = mod.get("unlock_wins", 0)
	var lock_text := "Unlocks at %d wins  (%d so far)" % [req_wins, StatsManager.wins]
	draw_string(font, Vector2(COL_DESC, row_y + 7.0), lock_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.48, 0.28, 0.9))


func _draw_checkbox_locked(center: Vector2) -> void:
	## Renders a dimmed, un-interactable checkbox indicating a locked modifier.
	var box_half: float = 10.0
	var rect := Rect2(center - Vector2(box_half, box_half), Vector2(box_half * 2, box_half * 2))
	draw_rect(rect, Color(0.1, 0.1, 0.15, 1.0))
	draw_rect(rect, Color(0.28, 0.28, 0.35, 0.5), false, 2.0)


func _draw_locked_power_up_row(font: Font, pu: Dictionary, row_y: float, idx: int) -> void:
	# Dimmed name
	draw_string(font, Vector2(COL_LABEL, row_y + 7.0), pu["label"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.35, 0.35, 0.42, 1.0))

	# Price label
	var can_afford: bool = pu["price"] == 0 or StatsManager.points >= pu["price"]
	var price_text := "%d pts" % pu["price"]
	var price_col := Color(0.95, 0.82, 0.3, 1.0) if can_afford else Color(0.5, 0.5, 0.52, 1.0)
	draw_string(font, Vector2(COL_DESC, row_y + 7.0), price_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, price_col)

	# BUY button
	var btn_w := 64.0
	var btn_h := 26.0
	var btn_x := COL_DESC + 80.0
	var btn_y := row_y - 9.0
	var btn_rect := Rect2(btn_x, btn_y, btn_w, btn_h)

	var is_buy_hovered: bool = hover_section == "buy" and hover_index == idx
	var btn_bg: Color
	var btn_text_col: Color
	if can_afford:
		btn_bg = Color(0.18, 0.55, 0.22, 1.0) if is_buy_hovered else Color(0.12, 0.38, 0.16, 1.0)
		btn_text_col = Color.WHITE
	else:
		btn_bg = Color(0.14, 0.14, 0.2, 1.0)
		btn_text_col = Color(0.38, 0.38, 0.44, 1.0)

	draw_rect(btn_rect, btn_bg)
	var btn_brd := Color(0.3, 0.82, 0.4, 0.85) if can_afford else Color(0.28, 0.28, 0.38, 0.5)
	draw_rect(btn_rect, btn_brd, false, 1.5)

	var buy_lbl := "BUY"
	var buy_size := 14
	var buy_w := font.get_string_size(buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_size).x
	draw_string(font, Vector2(btn_x + (btn_w - buy_w) / 2.0, btn_y + 18.0),
		buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_size, btn_text_col)

	if can_afford:
		_pu_buy_rects.append({"rect": btn_rect, "id": pu["id"], "price": pu["price"], "index": idx})


# ── Helpers ──────────────────────────────────────────────────────────────────

func _draw_section_header(font: Font, title: String, subtitle: String, y: float) -> void:
	var tsz: int = 22
	draw_string(font, Vector2(COL_LABEL, y), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.75, 0.75, 0.85, 1.0))

	var ssz: int = 14
	var subtitle_x: float = COL_LABEL + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x + 16.0
	draw_string(font, Vector2(subtitle_x, y - 2.0), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.55, 1.0))


func _draw_radio(center: Vector2, selected: bool, hovered: bool, locked: bool = false) -> void:
	var ring_col: Color
	if locked:
		ring_col = Color(0.3, 0.3, 0.38, 1.0)
	elif hovered:
		ring_col = Color(0.7, 0.7, 0.85, 1.0)
	else:
		ring_col = Color(0.45, 0.45, 0.6, 1.0)
	draw_arc(center, 10.0, 0, TAU, 24, ring_col, 2.0)

	if selected and not locked:
		draw_circle(center, 5.5, Color(0.3, 0.9, 0.45, 1.0))


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
		# Tick mark
		var font := ThemeDB.fallback_font
		draw_string(font, center + Vector2(-6, 7), "✓",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_option_text(font: Font, label: String, desc: String,
		row_y: float, active: bool, hovered: bool) -> void:
	var label_col: Color
	if active:
		label_col = Color(1.0, 1.0, 1.0, 1.0)
	elif hovered:
		label_col = Color(0.85, 0.85, 0.95, 1.0)
	else:
		label_col = Color(0.6, 0.6, 0.72, 1.0)

	draw_string(font, Vector2(COL_LABEL, row_y + 7.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, label_col)

	var desc_col := Color(0.5, 0.5, 0.62, 1.0) if not active else Color(0.65, 0.75, 0.65, 1.0)
	draw_string(font, Vector2(COL_DESC, row_y + 7.0), desc,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, desc_col)
