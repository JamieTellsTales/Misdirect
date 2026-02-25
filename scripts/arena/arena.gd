extends Node2D
## Arena - Octagonal arena with fixed-size colour zones
## Corner walls adjust to screen aspect ratio, zones stay fair

const ColourData = preload("res://scripts/resources/department_data.gd")

# Screen dimensions (can be any aspect ratio)
const ARENA_WIDTH: float = 1280.0
const ARENA_HEIGHT: float = 720.0

# Fixed zone dimensions - same for ALL colours (fair!)
const ZONE_LENGTH: float = 400.0  # Width/height of defended area
const ZONE_DEPTH: float = 60.0    # How far zone extends into arena
const WALL_THICKNESS: float = 10.0
const PADDLE_THICKNESS: float = 12.0

@export var ticket_spawn_interval: float = 2.5
@export var max_tickets: int = 10
@export var round_duration: float = 120.0  # 2 minutes

# Wall references (8 walls for octagon)
var cardinal_walls: Dictionary = {}  # "north", "south", "east", "west" -> StaticBody2D
var corner_walls: Array = []         # 4 diagonal corner walls

var ticket_scene: PackedScene = preload("res://scenes/components/ticket.tscn")
var zone_scene: PackedScene = preload("res://scenes/components/department_zone.tscn")
var paddle_scene: PackedScene = preload("res://scenes/components/paddle.tscn")
var player_paddle_scene: PackedScene = preload("res://scenes/components/player_paddle.tscn")
var ai_paddle_scene: PackedScene = preload("res://scenes/components/ai_paddle.tscn")
var score_display_scene: PackedScene = preload("res://scenes/components/score_display.tscn")
var timer_display_scene: PackedScene = preload("res://scenes/components/round_timer_display.tscn")
var game_over_scene: PackedScene = preload("res://scenes/game_over.tscn")

var zones: Dictionary = {}         # colour_type int -> ColourZone
var paddles: Dictionary = {}       # colour_type int -> Paddle
var score_displays: Dictionary = {} # colour_type int -> ScoreDisplay
var scores: Dictionary = {}        # colour_type int -> int
var collapsed_colours: Array = []
var player_colour: int = ColourData.ColourType.GREEN  # Player controls bottom zone

var spawn_timer: float = 0.0
var spawn_colour_index: int = 0
var timer_display: Control = null
var game_over_screen: Control = null
var is_game_over: bool = false

# Active colours (the 4 used in arena)
var active_colours: Array = [
	ColourData.ColourType.BLUE,
	ColourData.ColourType.GREEN,
	ColourData.ColourType.RED,
	ColourData.ColourType.YELLOW,
]


func _ready() -> void:
	_init_scores()
	_setup_octagon_walls()
	_setup_colour_zones()
	_setup_paddles()
	_setup_score_displays()
	_setup_timer_display()
	_setup_game_over_screen()
	_start_round()


func _process(delta: float) -> void:
	if is_game_over:
		return

	spawn_timer += delta
	if spawn_timer >= ticket_spawn_interval:
		spawn_timer = 0.0
		_try_spawn_ticket()


func _init_scores() -> void:
	for ct in active_colours:
		scores[ct] = 0


func _start_round() -> void:
	is_game_over = false
	collapsed_colours.clear()
	if timer_display:
		timer_display.round_duration = round_duration
		timer_display.start_timer()
	_spawn_ticket()
	_spawn_ticket()  # Start with 2 tickets


func _end_round() -> void:
	is_game_over = true
	if timer_display:
		timer_display.stop_timer()

	if game_over_screen:
		game_over_screen.show_results(scores, player_colour, collapsed_colours)


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_octagon_walls() -> void:
	var walls_node := get_node_or_null("Walls")
	if walls_node:
		for child in walls_node.get_children():
			child.queue_free()

	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0

	_create_cardinal_wall(
		"north",
		Vector2(center_x, WALL_THICKNESS / 2.0),
		Vector2(ARENA_WIDTH, WALL_THICKNESS)
	)
	_create_cardinal_wall(
		"south",
		Vector2(center_x, ARENA_HEIGHT - WALL_THICKNESS / 2.0),
		Vector2(ARENA_WIDTH, WALL_THICKNESS)
	)
	_create_cardinal_wall(
		"west",
		Vector2(WALL_THICKNESS / 2.0, center_y),
		Vector2(WALL_THICKNESS, ARENA_HEIGHT)
	)
	_create_cardinal_wall(
		"east",
		Vector2(ARENA_WIDTH - WALL_THICKNESS / 2.0, center_y),
		Vector2(WALL_THICKNESS, ARENA_HEIGHT)
	)

	var corner_inset: float = ZONE_DEPTH + WALL_THICKNESS  # = 70

	_create_corner_wall(
		Vector2(center_x - ZONE_LENGTH / 2.0, corner_inset),
		Vector2(corner_inset, center_y - ZONE_LENGTH / 2.0)
	)
	_create_corner_wall(
		Vector2(center_x + ZONE_LENGTH / 2.0, corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y - ZONE_LENGTH / 2.0)
	)
	_create_corner_wall(
		Vector2(center_x - ZONE_LENGTH / 2.0, ARENA_HEIGHT - corner_inset),
		Vector2(corner_inset, center_y + ZONE_LENGTH / 2.0)
	)
	_create_corner_wall(
		Vector2(center_x + ZONE_LENGTH / 2.0, ARENA_HEIGHT - corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y + ZONE_LENGTH / 2.0)
	)


func _create_cardinal_wall(wall_name: String, pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name.capitalize() + "Wall"
	wall.position = pos

	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce = 1.0
	physics_mat.friction = 0.0
	wall.physics_material_override = physics_mat

	var col_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col_shape.shape = rect
	wall.add_child(col_shape)

	$Walls.add_child(wall)
	cardinal_walls[wall_name] = wall


func _create_corner_wall(point_a: Vector2, point_b: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = "CornerWall"

	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce = 1.0
	physics_mat.friction = 0.0
	wall.physics_material_override = physics_mat

	var midpoint: Vector2 = (point_a + point_b) / 2.0
	wall.position = midpoint

	var direction: Vector2 = point_b - point_a
	var angle: float = direction.angle()
	wall.rotation = angle

	var col_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(direction.length(), WALL_THICKNESS)
	col_shape.shape = rect
	wall.add_child(col_shape)

	$Walls.add_child(wall)
	corner_walls.append(wall)


func _setup_colour_zones() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0

	# North zone (Blue)
	_create_zone(
		ColourData.ColourType.BLUE,
		Vector2(center_x, ZONE_DEPTH / 2.0 + WALL_THICKNESS),
		Vector2(ZONE_LENGTH, ZONE_DEPTH)
	)

	# South zone (Green) — player zone
	_create_zone(
		ColourData.ColourType.GREEN,
		Vector2(center_x, ARENA_HEIGHT - ZONE_DEPTH / 2.0 - WALL_THICKNESS),
		Vector2(ZONE_LENGTH, ZONE_DEPTH)
	)

	# West zone (Red)
	_create_zone(
		ColourData.ColourType.RED,
		Vector2(ZONE_DEPTH / 2.0 + WALL_THICKNESS, center_y),
		Vector2(ZONE_DEPTH, ZONE_LENGTH)
	)

	# East zone (Yellow)
	_create_zone(
		ColourData.ColourType.YELLOW,
		Vector2(ARENA_WIDTH - ZONE_DEPTH / 2.0 - WALL_THICKNESS, center_y),
		Vector2(ZONE_DEPTH, ZONE_LENGTH)
	)


func _create_zone(ct: int, pos: Vector2, size: Vector2) -> void:
	var zone = zone_scene.instantiate()
	zone.colour_type = ct
	zone.position = pos

	var shape := RectangleShape2D.new()
	shape.size = size
	zone.get_node("CollisionShape2D").shape = shape

	zone.score_up.connect(_on_score_up)
	zone.score_down.connect(_on_score_down)
	zone.wrong_catch.connect(_on_wrong_catch)

	add_child(zone)
	zones[ct] = zone


func _setup_paddles() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var paddle_offset: float = PADDLE_THICKNESS / 2.0

	# North paddle (Blue)
	_create_paddle(
		ColourData.ColourType.BLUE,
		Vector2(center_x, ZONE_DEPTH + WALL_THICKNESS + paddle_offset),
		true
	)

	# South paddle (Green) — player
	_create_paddle(
		ColourData.ColourType.GREEN,
		Vector2(center_x, ARENA_HEIGHT - ZONE_DEPTH - WALL_THICKNESS - paddle_offset),
		true
	)

	# West paddle (Red)
	_create_paddle(
		ColourData.ColourType.RED,
		Vector2(ZONE_DEPTH + WALL_THICKNESS + paddle_offset, center_y),
		false
	)

	# East paddle (Yellow)
	_create_paddle(
		ColourData.ColourType.YELLOW,
		Vector2(ARENA_WIDTH - ZONE_DEPTH - WALL_THICKNESS - paddle_offset, center_y),
		false
	)


func _create_paddle(ct: int, pos: Vector2, horizontal: bool) -> void:
	var paddle: CharacterBody2D
	if ct == player_colour:
		paddle = player_paddle_scene.instantiate()
	else:
		paddle = ai_paddle_scene.instantiate()

	paddle.colour_type = ct
	paddle.is_horizontal = horizontal
	paddle.position = pos

	add_child(paddle)
	paddles[ct] = paddle


func _setup_score_displays() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0

	var zone_cy_north: float = WALL_THICKNESS + ZONE_DEPTH / 2.0
	var zone_cy_south: float = ARENA_HEIGHT - WALL_THICKNESS - ZONE_DEPTH / 2.0
	var zone_cx_west: float = WALL_THICKNESS + ZONE_DEPTH / 2.0
	var zone_cx_east: float = ARENA_WIDTH - WALL_THICKNESS - ZONE_DEPTH / 2.0

	_create_score_display(ColourData.ColourType.BLUE,
		Vector2(center_x - 40, zone_cy_north - 17), Vector2(80, 35))
	_create_score_display(ColourData.ColourType.GREEN,
		Vector2(center_x - 40, zone_cy_south - 17), Vector2(80, 35))

	var zone_w: float = ZONE_DEPTH - 2.0
	_create_score_display(ColourData.ColourType.RED,
		Vector2(zone_cx_west - zone_w / 2.0, center_y - 17), Vector2(zone_w, 35))
	_create_score_display(ColourData.ColourType.YELLOW,
		Vector2(zone_cx_east - zone_w / 2.0, center_y - 17), Vector2(zone_w, 35))


func _create_score_display(ct: int, pos: Vector2, ctrl_size: Vector2) -> void:
	var display = score_display_scene.instantiate()
	display.set_colour_zone(ct, ct == player_colour)
	display.position = pos
	add_child(display)
	display.size = ctrl_size
	score_displays[ct] = display


func _setup_timer_display() -> void:
	timer_display = timer_display_scene.instantiate()
	timer_display.position = Vector2(ARENA_WIDTH / 2.0 - 75, ARENA_HEIGHT / 2.0 - 20)
	timer_display.round_duration = round_duration
	timer_display.timer_expired.connect(_on_timer_expired)
	add_child(timer_display)


func _setup_game_over_screen() -> void:
	game_over_screen = game_over_scene.instantiate()
	game_over_screen.restart_requested.connect(_restart_game)
	game_over_screen.quit_requested.connect(_quit_game)
	add_child(game_over_screen)


func _on_timer_expired() -> void:
	_end_round()


func _on_score_up(ct: int, points: int) -> void:
	if scores.has(ct):
		scores[ct] += points
		if score_displays.has(ct):
			score_displays[ct].set_score(scores[ct])


func _on_score_down(ct: int, points: int) -> void:
	if scores.has(ct):
		scores[ct] = max(0, scores[ct] - points)
		if score_displays.has(ct):
			score_displays[ct].set_score(scores[ct])


func _on_wrong_catch(_ticket: Node2D, _ct: int) -> void:
	pass


func _try_spawn_ticket() -> void:
	if is_game_over:
		return
	var ticket_count := get_tree().get_nodes_in_group("tickets").size()
	if ticket_count < max_tickets:
		_spawn_ticket()


func _spawn_ticket() -> void:
	var ticket := ticket_scene.instantiate()

	ticket.position = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0)

	# Rotate through colours so every zone receives the same number of tickets
	var ct: int = active_colours[spawn_colour_index % active_colours.size()]
	spawn_colour_index += 1
	ticket.set_colour(ct)

	ticket.set_random_size()

	add_child(ticket)

	# Connect split signal for Double Rebound power up
	ticket.request_split.connect(_on_ticket_split)

	# Determine launch angle based on active modifiers
	var vel_angle: float
	if GameConfig.has_modifier("random_directions"):
		# Modifier: fully random direction (classic chaos mode)
		vel_angle = randf_range(0.0, TAU)
	else:
		# Default: aim roughly toward matching zone with ±20° spread
		var base_angle: float = _get_zone_direction_angle(ct)
		var spread: float = PI / 9.0  # ±20 degrees — stays within zone opening
		vel_angle = base_angle + randf_range(-spread, spread)

	ticket.linear_velocity = Vector2.from_angle(vel_angle) * ticket.base_speed


func _get_zone_direction_angle(ct: int) -> float:
	## Returns the angle from the arena centre toward the given colour's zone.
	## With the rotated_colours modifier, each colour targets the next zone clockwise.
	var colour_index: int = active_colours.find(ct)
	var target_index: int = colour_index

	if GameConfig.has_modifier("rotated_colours"):
		target_index = (colour_index + 1) % active_colours.size()

	var target_ct: int = active_colours[target_index]

	match target_ct:
		ColourData.ColourType.BLUE:
			return -PI / 2.0  # North (up)
		ColourData.ColourType.GREEN:
			return PI / 2.0   # South (down)
		ColourData.ColourType.RED:
			return PI          # West (left)
		ColourData.ColourType.YELLOW:
			return 0.0         # East (right)
		_:
			return randf_range(0.0, TAU)


func _on_ticket_split(original: RigidBody2D, count: int) -> void:
	if not is_instance_valid(original):
		return

	var pos: Vector2 = original.position
	var vel: Vector2 = original.linear_velocity
	var ct: int = original.colour_type
	var sz: float = original.size_scale

	original.queue_free()

	for i in count:
		var t: RigidBody2D = ticket_scene.instantiate()
		t.position = pos
		t.set_colour(ct)
		t.size_scale = max(0.4, sz * 0.75)
		t.can_split = false  # Split children cannot re-split
		add_child(t)
		t._apply_size()

		var angle: float = vel.angle() + randf_range(-PI / 5.0, PI / 5.0)
		t.linear_velocity = Vector2.from_angle(angle) * vel.length() * 1.1

		t.request_split.connect(_on_ticket_split)


func _draw() -> void:
	_draw_octagon_outline()
	_draw_corner_regions()


func _draw_octagon_outline() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var half_zone: float = ZONE_LENGTH / 2.0
	var corner_inset: float = ZONE_DEPTH + WALL_THICKNESS  # = 70

	var points: PackedVector2Array = [
		Vector2(center_x - half_zone, corner_inset),
		Vector2(center_x + half_zone, corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y - half_zone),
		Vector2(ARENA_WIDTH - corner_inset, center_y + half_zone),
		Vector2(center_x + half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(center_x - half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(corner_inset, center_y + half_zone),
		Vector2(corner_inset, center_y - half_zone),
	]

	var zone_color := Color(0.4, 0.4, 0.5, 0.5)
	var corner_color_line := Color(0.7, 0.7, 0.8, 0.9)

	for i in range(points.size()):
		var start := points[i]
		var end := points[(i + 1) % points.size()]
		var color := zone_color if i % 2 == 0 else corner_color_line
		var width := 2.0 if i % 2 == 0 else 3.0
		draw_line(start, end, color, width)


func _draw_corner_regions() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var half_zone: float = ZONE_LENGTH / 2.0
	var corner_inset: float = ZONE_DEPTH + WALL_THICKNESS  # = 70
	var fill := Color(0.05, 0.05, 0.08, 1.0)

	# Top-left
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0),
		Vector2(center_x - half_zone, 0),
		Vector2(center_x - half_zone, corner_inset),
		Vector2(corner_inset, center_y - half_zone),
		Vector2(0, center_y - half_zone),
	]), fill)

	# Top-right
	draw_colored_polygon(PackedVector2Array([
		Vector2(ARENA_WIDTH, 0),
		Vector2(ARENA_WIDTH, center_y - half_zone),
		Vector2(ARENA_WIDTH - corner_inset, center_y - half_zone),
		Vector2(center_x + half_zone, corner_inset),
		Vector2(center_x + half_zone, 0),
	]), fill)

	# Bottom-left
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, ARENA_HEIGHT),
		Vector2(0, center_y + half_zone),
		Vector2(corner_inset, center_y + half_zone),
		Vector2(center_x - half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(center_x - half_zone, ARENA_HEIGHT),
	]), fill)

	# Bottom-right
	draw_colored_polygon(PackedVector2Array([
		Vector2(ARENA_WIDTH, ARENA_HEIGHT),
		Vector2(center_x + half_zone, ARENA_HEIGHT),
		Vector2(center_x + half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y + half_zone),
		Vector2(ARENA_WIDTH, center_y + half_zone),
	]), fill)
