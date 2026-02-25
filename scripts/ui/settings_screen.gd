extends Node2D
class_name SettingsScreen
## Settings screen — fully drawn via _draw() / _input(), no Control nodes.
## Changes are previewed live; only committed to disk on "Save & Back".

const W: float = 1280.0
const H: float = 720.0
const CX: float = W / 2.0

# Layout constants
const LABEL_X: float = 220.0   # Left-align label column
const CTRL_X: float  = 530.0   # Left edge of control column
const CTRL_W: float  = 400.0   # Width of sliders / selectors
const ROW_H: float   = 58.0

# Row Y positions
const Y_DISPLAY_HDR: float = 148.0
const Y_RESOLUTION:  float = 192.0
const Y_FULLSCREEN:  float = 250.0
const Y_VSYNC:       float = 308.0
const Y_AUDIO_HDR:   float = 382.0
const Y_MASTER:      float = 426.0
const Y_MUSIC:       float = 484.0
const Y_SFX:         float = 542.0
const Y_BUTTONS:     float = 618.0

# Working copies — only written to SettingsManager on save
var work: Dictionary = {}

# Slider drag state
var dragging_slider: String = ""  # "", "master", "music", "sfx"

# Hover state
var hover: String = ""

# Clickable rects (populated in _draw)
var res_left_rect:   Rect2 = Rect2()
var res_right_rect:  Rect2 = Rect2()
var fs_rect:         Rect2 = Rect2()
var vsync_rect:      Rect2 = Rect2()
var save_rect:       Rect2 = Rect2()
var discard_rect:    Rect2 = Rect2()

# Slider track rects
var sliders: Dictionary = {}  # name -> Rect2


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_copy_from_manager()


func _copy_from_manager() -> void:
	work = {
		"fullscreen":       SettingsManager.fullscreen,
		"vsync":            SettingsManager.vsync,
		"resolution_index": SettingsManager.resolution_index,
		"master_volume":    SettingsManager.master_volume,
		"music_volume":     SettingsManager.music_volume,
		"sfx_volume":       SettingsManager.sfx_volume,
	}


func _process(_delta: float) -> void:
	queue_redraw()


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_mouse_move(event.position)
		if dragging_slider != "":
			_drag_slider(dragging_slider, event.position.x)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_down(event.position)
			else:
				dragging_slider = ""

	elif event.is_action_pressed("ui_cancel"):
		_discard()


func _on_mouse_move(pos: Vector2) -> void:
	hover = ""
	if res_left_rect.has_point(pos):   hover = "res_left"
	elif res_right_rect.has_point(pos): hover = "res_right"
	elif fs_rect.has_point(pos):        hover = "fullscreen"
	elif vsync_rect.has_point(pos):     hover = "vsync"
	elif save_rect.has_point(pos):      hover = "save"
	elif discard_rect.has_point(pos):   hover = "discard"
	else:
		for sname in sliders:
			if sliders[sname].has_point(pos):
				hover = "slider_" + sname
				break


func _on_left_down(pos: Vector2) -> void:
	if res_left_rect.has_point(pos):
		work["resolution_index"] = wrapi(work["resolution_index"] - 1, 0, SettingsManager.RESOLUTIONS.size())
		_preview()
	elif res_right_rect.has_point(pos):
		work["resolution_index"] = wrapi(work["resolution_index"] + 1, 0, SettingsManager.RESOLUTIONS.size())
		_preview()
	elif fs_rect.has_point(pos):
		work["fullscreen"] = not work["fullscreen"]
		_preview()
	elif vsync_rect.has_point(pos):
		work["vsync"] = not work["vsync"]
		_preview()
	elif save_rect.has_point(pos):
		_save()
	elif discard_rect.has_point(pos):
		_discard()
	else:
		for sname in sliders:
			if sliders[sname].has_point(pos):
				dragging_slider = sname
				_drag_slider(sname, pos.x)
				break


func _drag_slider(sname: String, mouse_x: float) -> void:
	if not sliders.has(sname):
		return
	var track: Rect2 = sliders[sname]
	var t: float = clampf((mouse_x - track.position.x) / track.size.x, 0.0, 1.0)
	work[sname + "_volume"] = t
	_preview()


# ── Actions ──────────────────────────────────────────────────────────────────

func _preview() -> void:
	# Apply working values live so the player can hear/see changes immediately
	SettingsManager.fullscreen       = work["fullscreen"]
	SettingsManager.vsync            = work["vsync"]
	SettingsManager.resolution_index = work["resolution_index"]
	SettingsManager.master_volume    = work["master_volume"]
	SettingsManager.music_volume     = work["music_volume"]
	SettingsManager.sfx_volume       = work["sfx_volume"]
	SettingsManager.apply_settings()


func _save() -> void:
	_preview()
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _discard() -> void:
	# Restore from disk and re-apply before leaving
	SettingsManager.load_settings()
	SettingsManager.apply_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_header()
	_draw_display_section()
	_draw_audio_section()
	_draw_buttons()


func _draw_bg() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.07, 0.07, 0.12, 1.0))

	var cx: float = CX; var cy: float = H / 2.0
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
	draw_circle(Vector2(0, 0),   200, Color(Color.DODGER_BLUE,   ca))
	draw_circle(Vector2(W, 0),   200, Color(Color.CRIMSON,       ca))
	draw_circle(Vector2(0, H),   200, Color(Color.FOREST_GREEN,  ca))
	draw_circle(Vector2(W, H),   200, Color(Color.GOLD,          ca))


func _draw_header() -> void:
	var font := ThemeDB.fallback_font

	var title := "MISDIRECT"
	var tsz: int = 48
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(CX - tw / 2.0 + 2, 72), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(CX - tw / 2.0, 70), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var sub := "Settings"
	var ssz: int = 22
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	draw_string(font, Vector2(CX - sw / 2.0, 102), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ssz, Color(0.45, 0.45, 0.58, 1.0))

	draw_line(Vector2(LABEL_X, 118), Vector2(W - LABEL_X, 118),
		Color(0.3, 0.3, 0.4, 0.5), 1.0)


func _draw_display_section() -> void:
	var font := ThemeDB.fallback_font

	_draw_section_label(font, "DISPLAY", Y_DISPLAY_HDR)

	# Resolution (disabled when fullscreen)
	var res_dimmed: bool = work["fullscreen"]
	_draw_row_label(font, "Resolution", Y_RESOLUTION, res_dimmed)
	_draw_resolution_selector(font, Y_RESOLUTION, res_dimmed)

	# Fullscreen
	_draw_row_label(font, "Fullscreen", Y_FULLSCREEN)
	_draw_toggle(font, "fullscreen", work["fullscreen"], Y_FULLSCREEN)

	# VSync
	_draw_row_label(font, "VSync", Y_VSYNC)
	_draw_toggle(font, "vsync", work["vsync"], Y_VSYNC)

	draw_line(Vector2(LABEL_X, Y_AUDIO_HDR - 18), Vector2(W - LABEL_X, Y_AUDIO_HDR - 18),
		Color(0.25, 0.25, 0.35, 0.4), 1.0)


func _draw_audio_section() -> void:
	var font := ThemeDB.fallback_font

	_draw_section_label(font, "AUDIO", Y_AUDIO_HDR)

	_draw_row_label(font, "Master", Y_MASTER)
	_draw_slider(font, "master", work["master_volume"], Y_MASTER)

	_draw_row_label(font, "Music", Y_MUSIC)
	_draw_slider(font, "music", work["music_volume"], Y_MUSIC)

	_draw_row_label(font, "SFX", Y_SFX)
	_draw_slider(font, "sfx", work["sfx_volume"], Y_SFX)


func _draw_buttons() -> void:
	var font := ThemeDB.fallback_font

	# Save & Back
	var sw: float = 220.0; var sh: float = 50.0
	save_rect = Rect2(CX - sw - 16.0, Y_BUTTONS, sw, sh)
	var save_hov: bool = hover == "save"
	draw_rect(save_rect, Color(0.1, 0.45, 0.15, 1.0) if save_hov else Color(0.08, 0.32, 0.1, 1.0))
	draw_rect(save_rect, Color(0.3, 0.9, 0.4, 0.9) if save_hov else Color(0.2, 0.65, 0.25, 0.7), false, 2.0)
	var st := "Save & Back"
	var stw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(save_rect.position.x + (sw - stw) / 2.0, Y_BUTTONS + 33.0),
		st, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

	# Discard
	var dw: float = 180.0
	discard_rect = Rect2(CX + 16.0, Y_BUTTONS, dw, sh)
	var dis_hov: bool = hover == "discard"
	draw_rect(discard_rect, Color(0.28, 0.28, 0.38, 1.0) if dis_hov else Color(0.18, 0.18, 0.26, 1.0))
	draw_rect(discard_rect, Color(0.5, 0.5, 0.65, 0.7) if dis_hov else Color(0.35, 0.35, 0.48, 0.5), false, 2.0)
	var dt := "Discard"
	var dtw := font.get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(discard_rect.position.x + (dw - dtw) / 2.0, Y_BUTTONS + 33.0),
		dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.7, 0.8, 1.0))

	# Hint
	var hint := "ESC — discard & back"
	var hsz: int = 13
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz).x
	draw_string(font, Vector2(CX - hw / 2.0, H - 20.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hsz, Color(0.3, 0.3, 0.4, 1.0))


# ── Row helpers ──────────────────────────────────────────────────────────────

func _draw_section_label(font: Font, text: String, y: float) -> void:
	draw_string(font, Vector2(LABEL_X, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.88, 1.0))


func _draw_row_label(font: Font, text: String, y: float, dimmed: bool = false) -> void:
	var col := Color(0.4, 0.4, 0.5, 1.0) if dimmed else Color(0.7, 0.7, 0.82, 1.0)
	draw_string(font, Vector2(LABEL_X + 18.0, y + 6.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


func _draw_resolution_selector(font: Font, y: float, dimmed: bool) -> void:
	var res: Vector2i = SettingsManager.RESOLUTIONS[work["resolution_index"]]
	var res_str: String = "%d × %d" % [res.x, res.y]

	var arrow_sz: float = 28.0
	var arrow_pad: float = 10.0

	# Left arrow
	res_left_rect = Rect2(CTRL_X, y - 4.0, arrow_sz, 36.0)
	var lhov: bool = hover == "res_left" and not dimmed
	var arrow_col := Color(0.3, 0.3, 0.4, 1.0) if dimmed else (Color(0.9, 0.9, 1.0, 1.0) if lhov else Color(0.55, 0.55, 0.7, 1.0))
	draw_string(font, Vector2(CTRL_X + 4.0, y + 22.0), "◀",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, arrow_col)

	# Label
	var lw := font.get_string_size(res_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var lx: float = CTRL_X + arrow_sz + arrow_pad + (CTRL_W - arrow_sz * 2 - arrow_pad * 2 - lw) / 2.0
	var text_col := Color(0.35, 0.35, 0.45, 1.0) if dimmed else Color(0.9, 0.9, 1.0, 1.0)
	draw_string(font, Vector2(lx, y + 22.0), res_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, text_col)

	# Right arrow
	res_right_rect = Rect2(CTRL_X + CTRL_W - arrow_sz, y - 4.0, arrow_sz, 36.0)
	var rhov: bool = hover == "res_right" and not dimmed
	var rarrow_col := Color(0.3, 0.3, 0.4, 1.0) if dimmed else (Color(0.9, 0.9, 1.0, 1.0) if rhov else Color(0.55, 0.55, 0.7, 1.0))
	draw_string(font, Vector2(CTRL_X + CTRL_W - arrow_sz + 4.0, y + 22.0), "▶",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rarrow_col)

	if dimmed:
		var note_sz: int = 13
		draw_string(font, Vector2(CTRL_X + CTRL_W + 16.0, y + 18.0), "(fullscreen)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, note_sz, Color(0.4, 0.4, 0.5, 1.0))


func _draw_toggle(font: Font, id: String, value: bool, y: float) -> void:
	var hov: bool = hover == id
	var total_w: float = 130.0
	var h: float = 32.0
	var rx: float = CTRL_X
	var ry: float = y - 2.0

	# Background track
	var track_col := Color(0.15, 0.15, 0.22, 1.0)
	draw_rect(Rect2(rx, ry, total_w, h), track_col)
	draw_rect(Rect2(rx, ry, total_w, h), Color(0.4, 0.4, 0.55, 0.6), false, 1.5)

	# Active half highlight
	var half_w: float = total_w / 2.0
	if value:
		var active_col := Color(0.1, 0.55, 0.2, 0.9) if not hov else Color(0.15, 0.65, 0.25, 0.9)
		draw_rect(Rect2(rx + half_w, ry, half_w, h), active_col)
	else:
		var inactive_col := Color(0.3, 0.3, 0.4, 0.5) if not hov else Color(0.35, 0.35, 0.48, 0.6)
		draw_rect(Rect2(rx, ry, half_w, h), inactive_col)

	# Labels
	var off_col := Color(0.9, 0.9, 1.0, 1.0) if not value else Color(0.4, 0.4, 0.55, 1.0)
	var on_col  := Color(0.9, 0.9, 1.0, 1.0) if value     else Color(0.4, 0.4, 0.55, 1.0)
	draw_string(font, Vector2(rx + (half_w - font.get_string_size("OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) / 2.0, ry + 22.0),
		"OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, off_col)
	draw_string(font, Vector2(rx + half_w + (half_w - font.get_string_size("ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) / 2.0, ry + 22.0),
		"ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, on_col)

	# Store hit rect
	if id == "fullscreen":
		fs_rect = Rect2(rx, ry, total_w, h)
	elif id == "vsync":
		vsync_rect = Rect2(rx, ry, total_w, h)


func _draw_slider(font: Font, name: String, value: float, y: float) -> void:
	var track_h: float = 8.0
	var thumb_r: float = 10.0
	var ty: float = y + 14.0  # Track centre Y

	var track_rect := Rect2(CTRL_X, ty - track_h / 2.0, CTRL_W, track_h)
	sliders[name] = Rect2(CTRL_X - thumb_r, ty - 20.0, CTRL_W + thumb_r * 2, 40.0)  # Generous hit area

	var is_hov: bool = hover == "slider_" + name or dragging_slider == name

	# Track background
	draw_rect(track_rect, Color(0.18, 0.18, 0.26, 1.0))

	# Filled portion
	var filled_w: float = CTRL_W * value
	if filled_w > 0:
		draw_rect(Rect2(CTRL_X, ty - track_h / 2.0, filled_w, track_h),
			Color(0.25, 0.7, 0.35, 1.0))

	# Track border
	draw_rect(track_rect, Color(0.35, 0.35, 0.48, 0.6), false, 1.5)

	# Thumb
	var tx: float = CTRL_X + CTRL_W * value
	var thumb_col := Color(0.4, 0.95, 0.5, 1.0) if is_hov else Color(0.3, 0.8, 0.4, 1.0)
	draw_circle(Vector2(tx, ty), thumb_r, thumb_col)
	draw_arc(Vector2(tx, ty), thumb_r, 0, TAU, 24, Color(0.2, 0.5, 0.25, 1.0), 2.0)

	# Percentage label
	var pct_str: String = "%d%%" % roundi(value * 100.0)
	var psz: int = 16
	draw_string(font, Vector2(CTRL_X + CTRL_W + 18.0, y + 20.0), pct_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, psz, Color(0.6, 0.6, 0.72, 1.0))
