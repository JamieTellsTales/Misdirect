extends Area2D
class_name DepartmentZone
## A zone at the edge of the arena belonging to a department
## Tickets entering this zone score points (correct color) or lose points (wrong color)

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

signal score_up(department_type: int, points: int)
signal score_down(department_type: int, points: int)
signal wrong_catch(ticket: Node2D, department_type: int)

@export_enum("SERVICE_DESK", "INFRASTRUCTURE", "SECURITY", "DEVELOPMENT", "MANAGEMENT") var department_type: int = 0
@export var zone_depth: float = 60.0

var zone_color: Color
var is_collapsed: bool = false

# Flash effects
var flash_timer: float = 0.0
var flash_color: Color = Color.WHITE
var is_flashing: bool = false


func _ready() -> void:
	zone_color = DepartmentDataScript.get_color(department_type)
	zone_color.a = 0.3

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
		queue_redraw()


func _draw() -> void:
	var col_shape := get_node_or_null("CollisionShape2D")
	if col_shape and col_shape.shape is RectangleShape2D:
		var shape := col_shape.shape as RectangleShape2D
		var rect := Rect2(-shape.size / 2, shape.size)

		# Draw zone background
		var bg_color: Color
		if is_collapsed:
			bg_color = Color.DARK_GRAY
			bg_color.a = 0.5
		elif is_flashing:
			var flash_intensity: float = flash_timer / 0.3
			bg_color = zone_color.lerp(flash_color, flash_intensity * 0.6)
		else:
			bg_color = zone_color
		draw_rect(rect, bg_color)

		# Draw border line
		var border_color: Color = DepartmentDataScript.get_color(department_type)
		if is_collapsed:
			border_color = Color.DARK_GRAY
		border_color.a = 0.8
		draw_rect(rect, border_color, false, 3.0)


func _on_body_entered(body: Node2D) -> void:
	if is_collapsed:
		return
	if body.is_in_group("tickets"):
		_handle_ticket(body)


func _handle_ticket(ticket: Node2D) -> void:
	var points: int = ticket.get_point_value()
	var is_correct: bool = ticket.matches_department(department_type)

	if is_correct:
		# Correct color - gain points!
		_flash(Color.GREEN)
		score_up.emit(department_type, points)
	else:
		# Wrong color - lose points!
		_flash(Color.RED)
		score_down.emit(department_type, points)
		wrong_catch.emit(ticket, department_type)

	# Remove ticket from play
	ticket.queue_free()


func _flash(color: Color) -> void:
	is_flashing = true
	flash_timer = 0.3
	flash_color = color
	queue_redraw()


func collapse() -> void:
	is_collapsed = true
	zone_color = Color.DARK_GRAY
	zone_color.a = 0.5
	queue_redraw()


func is_department_collapsed() -> bool:
	return is_collapsed


func get_department_color() -> Color:
	return DepartmentDataScript.get_color(department_type)
