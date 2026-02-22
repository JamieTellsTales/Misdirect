extends RigidBody2D
class_name Ticket
## Ticket - A bouncing ball that represents a helpdesk ticket

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

signal request_split(ticket: RigidBody2D, count: int)

@export var ticket_color: Color = Color.DODGER_BLUE
@export var base_speed: float = 300.0

# Department this ticket belongs to
var department_type: int = DepartmentDataScript.DepartmentType.SERVICE_DESK

# Size affects speed and points (0.5 to 2.0 scale)
var size_scale: float = 1.0
var radius: float = 16.0
var point_value: int = 10

# Speed limits adjusted by size
var max_speed: float = 500.0
var min_speed: float = 150.0

# Penalty tracking
var wrong_catch_count: int = 0
var has_blame_stamp: bool = false
var speed_multiplier: float = 1.0

# For Quick Favor split behavior
var has_split_on_deflect: bool = false


func _ready() -> void:
	add_to_group("tickets")
	_apply_size()
	queue_redraw()

	# Connect to body collision for split detection
	body_entered.connect(_on_body_entered)
	contact_monitor = true
	max_contacts_reported = 4


func set_random_size() -> void:
	# Random size between 0.5x and 2.0x
	size_scale = randf_range(0.5, 2.0)
	_apply_size()


func _apply_size() -> void:
	# Base radius is 16, scale it
	radius = 16.0 * size_scale

	# Bigger = slower
	var speed_factor: float = 1.0 / size_scale  # 0.5 size = 2x speed, 2.0 size = 0.5x speed
	max_speed = 500.0 * speed_factor
	min_speed = 150.0 * speed_factor
	base_speed = 300.0 * speed_factor

	# Bigger = more points (10 to 40 points based on size)
	point_value = int(10 + (size_scale - 0.5) * 20)

	_update_collision_shape()
	queue_redraw()


func _update_collision_shape() -> void:
	var col_shape := get_node_or_null("CollisionShape2D")
	if col_shape:
		var circle := CircleShape2D.new()
		circle.radius = radius
		col_shape.shape = circle


func _physics_process(_delta: float) -> void:
	_clamp_speed()


func _clamp_speed() -> void:
	var effective_max: float = max_speed * speed_multiplier
	var effective_min: float = min_speed * speed_multiplier
	var speed: float = linear_velocity.length()

	if speed > effective_max:
		linear_velocity = linear_velocity.normalized() * effective_max
	elif speed < effective_min and speed > 0:
		linear_velocity = linear_velocity.normalized() * effective_min


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("paddles"):
		# Blend the paddle's movement velocity into the ball so that moving
		# left/right (or up/down for vertical paddles) visibly steers the ball.
		if "velocity" in body:
			linear_velocity += body.velocity * 0.5


func _draw() -> void:
	# Draw the ticket as a colored circle
	draw_circle(Vector2.ZERO, radius, ticket_color)

	# Add border - thicker for large tickets
	var border_width: float = 2.0 + size_scale
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ticket_color.lightened(0.3), border_width)

	# Draw blame stamp indicator (X mark)
	if has_blame_stamp:
		var stamp_color := Color.BLACK
		stamp_color.a = 0.7
		var stamp_size: float = radius * 0.5
		draw_line(Vector2(-stamp_size, -stamp_size), Vector2(stamp_size, stamp_size), stamp_color, 3.0)
		draw_line(Vector2(stamp_size, -stamp_size), Vector2(-stamp_size, stamp_size), stamp_color, 3.0)


func set_ticket_color(color: Color) -> void:
	ticket_color = color
	queue_redraw()


func set_department(dept_type: int) -> void:
	department_type = dept_type
	ticket_color = DepartmentDataScript.get_color(dept_type)
	queue_redraw()


func matches_department(dept_type: int) -> bool:
	return department_type == dept_type


func get_point_value() -> int:
	return point_value


func apply_wrong_catch_penalty() -> void:
	wrong_catch_count += 1

	if wrong_catch_count == 1:
		speed_multiplier = 1.5
	elif wrong_catch_count == 2:
		speed_multiplier = 1.3
	else:
		has_blame_stamp = true
		speed_multiplier = 1.2

	queue_redraw()


func get_penalty_level() -> int:
	return wrong_catch_count


func should_split_on_wrong_catch() -> bool:
	return false  # Simplified - no special types for now
