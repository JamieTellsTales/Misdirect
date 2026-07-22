extends CharacterBody2D
class_name Paddle
## Base paddle class for deflecting balls.
## The paddle is ALWAYS drawn as a horizontal bar in local space.
## arena.gd sets `rotation` on the node to orient it along its zone edge,
## and sets the movement properties before add_child() so _ready() has them.

const ColourData = preload("res://scripts/resources/colour_data.gd")

@export_enum("BLUE", "GREEN", "RED", "YELLOW", "PURPLE", "ORANGE", "CYAN", "PINK") var colour_type: int = 0
@export var paddle_length: float = 100.0
@export var paddle_thickness: float = 12.0

var paddle_color: Color
var use_deflector: bool = false
## Set by arena.gd before add_child(). Portrait-mode arena scale — multiply all
## speed/range/force constants by this so gameplay feel matches landscape.
var arena_scale: float = 1.0

## Set by arena.gd before add_child(). Unit vector along the zone edge in world space.
var move_direction: Vector2 = Vector2(1.0, 0.0)
## Set by arena.gd. Unit vector pointing outward from the arena centre through this zone.
var outward_dir: Vector2 = Vector2(0.0, 1.0)
## Set by arena.gd. World-space position of the paddle's resting centre.
var zone_centre: Vector2 = Vector2.ZERO
## Signed scalar bounds along move_direction from zone_centre.
var min_offset: float = -150.0
var max_offset: float =  150.0


var _flash_timer: float = 0.0   # Red hit-flash countdown (life lost)
const FLASH_DUR: float = 0.35


func _ready() -> void:
	add_to_group("paddles")
	paddle_color = ColourData.get_color(colour_type)
	_setup_collision_shape()
	# Layer 4 (bit value 8): paddle–paddle collision only.
	# Keeps paddle–ball physics on lower layers unchanged.
	collision_layer |= 8
	collision_mask  |= 8
	queue_redraw()


func hit_flash() -> void:
	## Flash the paddle red — called by arena.gd when this zone loses a life.
	_flash_timer = FLASH_DUR
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()


func _setup_collision_shape() -> void:
	## Collision shape is always paddle_length × paddle_thickness in local space.
	## The node's rotation aligns it with its zone edge.
	if use_deflector:
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([
			Vector2(-paddle_length / 2.0,  paddle_thickness / 2.0),
			Vector2( paddle_length / 2.0,  paddle_thickness / 2.0),
			Vector2(0.0,                  -paddle_thickness),
		])
		$CollisionShape2D.shape = shape
	else:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(paddle_length, paddle_thickness)
		$CollisionShape2D.shape = shape


func _draw() -> void:
	var fill: Color = paddle_color
	if _flash_timer > 0.0:
		fill = paddle_color.lerp(Color(1.0, 0.25, 0.2), _flash_timer / FLASH_DUR)

	if use_deflector:
		var tri := PackedVector2Array([
			Vector2(-paddle_length / 2.0,  paddle_thickness / 2.0),
			Vector2( paddle_length / 2.0,  paddle_thickness / 2.0),
			Vector2(0.0,                  -paddle_thickness),
		])
		draw_colored_polygon(tri, fill)
		var border := PackedVector2Array(tri)
		border.append(border[0])
		draw_polyline(border, fill.lightened(0.3), 2.0)
	else:
		var size := Vector2(paddle_length, paddle_thickness)
		var rect := Rect2(-size / 2.0, size)
		draw_rect(rect, fill)
		draw_rect(rect, fill.lightened(0.3), false, 2.0)


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
