extends Node2D
## Profile setup screen — first-run name entry and profile creation.
## Also used when adding a new profile from the profile select screen.
## All drawing done via _draw() consistent with the rest of the UI codebase.

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0
const COL_LEFT:     float = 180.0
const COL_RIGHT:    float = ARENA_WIDTH - 180.0
const MAX_NAME:     int   = 20

# ── State ─────────────────────────────────────────────────────────────────────

var name_text:      String = ""
var cursor_timer:   float  = 0.0   # Blinks every 0.5 s
var cursor_visible: bool   = true

# Mouse state
var hover_section:  String = ""   # "create", "settings", "back"

# Rects (computed each draw call)
var _create_rect:   Rect2 = Rect2()
var _settings_rect: Rect2 = Rect2()
var _back_rect:     Rect2 = Rect2()
var _name_box_rect: Rect2 = Rect2()

# Whether we have a back destination (false = first-run, no back option)
var show_back: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Show a back button when there is already at least one profile
	show_back = not ProfileManager.profiles.is_empty()


func _process(delta: float) -> void:
	cursor_timer += delta
	if cursor_timer >= 0.5:
		cursor_timer = 0.0
		cursor_visible = not cursor_visible
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
		return

	if event is InputEventKey and event.pressed:
		_handle_key(event)


func _update_hover(pos: Vector2) -> void:
	hover_section = ""
	if _create_rect.has_point(pos) and _name_is_valid():
		hover_section = "create"
	elif _settings_rect.has_point(pos):
		hover_section = "settings"
	elif show_back and _back_rect.has_point(pos):
		hover_section = "back"


func _handle_click(pos: Vector2) -> void:
	if _create_rect.has_point(pos) and _name_is_valid():
		_create_profile()
	elif _settings_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/settings_screen.tscn")
	elif show_back and _back_rect.has_point(pos):
		get_tree().change_scene_to_file("res://scenes/profile_select.tscn")


func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE:
		if name_text.length() > 0:
			name_text = name_text.left(name_text.length() - 1)
		cursor_visible = true
		cursor_timer = 0.0
		return

	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _name_is_valid():
			_create_profile()
		return

	if event.keycode == KEY_ESCAPE and show_back:
		get_tree().change_scene_to_file("res://scenes/profile_select.tscn")
		return

	# Printable character
	if event.unicode > 0 and name_text.length() < MAX_NAME:
		var ch := char(event.unicode)
		if _is_allowed_char(ch):
			name_text += ch
			cursor_visible = true
			cursor_timer = 0.0


func _is_allowed_char(ch: String) -> bool:
	var code := ch.unicode_at(0)
	# Letters (upper/lower), digits, space, hyphen, apostrophe, underscore
	return (code >= 65 and code <= 90) or \
		   (code >= 97 and code <= 122) or \
		   (code >= 48 and code <= 57) or \
		   code == 32 or code == 45 or code == 39 or code == 95


func _name_is_valid() -> bool:
	return name_text.strip_edges().length() > 0


func _create_profile() -> void:
	ProfileManager.create_profile(name_text.strip_edges())
	StatsManager.load_stats()   # Reload for the new profile
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_name_field()
	_draw_sections()
	_draw_create_button()
	if show_back:
		_draw_back_button()


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

	var title := "MISDIRECT"
	var tsz: int = 48
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Create Your Profile"
	var ssz: int = 20
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(cx - sw / 2.0, 100), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.58, 1.0))

	draw_line(Vector2(COL_LEFT, 115), Vector2(COL_RIGHT, 115),
		Color(0.3, 0.3, 0.4, 0.6), 1.0)


func _draw_name_field() -> void:
	var font := ThemeDB.fallback_font
	var section_y: float = 155.0

	# Section label
	draw_string(font, Vector2(COL_LEFT, section_y), "PLAYER NAME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.85, 1.0))

	# Input box
	var box_y: float = section_y + 12.0
	var box_h: float = 44.0
	_name_box_rect = Rect2(COL_LEFT, box_y, COL_RIGHT - COL_LEFT, box_h)

	draw_rect(_name_box_rect, Color(0.1, 0.1, 0.18, 1.0))
	draw_rect(_name_box_rect, Color(0.35, 0.55, 0.9, 0.85), false, 2.0)

	# Text + blinking cursor
	var display_text := name_text + ("█" if cursor_visible else " ")
	draw_string(font, Vector2(COL_LEFT + 14.0, box_y + 30.0), display_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.9, 1.0, 1.0))

	# Character count hint
	var count_text := "%d / %d" % [name_text.length(), MAX_NAME]
	var csz: int = 13
	var cw := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, csz).x
	draw_string(font, Vector2(COL_RIGHT - cw, box_y + 58.0), count_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, csz, Color(0.4, 0.4, 0.5, 0.8))


func _draw_sections() -> void:
	var font := ThemeDB.fallback_font
	var start_y: float = 290.0
	var row_h: float   = 56.0

	draw_line(Vector2(COL_LEFT, start_y - 12.0), Vector2(COL_RIGHT, start_y - 12.0),
		Color(0.3, 0.3, 0.4, 0.4), 1.0)

	# ── Localisation (placeholder) ─────────────────────────────────────────────
	var y1: float = start_y + 20.0
	draw_string(font, Vector2(COL_LEFT, y1), "LOCALISATION",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.4, 0.5, 1.0))
	draw_string(font, Vector2(COL_LEFT + 220.0, y1), "Coming soon",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.32, 0.32, 0.42, 0.9))

	# ── Keyboard Settings (placeholder) ───────────────────────────────────────
	var y2: float = start_y + row_h + 20.0
	draw_string(font, Vector2(COL_LEFT, y2), "KEYBOARD SETTINGS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.4, 0.5, 1.0))
	draw_string(font, Vector2(COL_LEFT + 260.0, y2), "Coming soon",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.32, 0.32, 0.42, 0.9))

	# ── Audio & Display ────────────────────────────────────────────────────────
	var y3: float = start_y + row_h * 2.0 + 20.0
	draw_string(font, Vector2(COL_LEFT, y3), "AUDIO & DISPLAY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.6, 0.72, 1.0))

	# SETTINGS → button
	var btn_label := "SETTINGS  →"
	var btn_sz: int = 15
	var btn_w := font.get_string_size(btn_label, HORIZONTAL_ALIGNMENT_LEFT, -1, btn_sz).x + 24.0
	var btn_h := 30.0
	var btn_x := COL_LEFT + 240.0
	var btn_y := y3 - 18.0
	_settings_rect = Rect2(btn_x, btn_y, btn_w, btn_h)

	var is_set_hov: bool = hover_section == "settings"
	var btn_bg := Color(0.18, 0.28, 0.48, 1.0) if is_set_hov else Color(0.12, 0.18, 0.3, 1.0)
	draw_rect(_settings_rect, btn_bg)
	draw_rect(_settings_rect, Color(0.35, 0.55, 0.9, 0.7), false, 1.5)
	draw_string(font, Vector2(btn_x + 10.0, btn_y + 21.0), btn_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, btn_sz,
		Color(0.75, 0.85, 1.0, 1.0) if is_set_hov else Color(0.55, 0.65, 0.85, 1.0))

	draw_line(Vector2(COL_LEFT, start_y + row_h * 3.0 + 12.0),
		Vector2(COL_RIGHT, start_y + row_h * 3.0 + 12.0),
		Color(0.3, 0.3, 0.4, 0.4), 1.0)


func _draw_create_button() -> void:
	var font := ThemeDB.fallback_font
	var cx: float = ARENA_WIDTH / 2.0
	var btn_y: float = 590.0
	var btn_w: float = 260.0
	var btn_h: float = 52.0
	_create_rect = Rect2(cx - btn_w / 2.0, btn_y, btn_w, btn_h)

	var valid: bool  = _name_is_valid()
	var hov: bool    = hover_section == "create"

	var bg: Color
	var border: Color
	var label_col: Color
	if valid:
		bg         = Color(0.15, 0.55, 0.2, 1.0) if hov else Color(0.1, 0.4, 0.15, 1.0)
		border     = Color(0.3, 0.9, 0.4, 0.9)
		label_col  = Color.WHITE
	else:
		bg         = Color(0.1, 0.1, 0.15, 1.0)
		border     = Color(0.3, 0.3, 0.38, 0.5)
		label_col  = Color(0.35, 0.35, 0.42, 1.0)

	draw_rect(_create_rect, bg)
	draw_rect(_create_rect, border, false, 2.0)

	var lbl  := "CREATE PROFILE"
	var lsz  := 24
	var lw   := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x
	draw_string(font, Vector2(cx - lw / 2.0, btn_y + 34.0), lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, label_col)

	if not valid:
		var hint := "Enter a name to continue"
		var hsz  := 13
		var hw   := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz).x
		draw_string(font, Vector2(cx - hw / 2.0, btn_y + 64.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hsz, Color(0.4, 0.4, 0.5, 0.75))


func _draw_back_button() -> void:
	var font := ThemeDB.fallback_font
	var bw: float = 120.0
	var bh: float = 36.0
	_back_rect = Rect2(COL_LEFT, 590.0 + 8.0, bw, bh)

	var hov: bool    = hover_section == "back"
	var back_col := Color(0.35, 0.35, 0.45, 1.0) if hov else Color(0.2, 0.2, 0.28, 1.0)
	draw_rect(_back_rect, back_col)
	draw_rect(_back_rect, Color(0.45, 0.45, 0.55, 0.7), false, 1.5)

	var lbl  := "← Back"
	var lsz  := 18
	var lw   := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x
	draw_string(font, Vector2(COL_LEFT + (bw - lw) / 2.0, _back_rect.position.y + 25.0), lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, Color(0.7, 0.7, 0.8, 1.0))
