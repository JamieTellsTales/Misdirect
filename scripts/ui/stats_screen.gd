extends Node2D
class_name StatsScreen
## Full-screen statistics display.
## Shows all tracked lifetime stats. ESC or back button returns to main menu.

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Back button hit-test handled in _draw's back_rect
		if _back_rect.has_point(event.position):
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


var _back_rect: Rect2 = Rect2()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font       := ThemeDB.fallback_font
	var cx: float   = ARENA_WIDTH  / 2.0
	var cy: float   = ARENA_HEIGHT / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), Color(0.07, 0.07, 0.12, 1.0))

	# Panel
	var box_w: float = 560.0
	var box_h: float = 646.0
	var bx: float    = cx - box_w / 2.0
	var by: float    = cy - box_h / 2.0
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

	# Stat rows
	var rows: Array = [
		["High Score",         "%d" % StatsManager.high_score,                          Color(1.0,  0.84, 0.0,  1.0)],
		["Total Score",        "%d" % StatsManager.total_score,                         Color(0.8,  0.8,  0.9,  1.0)],
		["Points Available",   "%d" % StatsManager.points,                              Color(0.4,  0.9,  0.4,  1.0)],
		["Games Played",       "%d" % StatsManager.games_played,                        Color(0.8,  0.8,  0.9,  1.0)],
		["Wins",               "%d" % StatsManager.wins,                                Color(0.4,  0.9,  0.4,  1.0)],
		["Losses",             "%d" % StatsManager.losses,                              Color(0.9,  0.4,  0.4,  1.0)],
		["Win / Loss Ratio",   StatsManager.win_loss_ratio(),                           Color(0.8,  0.8,  0.9,  1.0)],
		["Time Played",        StatsManager.format_time(StatsManager.total_time_played),Color(0.8,  0.8,  0.9,  1.0)],
		["Achievements",       "%d unlocked" % StatsManager.achievements_unlocked,      Color(0.8,  0.8,  0.9,  1.0)],
		["Powerups",           "%d unlocked" % StatsManager.powerups_unlocked,          Color(0.8,  0.8,  0.9,  1.0)],
		["Modifiers",          "%d unlocked" % StatsManager.modifiers_unlocked,         Color(0.8,  0.8,  0.9,  1.0)],
		["Longest Endless",    "— coming soon",                                         Color(0.45, 0.45, 0.55, 1.0)],
	]

	var label_size: int  = 20
	var value_size: int  = 20
	var row_h: float     = 42.0
	var row_y: float     = by + 98.0
	var label_x: float   = bx + 36.0
	var value_x: float   = bx + box_w - 36.0  # Right-aligned

	for row in rows:
		var lbl: String   = row[0]
		var val: String   = row[1]
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

	# Back button
	var back_lbl  := "← BACK"
	var back_size := 18
	var back_w    := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size).x
	var back_x    := cx - back_w / 2.0
	var back_y    := by + box_h - 26.0
	_back_rect = Rect2(back_x - 16, back_y - back_size, back_w + 32, back_size + 10)

	draw_string(font, Vector2(back_x, back_y),
		back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size, Color(0.45, 0.55, 0.75, 1.0))

	# ESC hint
	var hint      := "ESC — back"
	var hint_size := 13
	var hint_w    := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, ARENA_HEIGHT - 24.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))
