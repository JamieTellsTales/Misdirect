extends Control
class_name QueueDisplay
## Displays the ticket queue count and SLA timer for a department

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

@export_enum("SERVICE_DESK", "INFRASTRUCTURE", "SECURITY", "DEVELOPMENT", "MANAGEMENT") var department_type: int = 0
@export var max_queue_size: int = 10

var queue_count: int = 0
var sla_percent: float = 1.0  # 0.0 = expired, 1.0 = full time remaining
var department_color: Color


func _ready() -> void:
	department_color = DepartmentDataScript.get_color(department_type)
	custom_minimum_size = Vector2(80, 50)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Background
	var bg_color: Color = department_color
	bg_color.a = 0.7
	draw_rect(rect, bg_color)

	# Border
	draw_rect(rect, department_color.lightened(0.2), false, 2.0)

	# Queue count text
	var font := ThemeDB.fallback_font
	var font_size: int = 20
	var text: String = str(queue_count)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(
		(size.x - text_size.x) / 2,
		font_size + 4
	)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# SLA timer bar (top bar)
	var sla_bar_height: float = 4.0
	var sla_bar_rect := Rect2(2, 2, size.x - 4, sla_bar_height)
	draw_rect(sla_bar_rect, Color(0, 0, 0, 0.3))

	if queue_count > 0:
		var sla_width: float = sla_percent * sla_bar_rect.size.x
		var sla_fill := Rect2(sla_bar_rect.position, Vector2(sla_width, sla_bar_height))
		var sla_color: Color
		if sla_percent > 0.5:
			sla_color = Color.GREEN
		elif sla_percent > 0.25:
			sla_color = Color.YELLOW
		else:
			sla_color = Color.RED
		draw_rect(sla_fill, sla_color)

	# Queue fullness bar (bottom bar)
	var bar_height: float = 6.0
	var bar_rect := Rect2(2, size.y - bar_height - 2, size.x - 4, bar_height)
	draw_rect(bar_rect, Color(0, 0, 0, 0.3))

	var fill_width: float = (float(queue_count) / float(max_queue_size)) * bar_rect.size.x
	var fill_rect := Rect2(bar_rect.position, Vector2(fill_width, bar_height))
	var fill_color: Color
	if queue_count < max_queue_size * 0.7:
		fill_color = Color.GREEN
	elif queue_count < max_queue_size:
		fill_color = Color.ORANGE
	else:
		fill_color = Color.RED
	draw_rect(fill_rect, fill_color)

	# "Q:" label
	var label_size: int = 10
	draw_string(font, Vector2(4, size.y - bar_height - 6), "Q:", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color.WHITE)


func set_queue_count(count: int) -> void:
	queue_count = count
	queue_redraw()


func set_sla_percent(percent: float) -> void:
	sla_percent = clampf(percent, 0.0, 1.0)
	queue_redraw()


func set_department(dept_type: int) -> void:
	department_type = dept_type
	department_color = DepartmentDataScript.get_color(department_type)
	queue_redraw()
