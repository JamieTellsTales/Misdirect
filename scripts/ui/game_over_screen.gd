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
	# Must process even while the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept"):
		get_tree().paused = false
		restart_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
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
	get_tree().paused = true


func _draw() -> void:
	if not visible:
		return

	# Use fixed arena dimensions — Control.size is unreliable when parented to a Node2D
	var screen_size := Vector2(1280.0, 720.0)
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0

	# Subtle dim over the frozen arena
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0, 0, 0, 0.5))

	# Centred panel
	var box_w: float = 520.0
	var box_h: float = 300.0
	var box_x: float = center_x - box_w / 2.0
	var box_y: float = center_y - box_h / 2.0
	var box_rect := Rect2(box_x, box_y, box_w, box_h)

	draw_rect(box_rect, Color(0.07, 0.07, 0.12, 0.97))
	draw_rect(box_rect, Color(0.55, 0.55, 0.65, 1.0), false, 2.0)

	var font := ThemeDB.fallback_font

	# Title
	var title: String
	var title_color: Color
	if player_collapsed:
		title = "DEPARTMENT COLLAPSED!"
		title_color = Color.TOMATO
	elif winner_dept == player_dept:
		title = "YOU WIN!"
		title_color = Color.GOLD
	else:
		title = "GAME OVER"
		title_color = Color.WHITE

	var title_size: int = 36
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(center_x - title_w / 2.0, box_y + 50.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	# Divider
	draw_line(Vector2(box_x + 24, box_y + 62), Vector2(box_x + box_w - 24, box_y + 62),
		Color(0.4, 0.4, 0.5, 0.7), 1.0)

	# Scores sorted highest first
	var sorted_depts: Array = final_scores.keys()
	sorted_depts.sort_custom(func(a, b): return final_scores[a] > final_scores[b])

	var score_size: int = 22
	var y_pos: float = box_y + 90.0
	for dept in sorted_depts:
		var dept_color: Color = DepartmentDataScript.get_color(dept)
		var score_val: int = final_scores[dept]
		var line: String = "%s:  %d" % [DepartmentDataScript.get_department_name(dept), score_val]
		if dept == winner_dept:
			line += "  ★"
		if dept == player_dept:
			line += "  (You)"

		var line_w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size).x
		draw_string(font, Vector2(center_x - line_w / 2.0, y_pos),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, dept_color)
		y_pos += 38.0

	# Instructions
	var inst_size: int = 15
	var inst_text: String = "ENTER — play again     ESC — main menu"
	var inst_w := font.get_string_size(inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, inst_size).x
	draw_string(font, Vector2(center_x - inst_w / 2.0, box_y + box_h - 20.0),
		inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, inst_size, Color(0.45, 0.45, 0.55, 1.0))


func hide_screen() -> void:
	visible = false
