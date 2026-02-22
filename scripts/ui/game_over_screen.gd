extends Control
class_name GameOverScreen
## Game over overlay showing results

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

signal restart_requested
signal quit_requested

var final_scores: Dictionary = {}
var winner_dept: int = -1
var player_dept: int = -1
var player_collapsed: bool = false


func _ready() -> void:
	visible = false
	# Fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept"):
		restart_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		quit_requested.emit()


func show_results(scores: Dictionary, player_department: int, collapsed_depts: Array) -> void:
	final_scores = scores
	player_dept = player_department
	player_collapsed = player_department in collapsed_depts

	# Find winner (highest score among non-collapsed)
	var best_score: int = -1
	winner_dept = -1
	for dept in scores.keys():
		if dept not in collapsed_depts:
			if scores[dept] > best_score:
				best_score = scores[dept]
				winner_dept = dept

	visible = true
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var screen_size: Vector2 = size

	# Dark overlay
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.85))

	var font := ThemeDB.fallback_font
	var center_x: float = screen_size.x / 2

	# Title
	var title: String
	var title_color: Color
	if player_collapsed:
		title = "DEPARTMENT COLLAPSED!"
		title_color = Color.RED
	elif winner_dept == player_dept:
		title = "YOU WIN!"
		title_color = Color.GREEN
	else:
		title = "WORKDAY OVER"
		title_color = Color.WHITE

	var title_size: int = 48
	var title_text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	draw_string(font, Vector2(center_x - title_text_size.x / 2, 150), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	# Scores
	var y_pos: float = 220
	var score_size: int = 24

	# Sort departments by score
	var sorted_depts: Array = final_scores.keys()
	sorted_depts.sort_custom(func(a, b): return final_scores[a] > final_scores[b])

	for dept in sorted_depts:
		var dept_name: String = DepartmentDataScript.get_department_name(dept)
		var dept_color: Color = DepartmentDataScript.get_color(dept)
		var score_val: int = final_scores[dept]

		var line: String = "%s: %d" % [dept_name, score_val]
		if dept == winner_dept:
			line += " - WINNER"
		if dept == player_dept:
			line += " (You)"

		var line_size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, score_size)
		draw_string(font, Vector2(center_x - line_size.x / 2, y_pos), line, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, dept_color)

		y_pos += 35

	# Instructions
	var inst_size: int = 18
	var inst_text: String = "Press ENTER to restart  |  ESC to quit"
	var inst_text_size := font.get_string_size(inst_text, HORIZONTAL_ALIGNMENT_CENTER, -1, inst_size)
	draw_string(font, Vector2(center_x - inst_text_size.x / 2, screen_size.y - 80), inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, inst_size, Color.GRAY)


func hide_screen() -> void:
	visible = false
