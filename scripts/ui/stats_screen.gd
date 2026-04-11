extends Node2D
class_name StatsScreen
## Full-screen statistics display.
## Shows all tracked lifetime stats. ESC or back button returns to main menu.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0

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
	return ARENA_HEIGHT - FOOTER_H


func _draw() -> void:
	var font       := ThemeDB.fallback_font
	var cx: float   = ARENA_WIDTH  / 2.0

	# ── Background ────────────────────────────────────────────────────────────
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color(0.07, 0.07, 0.12, 1.0))

	# ── Panel (fits inside scroll area) ───────────────────────────────────────
	var box_w: float = 560.0
	var bx: float    = cx - box_w / 2.0

	# Totals derived from canonical lists in GameConfig
	var total_powerups: int = 0
	for pu in GameConfig.POWER_UPS:
		if pu["id"] != "":
			total_powerups += 1
	var total_modifiers:    int = GameConfig.MODIFIERS.size()
	var total_achievements: int = GameConfig.TOTAL_ACHIEVEMENTS

	# Stat rows
	var current_level: int = StatsManager.get_level()
	var xp_in_level:   int = StatsManager.get_xp_in_level()
	var rows: Array = [
		["High Score",       "%d" % StatsManager.high_score,                           Color(1.0,  0.84, 0.0,  1.0)],
		["Level",            "%d  (%d / 100 XP)" % [current_level, xp_in_level],      Color(0.55, 0.85, 1.0,  1.0)],
		["Total Score",      "%d" % StatsManager.total_score,                          Color(0.8,  0.8,  0.9,  1.0)],
		["Tokens",           "%d" % StatsManager.tokens,                               Color(0.4,  0.9,  0.4,  1.0)],
		["Games Played",     "%d" % StatsManager.games_played,                         Color(0.8,  0.8,  0.9,  1.0)],
		["Wins",             "%d" % StatsManager.wins,                                 Color(0.4,  0.9,  0.4,  1.0)],
		["Losses",           "%d" % StatsManager.losses,                               Color(0.9,  0.4,  0.4,  1.0)],
		["Win / Loss Ratio", StatsManager.win_loss_ratio(),                            Color(0.8,  0.8,  0.9,  1.0)],
		["Time Played",      StatsManager.format_time(StatsManager.total_time_played), Color(0.8,  0.8,  0.9,  1.0)],
		["Achievements",     "%d / %d" % [StatsManager.achievements_unlocked, total_achievements], Color(0.8, 0.8, 0.9, 1.0)],
		["Powerups",         "%d / %d" % [StatsManager.powerups_unlocked,     total_powerups],     Color(0.8, 0.8, 0.9, 1.0)],
		["Modifiers",        "%d / %d" % [StatsManager.modifiers_unlocked,    total_modifiers],    Color(0.8, 0.8, 0.9, 1.0)],
		["Longest Endless",  "— coming soon",                                          Color(0.45, 0.45, 0.55, 1.0)],
	]

	var label_size: int  = 20
	var value_size: int  = 20
	var row_h: float     = 38.0

	# Compute total content height so we can scroll and clamp correctly.
	# Content: title block (88 px) + rows + XP bar section (~56 px)
	var title_block_h: float = 88.0
	var xp_bar_h: float      = float(label_size) + 6.0 + 10.0 + 14.0  # label+gap+bar+padding
	_content_height          = title_block_h + float(rows.size()) * row_h + xp_bar_h + 16.0

	# Clamp scroll so we never scroll past the bottom of the content
	var scroll_area_h: float = _scroll_area_height()
	_scroll_offset = clampf(_scroll_offset, 0.0, maxf(0.0, _content_height - scroll_area_h))

	# Clip all scrollable content to the scroll area
	var clip_rect := Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, scroll_area_h))
	draw_set_transform(Vector2(0, -_scroll_offset))

	var box_h: float  = _content_height
	var by: float     = (scroll_area_h / 2.0) - (box_h / 2.0)
	# Anchor to top of content when content is taller than viewport
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

	var label_x: float   = bx + 36.0
	var value_x: float   = bx + box_w - 36.0  # Right-aligned
	var row_y: float     = by + 98.0

	for row in rows:
		var lbl: String    = row[0]
		var val: String    = row[1]
		var val_col: Color = row[2]

		# Alternating row tint
		var row_index: int = rows.find(row)
		if row_index % 2 == 0:
			draw_rect(Rect2(bx + 2, row_y - label_size, box_w - 4, row_h - 4),
				Color(1, 1, 1, 0.025))

		# Label (left)
		draw_string(font, Vector2(label_x, row_y),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.6, 0.6, 0.7, 1.0))

		# Value (right-aligned)
		var val_w := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
		draw_string(font, Vector2(value_x - val_w, row_y),
			val, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size, val_col)

		row_y += row_h

	# XP progress bar
	var xp_bar_y: float    = row_y + 4.0
	var xp_lbl_sz: int     = 14

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

	var bar_x: float    = label_x
	var bar_y: float    = xp_bar_y + xp_lbl_sz + 6.0
	var bar_w: float    = value_x - label_x
	var bar_h: float    = 10.0
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
		draw_rect(Rect2(ARENA_WIDTH - 8.0, 8.0, 4.0, scroll_track_h), Color(0.2, 0.2, 0.3, 0.6))
		draw_rect(Rect2(ARENA_WIDTH - 8.0, thumb_y, 4.0, thumb_h), Color(0.55, 0.55, 0.7, 0.9))

	# ── Footer (fixed, always visible) ────────────────────────────────────────
	var footer_y: float = scroll_area_h

	# Separator line
	draw_line(Vector2(0, footer_y), Vector2(ARENA_WIDTH, footer_y),
		Color(0.3, 0.3, 0.4, 0.8), 1.0)

	# Footer background
	draw_rect(Rect2(0, footer_y, ARENA_WIDTH, FOOTER_H), Color(0.05, 0.05, 0.09, 0.97))

	# Back button
	var back_lbl  := "← BACK"
	var back_size := 18
	var back_w    := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size).x
	var back_x    := cx - back_w / 2.0
	var back_y    := footer_y + 28.0
	_back_rect = Rect2(back_x - 16, back_y - back_size, back_w + 32, back_size + 10)

	draw_string(font, Vector2(back_x, back_y),
		back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size, Color(0.45, 0.55, 0.75, 1.0))

	# ESC hint
	var hint      := "ESC — back"
	var hint_size := 13
	var hint_w    := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, footer_y + FOOTER_H - 8.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)
