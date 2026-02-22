extends Control
class_name ScoreDisplay
## Displays the score for a department

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

@export_enum("SERVICE_DESK", "INFRASTRUCTURE", "SECURITY", "DEVELOPMENT", "MANAGEMENT") var department_type: int = 0
@export var is_player: bool = false

var score: int = 0
var department_color: Color
var display_score: int = 0  # For animated counting
var score_flash_timer: float = 0.0


func _ready() -> void:
	department_color = DepartmentDataScript.get_color(department_type)
	custom_minimum_size = Vector2(80, 35)
	queue_redraw()


func _process(delta: float) -> void:
	# Animate score counting
	if display_score != score:
		var diff: int = score - display_score
		var step: int = max(1, abs(diff) / 10)
		if diff > 0:
			display_score += step
			display_score = min(display_score, score)
		else:
			display_score -= step
			display_score = max(display_score, score)
		queue_redraw()

	# Score flash effect
	if score_flash_timer > 0:
		score_flash_timer -= delta
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var shadow := Color(0.0, 0.0, 0.0, 0.8)

	var text_color: Color = department_color.lightened(0.35)
	if score_flash_timer > 0:
		var flash: float = score_flash_timer / 0.3
		text_color = text_color.lerp(Color.WHITE, flash * 0.7)

	# Score number — centred horizontally and vertically in the control
	var score_text: String = str(display_score)
	var score_size: int = 26
	var text_size := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size)
	var x: float = (size.x - text_size.x) / 2.0
	var y: float = (size.y + text_size.y) / 2.0

	draw_string(font, Vector2(x + 1, y + 1), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, shadow)
	draw_string(font, Vector2(x, y), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, text_color)


func set_score(new_score: int) -> void:
	if new_score > score:
		score_flash_timer = 0.3  # Flash on score increase
	score = new_score
	queue_redraw()


func add_score(points: int) -> void:
	set_score(score + points)


func set_department(dept_type: int, player: bool = false) -> void:
	department_type = dept_type
	is_player = player
	department_color = DepartmentDataScript.get_color(department_type)
	queue_redraw()
