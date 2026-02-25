extends RigidBody2D
class_name Ticket
## Ticket - A bouncing ball in the arena

const ColourData = preload("res://scripts/resources/department_data.gd")

signal request_split(ticket: RigidBody2D, count: int)

@export var ticket_color: Color = Color.DODGER_BLUE
@export var base_speed: float = 300.0

# Colour this ticket belongs to
var colour_type: int = ColourData.ColourType.BLUE

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

# Split control — split children cannot re-split
var can_split: bool = true

# Cooldown to prevent multiple split signals from one collision
var split_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("tickets")
	_apply_size()
	queue_redraw()

	body_entered.connect(_on_body_entered)
	contact_monitor = true
	max_contacts_reported = 4


func set_random_size() -> void:
	size_scale = randf_range(0.5, 2.0)
	_apply_size()


func _apply_size() -> void:
	radius = 16.0 * size_scale

	var speed_factor: float = 1.0 / size_scale
	max_speed = 500.0 * speed_factor
	min_speed = 150.0 * speed_factor
	base_speed = 300.0 * speed_factor

	point_value = int(10 + (size_scale - 0.5) * 20)

	_update_collision_shape()
	queue_redraw()


func _update_collision_shape() -> void:
	var col_shape := get_node_or_null("CollisionShape2D")
	if col_shape:
		var circle := CircleShape2D.new()
		circle.radius = radius
		col_shape.shape = circle


func _physics_process(delta: float) -> void:
	_clamp_speed()
	if split_cooldown > 0:
		split_cooldown -= delta


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
		# Blend paddle movement into the ball for directional control feel
		if "velocity" in body:
			linear_velocity += body.velocity * 0.5

		# Double Rebound power up: split when hitting the player paddle
		if can_split and split_cooldown <= 0.0 and body.is_in_group("player_paddle"):
			if GameConfig.selected_power_up == "double_rebound":
				split_cooldown = 0.5
				request_split.emit(self, 2)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, ticket_color)

	var border_width: float = 2.0 + size_scale
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ticket_color.lightened(0.3), border_width)

	if has_blame_stamp:
		var stamp_color := Color.BLACK
		stamp_color.a = 0.7
		var stamp_size: float = radius * 0.5
		draw_line(Vector2(-stamp_size, -stamp_size), Vector2(stamp_size, stamp_size), stamp_color, 3.0)
		draw_line(Vector2(stamp_size, -stamp_size), Vector2(-stamp_size, stamp_size), stamp_color, 3.0)


func set_ticket_color(color: Color) -> void:
	ticket_color = color
	queue_redraw()


func set_colour(ct: int) -> void:
	colour_type = ct
	ticket_color = ColourData.get_color(ct)
	queue_redraw()


func matches_colour(ct: int) -> bool:
	return colour_type == ct


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
