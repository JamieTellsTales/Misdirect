extends Node2D
class_name StatsScreen
## Full-screen statistics display.
## Shows all tracked lifetime stats. ESC or back button returns to main menu.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

var _sw: float = 1280.0
var _sh: float = 720.0

# ── Scroll state ──────────────────────────────────────────────────────────────
var _scroll_offset: float = 0.0
var _content_height: float = 0.0   # set each frame in _draw so clamp works
const FOOTER_H: float = 56.0       # fixed footer height (separator + back + hint)
const SCROLL_SPEED: float = 32.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		var max_scroll: float = maxf(0.0, _content_height - _scroll_area_height())
		_scroll_offset = minf(max_scroll, _scroll_offset + SCROLL_SPEED * 4)
		queue_redraw()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_scroll_offset = maxf(0.0, _scroll_offset - SCROLL_SPEED * 4)
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _back_rect.has_point(event.position):
					AudioManager.play_button_click()
					get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset = maxf(0.0, _scroll_offset - SCROLL_SPEED * 3)
				queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				var max_scroll: float = maxf(0.0, _content_height - _scroll_area_height())
				_scroll_offset = minf(max_scroll, _scroll_offset + SCROLL_SPEED * 3)
				queue_redraw()


var _back_rect: Rect2 = Rect2()


func _process(_delta: float) -> void:
	queue_redraw()


func _scroll_area_height() -> float:
	return _sh - FOOTER_H


func _draw() -> void:
	_sw = get_viewport_rect().size.x
	_sh = get_viewport_rect().size.y
	var font       := FontManager.get_font()
	var cx: float   = _sw  / 2.0

	# ── Background ────────────────────────────────────────────────────────────
	draw_rect(Rect2(Vector2.ZERO, Vector2(_sw, _sh)), Color(0.07, 0.07, 0.12, 1.0))

	# ── Panel (fits inside scroll area) ───────────────────────────────────────
	var box_w: float = 580.0
	var bx: float    = cx - box_w / 2.0

	# Totals derived from canonical lists in GameConfig
	var total_powerups: int = 0
	for pu in GameConfig.POWER_UPS:
		if pu["id"] != "":
			total_powerups += 1
	var total_modifiers:    int = GameConfig.MODIFIERS.size()
	var total_achievements: int = GameConfig.TOTAL_ACHIEVEMENTS

	var current_level: int = StatsManager.get_level()
	var xp_in_level:   int = StatsManager.get_xp_in_level()

	# ── Section helpers ───────────────────────────────────────────────────────
	# Each entry: [label, value_string, color]
	# A section header is: ["__header__", "SECTION TITLE", header_color]

	var col_default  := Color(0.8,  0.8,  0.9,  1.0)
	var col_green    := Color(0.4,  0.9,  0.4,  1.0)
	var col_blue     := Color(0.5,  0.85, 1.0,  1.0)
	var col_red      := Color(0.9,  0.4,  0.4,  1.0)
	var col_gold     := Color(1.0,  0.84, 0.0,  1.0)
	var col_dim      := Color(0.45, 0.45, 0.55, 1.0)
	var col_header   := Color(0.55, 0.55, 0.68, 1.0)

	var rows: Array = [
		# ── Profile ──────────────────────────────────────────────────────────
		["__header__", "PROFILE",  col_header],
		["Level",       "%d  (%d / 100 XP)" % [current_level, xp_in_level], col_blue],
		["Tokens",      "%d  /  %d total" % [StatsManager.tokens, StatsManager.total_tokens_earned], col_green],
		["Time Played", StatsManager.format_time(StatsManager.total_time_played), col_default],

		# ── High Scores ───────────────────────────────────────────────────────
		["__header__", "HIGH SCORES", col_header],
		["All Modes",   "%d" % StatsManager.high_score,           col_gold],
		["Normal",      "%d" % StatsManager.high_score_normal,    col_default],
		["Endless",     "%d" % StatsManager.high_score_endless,   col_default],
		["Elimination", "%d" % StatsManager.high_score_elimination, col_default],

		# ── Overall Results ───────────────────────────────────────────────────
		["__header__", "OVERALL RESULTS", col_header],
		["Games Played",      "%d" % StatsManager.games_played,  col_default],
		["Wins",              "%d" % StatsManager.wins,          col_green],
		["Draws",             "%d" % StatsManager.draws,         col_blue],
		["Losses",            "%d" % StatsManager.losses,        col_red],
		["Win / Loss Ratio",  StatsManager.win_loss_ratio(),     col_default],
		["Total Score",       "%d" % StatsManager.total_score,   col_default],

		# ── By Mode ───────────────────────────────────────────────────────────
		["__header__", "BY MODE", col_header],
		["Normal Games",          "%d" % StatsManager.games_played_normal,      col_default],
		["Endless Games",         "%d" % StatsManager.games_played_endless,     col_default],
		["Elimination Games",     "%d" % StatsManager.games_played_elimination, col_default],
		["Longest Endless",       StatsManager.format_time(StatsManager.longest_endless_seconds),     col_default],
		["Longest Elimination",   StatsManager.format_time(StatsManager.longest_elimination_seconds), col_default],

		# ── Unlocks ───────────────────────────────────────────────────────────
		["__header__", "UNLOCKS", col_header],
		["Achievements Unlocked", "%d / %d" % [StatsManager.achievements_unlocked, total_achievements], col_default],
		["Power-Ups Unlocked",    "%d / %d" % [StatsManager.powerups_unlocked,     total_powerups],     col_default],
		["Modifiers Unlocked",    "%d / %d" % [StatsManager.modifiers_unlocked,    total_modifiers],    col_default],
	]

	var label_size: int  = 20
	var value_size: int  = 20
	var row_h: float     = 38.0
	var header_h: float  = 50.0

	# Compute total content height
	var title_block_h: float = 88.0
	var xp_bar_h: float      = float(label_size) + 6.0 + 10.0 + 14.0
	var content_rows_h: float = 0.0
	for row in rows:
		content_rows_h += header_h if row[0] == "__header__" else row_h
	_content_height = title_block_h + content_rows_h + xp_bar_h + 16.0

	# Clamp scroll
	var scroll_area_h: float = _scroll_area_height()
	_scroll_offset = clampf(_scroll_offset, 0.0, maxf(0.0, _content_height - scroll_area_h))

	draw_set_transform(Vector2(0, -_scroll_offset))

	var box_h: float = _content_height
	var by: float    = (scroll_area_h / 2.0) - (box_h / 2.0)
	if box_h > scroll_area_h:
		by = 0.0

	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.09, 0.09, 0.15, 1.0))
	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.55, 0.55, 0.65, 1.0), false, 2.0)

	# Title + active profile name
	var title      := "STATISTICS"
	var title_size := 36
	var title_w    := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0 + 2, by + 46.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.4))
	draw_string(font, Vector2(cx - title_w / 2.0, by + 44.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	var profile_label := ProfileManager.active_name()
	var pl_size := 16
	var pl_w := font.get_string_size(profile_label, HORIZONTAL_ALIGNMENT_LEFT, -1, pl_size).x
	draw_string(font, Vector2(cx - pl_w / 2.0, by + 66.0),
		profile_label, HORIZONTAL_ALIGNMENT_LEFT, -1, pl_size, Color(0.4, 0.75, 0.5, 0.9))

	draw_line(
		Vector2(bx + 24, by + 76),
		Vector2(bx + box_w - 24, by + 76),
		Color(0.4, 0.4, 0.5, 0.7), 1.0
	)

	var label_x: float = bx + 36.0
	var value_x: float = bx + box_w - 36.0
	var row_y: float   = by + 98.0
	var data_row_count: int = 0  # used for alternating tint (skip headers)

	for row in rows:
		var lbl: String = row[0]
		var val: String = row[1]
		var col: Color  = row[2]

		if lbl == "__header__":
			# Section header
			var h_size: int  = 13
			var h_w: float   = font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, h_size).x
			draw_string(font, Vector2(cx - h_w / 2.0, row_y + h_size),
				val, HORIZONTAL_ALIGNMENT_LEFT, -1, h_size, col)
			# Underline
			draw_line(Vector2(bx + 24, row_y + h_size + 4), Vector2(bx + box_w - 24, row_y + h_size + 4),
				Color(col, 0.4), 1.0)
			row_y += header_h
			data_row_count = 0
			continue

		# Alternating row tint
		if data_row_count % 2 == 0:
			draw_rect(Rect2(bx + 2, row_y - label_size, box_w - 4, row_h - 4),
				Color(1, 1, 1, 0.025))
		data_row_count += 1

		# Label (left)
		draw_string(font, Vector2(label_x, row_y),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.6, 0.6, 0.7, 1.0))

		# Value (right-aligned)
		var val_w := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
		draw_string(font, Vector2(value_x - val_w, row_y),
			val, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size, col)

		row_y += row_h

	# XP progress bar
	var xp_bar_y: float = row_y + 4.0
	var xp_lbl_sz: int  = 14

	var xp_label_lft: String
	var xp_label_rgt: String
	if current_level >= 999:
		xp_label_lft = "XP Progress"
		xp_label_rgt = "MAX LEVEL"
	else:
		xp_label_lft = "XP to next level"
		xp_label_rgt = "%d / 100" % xp_in_level

	draw_string(font, Vector2(label_x, xp_bar_y + xp_lbl_sz),
		xp_label_lft, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_lbl_sz, Color(0.5, 0.5, 0.6, 1.0))
	var xp_rgt_w := font.get_string_size(xp_label_rgt, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_lbl_sz).x
	draw_string(font, Vector2(value_x - xp_rgt_w, xp_bar_y + xp_lbl_sz),
		xp_label_rgt, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_lbl_sz,
		Color(0.55, 0.85, 0.55, 1.0) if current_level < 999 else Color(1.0, 0.84, 0.0, 1.0))

	var bar_x: float = label_x
	var bar_y: float = xp_bar_y + xp_lbl_sz + 6.0
	var bar_w: float = value_x - label_x
	var bar_h: float = 10.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.22, 1.0))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.35, 0.35, 0.45, 0.5), false, 1.0)
	var fill_frac: float = float(xp_in_level) / 100.0 if current_level < 999 else 1.0
	if fill_frac > 0.0:
		draw_rect(Rect2(bar_x, bar_y, bar_w * fill_frac, bar_h), Color(0.3, 0.75, 0.45, 1.0))

	# Reset transform before drawing fixed footer
	draw_set_transform(Vector2.ZERO)

	# ── Scroll indicator (only when scrollable) ───────────────────────────────
	if _content_height > scroll_area_h:
		var scroll_track_h: float = scroll_area_h - 16.0
		var thumb_h: float = maxf(24.0, scroll_track_h * (scroll_area_h / _content_height))
		var thumb_t: float = (_scroll_offset / maxf(1.0, _content_height - scroll_area_h))
		var thumb_y: float = 8.0 + thumb_t * (scroll_track_h - thumb_h)
		draw_rect(Rect2(_sw - 8.0, 8.0, 4.0, scroll_track_h), Color(0.2, 0.2, 0.3, 0.6))
		draw_rect(Rect2(_sw - 8.0, thumb_y, 4.0, thumb_h), Color(0.55, 0.55, 0.7, 0.9))

	# ── Footer (fixed, always visible) ────────────────────────────────────────
	var footer_y: float = scroll_area_h

	draw_line(Vector2(0, footer_y), Vector2(_sw, footer_y),
		Color(0.3, 0.3, 0.4, 0.8), 1.0)
	draw_rect(Rect2(0, footer_y, _sw, FOOTER_H), Color(0.05, 0.05, 0.09, 0.97))

	var back_lbl  := "← BACK"
	var back_size := 18
	var back_w    := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size).x
	var back_x    := cx - back_w / 2.0
	var back_y    := footer_y + 28.0
	_back_rect = Rect2(back_x - 16, back_y - back_size, back_w + 32, back_size + 10)

	draw_string(font, Vector2(back_x, back_y),
		back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size, Color(0.45, 0.55, 0.75, 1.0))

	var hint      := "ESC — back     scroll to see all"
	var hint_size := 13
	var hint_w    := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, footer_y + FOOTER_H - 8.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)
