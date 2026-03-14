extends CharacterBody2D
class_name Paddle
## Base paddle class for deflecting tickets.
## The paddle is ALWAYS drawn as a horizontal bar in local space.
## arena.gd sets `rotation` on the node to orient it along its zone edge,
## and sets the movement properties before add_child() so _ready() has them.

const ColourData = preload("res://scripts/resources/department_data.gd")

@export_enum("BLUE", "GREEN", "RED", "YELLOW", "PURPLE", "ORANGE", "CYAN", "PINK") var colour_type: int = 0
@export var paddle_length: float = 100.0
@export var paddle_thickness: float = 12.0

var paddle_color: Color

## Set by arena.gd before add_child(). Unit vector along the zone edge in world space.
var move_direction: Vector2 = Vector2(1.0, 0.0)
## Set by arena.gd. Unit vector pointing outward from the arena centre through this zone.
var outward_dir: Vector2 = Vector2(0.0, 1.0)
## Set by arena.gd. World-space position of the paddle's resting centre.
var zone_centre: Vector2 = Vector2.ZERO
## Signed scalar bounds along move_direction from zone_centre.
var min_offset: float = -150.0
var max_offset: float =  150.0


func _ready() -> void:
	add_to_group("paddles")
	paddle_color = ColourData.get_color(colour_type)
	_setup_collision_shape()
	# Layer 4 (bit value 8): paddle–paddle collision only.
	# Keeps paddle–ticket physics on lower layers unchanged.
	collision_layer |= 8
	collision_mask  |= 8
	queue_redraw()


func _setup_collision_shape() -> void:
	## Collision shape is always paddle_length × paddle_thickness in local space.
	## The node's rotation aligns it with its zone edge.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(paddle_length, paddle_thickness)
	$CollisionShape2D.shape = shape


func _draw() -> void:
	var size := Vector2(paddle_length, paddle_thickness)
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, paddle_color)
	draw_rect(rect, paddle_color.lightened(0.3), false, 2.0)


## Returns the current signed offset from zone_centre along move_direction.
func get_slide_offset() -> float:
	return (global_position - zone_centre).dot(move_direction)


## Sets position so the paddle is at `t` along move_direction from zone_centre,
## clamped to [min_offset, max_offset].
func set_slide_offset(t: float) -> void:
	t = clampf(t, min_offset, max_offset)
	global_position = zone_centre + move_direction * t


func get_paddle_color() -> Color:
	return paddle_color
