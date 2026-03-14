extends Area2D
class_name ColourZone
## A zone at the edge of the arena belonging to a colour
## Balls entering this zone score points (correct colour) or lose points (wrong colour)

const ColourData = preload("res://scripts/resources/department_data.gd")

signal score_up(colour_type: int, points: int)
signal score_down(colour_type: int, points: int)
signal wrong_catch(ball: Node2D, colour_type: int)

@export_enum("BLUE", "GREEN", "RED", "YELLOW", "PURPLE") var colour_type: int = 0
@export var zone_depth: float = 60.0

var zone_color: Color
var is_collapsed: bool = false

# Flash effects
var flash_timer: float = 0.0
var flash_color: Color = Color.WHITE
var is_flashing: bool = false

## Custom parallelogram draw shape in local space.
## Set by arena.gd via set_draw_shape() so adjacent zones share polygon corner
## vertices and form a seamless frame. Overrides the default rect draw.
var draw_vertices: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	zone_color = ColourData.get_color(colour_type)
	zone_color.a = 0.3

	body_entered.connect(_on_body_entered)
	queue_redraw()


func set_draw_shape(v_a: Vector2, v_b: Vector2, outward: Vector2, depth: float) -> void:
	## Build a parallelogram from world-space polygon edge vertices.
	## v_a, v_b are the two corner vertices of the polygon edge; outward is the
	## true edge normal pointing away from the polygon interior.
	draw_vertices = PackedVector2Array([
		to_local(v_a),
		to_local(v_b),
		to_local(v_b + outward * depth),
		to_local(v_a + outward * depth),
	])
	queue_redraw()


func _process(delta: float) -> void:
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
		queue_redraw()


func _draw() -> void:
	var bg_color: Color
	if is_collapsed:
		bg_color = Color.DARK_GRAY
		bg_color.a = 0.5
	elif is_flashing:
		var flash_intensity: float = flash_timer / 0.3
		bg_color = zone_color.lerp(flash_color, flash_intensity * 0.6)
	else:
		bg_color = zone_color

	var border_color: Color = ColourData.get_color(colour_type)
	if is_collapsed:
		border_color = Color.DARK_GRAY
	border_color.a = 0.8

	if draw_vertices.size() >= 4:
		draw_colored_polygon(draw_vertices, bg_color)
		var outline := draw_vertices.duplicate()
		outline.append(draw_vertices[0])
		draw_polyline(outline, border_color, 3.0)
	else:
		# Fallback rect (used before set_draw_shape is called)
		var col_shape := get_node_or_null("CollisionShape2D")
		if col_shape and col_shape.shape is RectangleShape2D:
			var shape := col_shape.shape as RectangleShape2D
			var rect := Rect2(-shape.size / 2, shape.size)
			draw_rect(rect, bg_color)
			draw_rect(rect, border_color, false, 3.0)


func _on_body_entered(body: Node2D) -> void:
	if is_collapsed:
		return
	if body.is_in_group("balls"):
		_handle_ball(body)


func _handle_ball(ball: Node2D) -> void:
	var points: int = ball.get_point_value()
	var is_correct: bool = ball.matches_colour(colour_type)

	if is_correct:
		_flash(Color.GREEN)
		score_up.emit(colour_type, points)
		AudioManager.play_correct_catch()
	else:
		_flash(Color.RED)
		score_down.emit(colour_type, points)
		wrong_catch.emit(ball, colour_type)
		AudioManager.play_wrong_catch()

	ball.queue_free()


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


func is_zone_collapsed() -> bool:
	return is_collapsed


func get_zone_color() -> Color:
	return ColourData.get_color(colour_type)
