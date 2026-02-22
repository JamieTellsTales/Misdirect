extends Node2D
## Arena - Octagonal arena with fixed-size department zones
## Corner walls adjust to screen aspect ratio, zones stay fair

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

# Screen dimensions (can be any aspect ratio)
const ARENA_WIDTH: float = 1280.0
const ARENA_HEIGHT: float = 720.0

# Fixed zone dimensions - same for ALL departments (fair!)
const ZONE_LENGTH: float = 400.0  # Width/height of defended area
const ZONE_DEPTH: float = 60.0    # How far zone extends into arena
const WALL_THICKNESS: float = 10.0
const PADDLE_THICKNESS: float = 12.0

@export var ticket_spawn_interval: float = 2.5
@export var max_tickets: int = 10
@export var round_duration: float = 120.0  # 2 minutes

# Wall references (8 walls for octagon)
var cardinal_walls: Dictionary = {}  # "north", "south", "east", "west" -> StaticBody2D
var corner_walls: Array = []  # 4 diagonal corner walls

var ticket_scene: PackedScene = preload("res://scenes/components/ticket.tscn")
var zone_scene: PackedScene = preload("res://scenes/components/department_zone.tscn")
var paddle_scene: PackedScene = preload("res://scenes/components/paddle.tscn")
var player_paddle_scene: PackedScene = preload("res://scenes/components/player_paddle.tscn")
var ai_paddle_scene: PackedScene = preload("res://scenes/components/ai_paddle.tscn")
var score_display_scene: PackedScene = preload("res://scenes/components/score_display.tscn")
var timer_display_scene: PackedScene = preload("res://scenes/components/round_timer_display.tscn")
var game_over_scene: PackedScene = preload("res://scenes/game_over.tscn")

var zones: Dictionary = {}  # department_type int -> DepartmentZone
var paddles: Dictionary = {}  # department_type int -> Paddle
var score_displays: Dictionary = {}  # department_type int -> ScoreDisplay
var scores: Dictionary = {}  # department_type int -> int
var collapsed_departments: Array = []
var player_department: int = DepartmentDataScript.DepartmentType.INFRASTRUCTURE  # Player controls bottom

var spawn_timer: float = 0.0
var spawn_colour_index: int = 0
var timer_display: Control = null
var game_over_screen: Control = null
var is_game_over: bool = false

# Active departments (the 4 used in arena)
var active_departments: Array = [
	DepartmentDataScript.DepartmentType.SERVICE_DESK,
	DepartmentDataScript.DepartmentType.INFRASTRUCTURE,
	DepartmentDataScript.DepartmentType.SECURITY,
	DepartmentDataScript.DepartmentType.DEVELOPMENT,
]


func _ready() -> void:
	_init_scores()
	_setup_octagon_walls()
	_setup_department_zones()
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
	for dept in active_departments:
		scores[dept] = 0


func _start_round() -> void:
	is_game_over = false
	collapsed_departments.clear()
	if timer_display:
		timer_display.round_duration = round_duration
		timer_display.start_timer()
	_spawn_ticket()
	_spawn_ticket()  # Start with 2 tickets


func _end_round() -> void:
	is_game_over = true
	if timer_display:
		timer_display.stop_timer()

	# Show game over screen
	if game_over_screen:
		game_over_screen.show_results(scores, player_department, collapsed_departments)


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_octagon_walls() -> void:
	# Remove old walls from scene (we'll create new ones)
	var walls_node := get_node_or_null("Walls")
	if walls_node:
		for child in walls_node.get_children():
			child.queue_free()

	# Calculate zone edge positions (zones are centered on each side)
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var half_zone: float = ZONE_LENGTH / 2.0

	# Cardinal walls span the FULL screen edge so the extreme corners are never open
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

	# Corner bumpers sit IN FRONT of (closer to centre than) the player zones.
	# They connect at the inner paddle-face depth on each side so that
	# balls approaching from a corner angle are redirected toward the zones
	# rather than being able to sneak behind the paddles.
	var corner_inset: float = ZONE_DEPTH + WALL_THICKNESS  # = 70 — inner paddle face

	# Top-left: north paddle left tip → west paddle top tip
	_create_corner_wall(
		Vector2(center_x - half_zone, corner_inset),
		Vector2(corner_inset, center_y - half_zone)
	)
	# Top-right: north paddle right tip → east paddle top tip
	_create_corner_wall(
		Vector2(center_x + half_zone, corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y - half_zone)
	)
	# Bottom-left: south paddle left tip → west paddle bottom tip
	_create_corner_wall(
		Vector2(center_x - half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(corner_inset, center_y + half_zone)
	)
	# Bottom-right: south paddle right tip → east paddle bottom tip
	_create_corner_wall(
		Vector2(center_x + half_zone, ARENA_HEIGHT - corner_inset),
		Vector2(ARENA_WIDTH - corner_inset, center_y + half_zone)
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
	# Create a thin rectangle along the diagonal line from point_a to point_b
	var wall := StaticBody2D.new()
	wall.name = "CornerWall"

	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce = 1.0
	physics_mat.friction = 0.0
	wall.physics_material_override = physics_mat

	# Position at midpoint
	var midpoint: Vector2 = (point_a + point_b) / 2.0
	wall.position = midpoint

	# Calculate rotation angle
	var direction: Vector2 = point_b - point_a
	var angle: float = direction.angle()
	wall.rotation = angle

	# Create thin rectangle collision shape
	var col_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(direction.length(), WALL_THICKNESS)
	col_shape.shape = rect
	wall.add_child(col_shape)

	$Walls.add_child(wall)
	corner_walls.append(wall)


func _setup_department_zones() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0

	# North zone (Service Desk) - fixed size, centered at top
	_create_zone(
		DepartmentDataScript.DepartmentType.SERVICE_DESK,
		Vector2(center_x, ZONE_DEPTH / 2.0 + WALL_THICKNESS),
		Vector2(ZONE_LENGTH, ZONE_DEPTH)
	)

	# South zone (Infrastructure) - fixed size, centered at bottom
	_create_zone(
		DepartmentDataScript.DepartmentType.INFRASTRUCTURE,
		Vector2(center_x, ARENA_HEIGHT - ZONE_DEPTH / 2.0 - WALL_THICKNESS),
		Vector2(ZONE_LENGTH, ZONE_DEPTH)
	)

	# West zone (Security) - fixed size, centered at left
	_create_zone(
		DepartmentDataScript.DepartmentType.SECURITY,
		Vector2(ZONE_DEPTH / 2.0 + WALL_THICKNESS, center_y),
		Vector2(ZONE_DEPTH, ZONE_LENGTH)
	)

	# East zone (Development) - fixed size, centered at right
	_create_zone(
		DepartmentDataScript.DepartmentType.DEVELOPMENT,
		Vector2(ARENA_WIDTH - ZONE_DEPTH / 2.0 - WALL_THICKNESS, center_y),
		Vector2(ZONE_DEPTH, ZONE_LENGTH)
	)


func _create_zone(dept_type: int, pos: Vector2, size: Vector2) -> void:
	var zone = zone_scene.instantiate()
	zone.department_type = dept_type
	zone.position = pos

	var shape := RectangleShape2D.new()
	shape.size = size
	zone.get_node("CollisionShape2D").shape = shape

	# Connect signals
	zone.score_up.connect(_on_score_up)
	zone.score_down.connect(_on_score_down)
	zone.wrong_catch.connect(_on_wrong_catch)

	add_child(zone)
	zones[dept_type] = zone


func _setup_paddles() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var paddle_offset: float = PADDLE_THICKNESS / 2.0

	# North paddle (Service Desk) - in front of north zone
	_create_paddle(
		DepartmentDataScript.DepartmentType.SERVICE_DESK,
		Vector2(center_x, ZONE_DEPTH + WALL_THICKNESS + paddle_offset),
		true
	)

	# South paddle (Infrastructure) - in front of south zone
	_create_paddle(
		DepartmentDataScript.DepartmentType.INFRASTRUCTURE,
		Vector2(center_x, ARENA_HEIGHT - ZONE_DEPTH - WALL_THICKNESS - paddle_offset),
		true
	)

	# West paddle (Security) - in front of west zone
	_create_paddle(
		DepartmentDataScript.DepartmentType.SECURITY,
		Vector2(ZONE_DEPTH + WALL_THICKNESS + paddle_offset, center_y),
		false
	)

	# East paddle (Development) - in front of east zone
	_create_paddle(
		DepartmentDataScript.DepartmentType.DEVELOPMENT,
		Vector2(ARENA_WIDTH - ZONE_DEPTH - WALL_THICKNESS - paddle_offset, center_y),
		false
	)


func _create_paddle(dept_type: int, pos: Vector2, horizontal: bool) -> void:
	var paddle: CharacterBody2D
	if dept_type == player_department:
		paddle = player_paddle_scene.instantiate()
	else:
		paddle = ai_paddle_scene.instantiate()

	paddle.department_type = dept_type
	paddle.is_horizontal = horizontal
	paddle.position = pos

	add_child(paddle)
	paddles[dept_type] = paddle


func _setup_score_displays() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var half_zone: float = ZONE_LENGTH / 2.0

	# Zone centres
	var zone_cy_north: float = WALL_THICKNESS + ZONE_DEPTH / 2.0          # y=40
	var zone_cy_south: float = ARENA_HEIGHT - WALL_THICKNESS - ZONE_DEPTH / 2.0  # y=680
	var zone_cx_west: float = WALL_THICKNESS + ZONE_DEPTH / 2.0           # x=40
	var zone_cx_east: float = ARENA_WIDTH - WALL_THICKNESS - ZONE_DEPTH / 2.0   # x=1240

	# North/South — wide control (80×35) centred on the zone midpoint
	_create_score_display(DepartmentDataScript.DepartmentType.SERVICE_DESK,
		Vector2(center_x - 40, zone_cy_north - 17), Vector2(80, 35))
	_create_score_display(DepartmentDataScript.DepartmentType.INFRASTRUCTURE,
		Vector2(center_x - 40, zone_cy_south - 17), Vector2(80, 35))

	# East/West — control sized to fill the 60 px zone width, centred vertically
	var zone_w: float = ZONE_DEPTH - 2.0  # 58 px — 1 px margin each side
	_create_score_display(DepartmentDataScript.DepartmentType.SECURITY,
		Vector2(zone_cx_west - zone_w / 2.0, center_y - 17), Vector2(zone_w, 35))
	_create_score_display(DepartmentDataScript.DepartmentType.DEVELOPMENT,
		Vector2(zone_cx_east - zone_w / 2.0, center_y - 17), Vector2(zone_w, 35))


func _create_score_display(dept_type: int, pos: Vector2, ctrl_size: Vector2) -> void:
	var display = score_display_scene.instantiate()
	display.set_department(dept_type, dept_type == player_department)
	display.position = pos
	add_child(display)
	# Set size AFTER add_child so it overrides the .tscn offset values
	display.size = ctrl_size
	score_displays[dept_type] = display


func _setup_timer_display() -> void:
	timer_display = timer_display_scene.instantiate()
	# Centre of arena — positioned so the 150x40 control is centred on screen
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


func _on_score_up(dept_type: int, points: int) -> void:
	if scores.has(dept_type):
		scores[dept_type] += points
		if score_displays.has(dept_type):
			score_displays[dept_type].set_score(scores[dept_type])


func _on_score_down(dept_type: int, points: int) -> void:
	if scores.has(dept_type):
		scores[dept_type] = max(0, scores[dept_type] - points)
		if score_displays.has(dept_type):
			score_displays[dept_type].set_score(scores[dept_type])


func _on_wrong_catch(ticket: Node2D, _catching_dept: int) -> void:
	# Wrong catch - ticket is already removed by zone
	# Could add visual/audio feedback here
	pass


func _try_spawn_ticket() -> void:
	if is_game_over:
		return
	var ticket_count := get_tree().get_nodes_in_group("tickets").size()
	if ticket_count < max_tickets:
		_spawn_ticket()


func _spawn_ticket() -> void:
	var ticket := ticket_scene.instantiate()

	# Always spawn from the exact centre of the arena
	ticket.position = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0)

	# Rotate through department colours in fixed order so every department
	# receives the same number of tickets over time (fair distribution)
	var dept: int = active_departments[spawn_colour_index % active_departments.size()]
	spawn_colour_index += 1
	ticket.set_department(dept)

	ticket.set_random_size()

	add_child(ticket)

	# Initial velocity — random direction, speed based on size
	var vel_angle: float = randf_range(0, TAU)
	ticket.linear_velocity = Vector2.from_angle(vel_angle) * ticket.base_speed


func _draw() -> void:
	_draw_octagon_outline()
	_draw_corner_regions()


func _draw_octagon_outline() -> void:
	var center_x: float = ARENA_WIDTH / 2.0
	var center_y: float = ARENA_HEIGHT / 2.0
	var half_zone: float = ZONE_LENGTH / 2.0
	var corner_inset: float = ZONE_DEPTH + WALL_THICKNESS  # = 70

	# Octagon traces the INNER play-field boundary — corner segments are the
	# inward bumper walls, zone segments are the openings to each player area.
	var points: PackedVector2Array = [
		Vector2(center_x - half_zone, corner_inset),       # north-left inner
		Vector2(center_x + half_zone, corner_inset),       # north-right inner
		Vector2(ARENA_WIDTH - corner_inset, center_y - half_zone),  # east-top inner
		Vector2(ARENA_WIDTH - corner_inset, center_y + half_zone),  # east-bottom inner
		Vector2(center_x + half_zone, ARENA_HEIGHT - corner_inset), # south-right inner
		Vector2(center_x - half_zone, ARENA_HEIGHT - corner_inset), # south-left inner
		Vector2(corner_inset, center_y + half_zone),       # west-bottom inner
		Vector2(corner_inset, center_y - half_zone),       # west-top inner
	]

	# Zone openings (straight segments) — subtle colour
	var zone_color := Color(0.4, 0.4, 0.5, 0.5)
	# Corner bumpers (diagonal segments) — brighter so they read as walls
	var corner_color_line := Color(0.7, 0.7, 0.8, 0.9)

	for i in range(points.size()):
		var start := points[i]
		var end := points[(i + 1) % points.size()]
		# Even indices are zone edges, odd indices are corner diagonals
		var color := zone_color if i % 2 == 0 else corner_color_line
		var width := 2.0 if i % 2 == 0 else 3.0
		draw_line(start, end, color, width)


func _draw_corner_regions() -> void:
	# Fill the corner dead zones from the screen corner out to the inward bumper walls.
	# Each region is a pentagon: screen-corner → zone edge on one axis →
	# corner bumper endpoints → zone edge on the other axis.
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
