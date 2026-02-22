extends CharacterBody2D
class_name Paddle
## Base paddle class for deflecting and catching tickets

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

@export_enum("SERVICE_DESK", "INFRASTRUCTURE", "SECURITY", "DEVELOPMENT", "MANAGEMENT") var department_type: int = 0
@export var paddle_length: float = 100.0
@export var paddle_thickness: float = 12.0
@export var is_horizontal: bool = false  # false = vertical paddle (left/right), true = horizontal (top/bottom)

var paddle_color: Color


func _ready() -> void:
	add_to_group("paddles")
	paddle_color = DepartmentDataScript.get_color(department_type)
	_setup_collision_shape()
	queue_redraw()


func _setup_collision_shape() -> void:
	var shape := RectangleShape2D.new()
	if is_horizontal:
		shape.size = Vector2(paddle_length, paddle_thickness)
	else:
		shape.size = Vector2(paddle_thickness, paddle_length)

	$CollisionShape2D.shape = shape


func _draw() -> void:
	var size: Vector2
	if is_horizontal:
		size = Vector2(paddle_length, paddle_thickness)
	else:
		size = Vector2(paddle_thickness, paddle_length)

	var rect := Rect2(-size / 2, size)

	# Main paddle body
	draw_rect(rect, paddle_color)

	# Highlight edge
	var highlight := paddle_color.lightened(0.3)
	draw_rect(rect, highlight, false, 2.0)


func get_department_color() -> Color:
	return paddle_color
