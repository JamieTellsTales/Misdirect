extends Node2D
## Arena — dynamic polygon arena built from GameConfig.selected_map and num_players.
## Polygon vertices are defined clockwise starting from the bottom-left of the player's
## side (side 0). Zone / paddle positions are computed from the polygon geometry at runtime.

const ColourData = preload("res://scripts/resources/department_data.gd")

const ARENA_WIDTH:  float = 1280.0
const ARENA_HEIGHT: float = 720.0

const ZONE_LENGTH:       float = 400.0
const ZONE_DEPTH:        float = 60.0
const WALL_THICKNESS:    float = 10.0
const PADDLE_THICKNESS:  float = 12.0

## Colour slot order: slot 0 = player (always GREEN), remaining slots = AI colours.
const SLOT_COLOURS: Array = [
	ColourData.ColourType.GREEN,
	ColourData.ColourType.BLUE,
	ColourData.ColourType.RED,
	ColourData.ColourType.YELLOW,
	ColourData.ColourType.PURPLE,
	ColourData.ColourType.ORANGE,
	ColourData.ColourType.CYAN,
	ColourData.ColourType.PINK,
]

@export var ticket_spawn_interval: float = 2.5
@export var max_tickets: int = 10
@export var round_duration: float = 120.0

var ticket_scene:        PackedScene = preload("res://scenes/components/ticket.tscn")
var zone_scene:          PackedScene = preload("res://scenes/components/department_zone.tscn")
var paddle_scene:        PackedScene = preload("res://scenes/components/paddle.tscn")
var player_paddle_scene: PackedScene = preload("res://scenes/components/player_paddle.tscn")
var ai_paddle_scene:     PackedScene = preload("res://scenes/components/ai_paddle.tscn")
var score_display_scene: PackedScene = preload("res://scenes/components/score_display.tscn")
var timer_display_scene: PackedScene = preload("res://scenes/components/round_timer_display.tscn")
var game_over_scene:     PackedScene = preload("res://scenes/game_over.tscn")
var pause_menu_scene:    PackedScene = preload("res://scenes/pause_menu.tscn")
var settings_screen_scene: PackedScene = preload("res://scenes/settings_screen.tscn")

var zones:          Dictionary = {}   # colour_type -> ColourZone Area2D
var paddles:        Dictionary = {}   # colour_type -> Paddle
var score_displays: Dictionary = {}   # colour_type -> ScoreDisplay
var scores:         Dictionary = {}   # colour_type -> int
var collapsed_colours: Array  = []
var player_colour: int = ColourData.ColourType.GREEN

## Built in _build_active_colours() from GameConfig.
var active_colours:   Array      = []       # ordered list of colour_type ints
var _side_for_colour: Dictionary = {}       # colour_type -> polygon side index
var _zone_angles:     Dictionary = {}       # colour_type -> outward normal angle (radians)
var _map_vertices:    PackedVector2Array    # polygon vertices for current map

var spawn_timer:       float = 0.0
var spawn_colour_index: int  = 0
var session_time:      float = 0.0
var timer_display:     Control = null
var game_over_screen:  Control = null
var pause_menu:        Node2D  = null
var settings_overlay:  Node2D  = null
var is_game_over:      bool    = false


func _ready() -> void:
	_build_active_colours()
	_init_scores()
	_setup_walls()
	_setup_colour_zones()
	_setup_paddles()
	_setup_score_displays()
	_setup_timer_display()
	_setup_game_over_screen()
	_setup_pause_menu()
	_start_round()


func _process(delta: float) -> void:
	if is_game_over:
		return
	session_time += delta
	spawn_timer += delta
	if spawn_timer >= ticket_spawn_interval:
		spawn_timer = 0.0
		_try_spawn_ticket()


# ── Active colours ─────────────────────────────────────────────────────────────

func _build_active_colours() -> void:
	## Build active_colours, _side_for_colour, _zone_angles from GameConfig.
	_map_vertices  = _get_map_vertices(GameConfig.selected_map)
	var sides: Array = GameConfig.MAP_ZONE_SIDES[GameConfig.selected_map][GameConfig.num_players]
	var centre := Vector2(ARENA_WIDTH, ARENA_HEIGHT) / 2.0
	var n: int = _map_vertices.size()

	active_colours.clear()
	_side_for_colour.clear()
	_zone_angles.clear()

	for slot in sides.size():
		var side_idx: int = sides[slot]
		var ct: int = SLOT_COLOURS[slot]
		active_colours.append(ct)
		_side_for_colour[ct] = side_idx

		var a: Vector2 = _map_vertices[side_idx]
		var b: Vector2 = _map_vertices[(side_idx + 1) % n]
		var mid: Vector2 = (a + b) / 2.0
		_zone_angles[ct] = (mid - centre).angle()


func _get_map_vertices(map: String) -> PackedVector2Array:
	## Returns polygon vertices clockwise starting from bottom-left of player's edge (side 0).
	match map:
		"triangle":
			# Equilateral: h=600, s≈693, centred at x=640, y=60–660
			return PackedVector2Array([
				Vector2(294, 660), Vector2(986, 660), Vector2(640, 60),
			])
		"pentagon":
			# Regular pentagon: R=332, center=(640,360), all sides ≈390px.
			# 5 vertices clockwise: BL(0), BR(1), right(2), apex(3), left(4)
			return PackedVector2Array([
				Vector2(445, 629), Vector2(835, 629),   # side 0: bottom (player)
				Vector2(956, 257),                      # side 1: lower-right
				Vector2(640, 28),                       # side 2: upper-right
				Vector2(324, 257),                      # sides 3–4: upper-left, lower-left
			])
		"hexagon":
			# Regular hexagon: R=346, center=(640,360), all sides ≈346px.
			# 6 vertices clockwise: BL(0), BR(1), R(2), TR(3), TL(4), L(5)
			return PackedVector2Array([
				Vector2(467, 660), Vector2(813, 660),   # side 0: bottom (player)
				Vector2(986, 360),                      # side 1: lower-right
				Vector2(813, 60),  Vector2(467, 60),    # sides 2–3: upper-right, top
				Vector2(294, 360),                      # sides 4–5: upper-left, lower-left
			])
		"heptagon":
			# Regular heptagon: R=316, center=(640,360), all sides ≈274px.
			# Clockwise flat-bottom.
			return PackedVector2Array([
				Vector2(503, 645), Vector2(777, 645),   # side 0: bottom (player)
				Vector2(948, 430),                      # side 1: lower-right
				Vector2(887, 163),                      # side 2: upper-right
				Vector2(640, 44),                       # side 3: top-right to apex; side 4: apex to top-left
				Vector2(393, 163),                      # side 5: upper-left
				Vector2(332, 430),                      # side 6: lower-left
			])
		"octagon":
			# Regular octagon: inradius=320, center=(640,360), all edges ≈264px.
			# Clockwise from the bottom-left vertex of side 0 (player's bottom face).
			return PackedVector2Array([
				Vector2(508, 680), Vector2(772, 680),   # side 0: bottom (player)
				Vector2(960, 492), Vector2(960, 228),   # sides 1-2: bottom-right, right
				Vector2(772, 40),  Vector2(508, 40),    # sides 3-4: top-right, top
				Vector2(320, 228), Vector2(320, 492),   # sides 5-6-7: top-left, left, bottom-left
			])
		_:  # "square" and default
			# True square: all sides = 600px, centred at (640,360)
			return PackedVector2Array([
				Vector2(340, 660), Vector2(940, 660),
				Vector2(940, 60),  Vector2(340, 60),
			])


# ── Scores ─────────────────────────────────────────────────────────────────────

func _init_scores() -> void:
	for ct in active_colours:
		scores[ct] = 0


# ── Round lifecycle ────────────────────────────────────────────────────────────

func _start_round() -> void:
	is_game_over = false
	collapsed_colours.clear()
	if timer_display:
		timer_display.round_duration = round_duration
		timer_display.start_timer()
	_spawn_ticket()
	_spawn_ticket()


func _end_round() -> void:
	is_game_over = true
	if timer_display:
		timer_display.stop_timer()

	if GameConfig.has_modifier("speed_ball"):
		scores[player_colour] = scores.get(player_colour, 0) * 2

	var player_score: int = scores.get(player_colour, 0)

	var best_score: int = -1
	var winner_ct: int  = -1
	for ct in scores.keys():
		if ct not in collapsed_colours and scores[ct] > best_score:
			best_score = scores[ct]
			winner_ct  = ct
	var player_won: bool = (winner_ct == player_colour)

	var result: Dictionary = StatsManager.record_game_end(player_score, session_time, player_won)

	if game_over_screen:
		game_over_screen.show_results(
			scores, player_colour, collapsed_colours,
			result.get("points_earned", 0),
			result.get("is_new_high_score", false)
		)


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Wall setup ─────────────────────────────────────────────────────────────────

func _setup_walls() -> void:
	## Create wall segments only for non-zone polygon edges.
	## Active zone sides are left open so balls can exit and be caught by the outside zone.
	var active_sides: Array = []
	for ct in active_colours:
		active_sides.append(_side_for_colour[ct])

	var walls_node := get_node_or_null("Walls")
	if walls_node:
		for child in walls_node.get_children():
			child.queue_free()

	var n: int = _map_vertices.size()
	for i in n:
		if i not in active_sides:
			var a: Vector2 = _map_vertices[i]
			var b: Vector2 = _map_vertices[(i + 1) % n]
			_create_segment_wall(a, b)


func _create_segment_wall(point_a: Vector2, point_b: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = "Wall"

	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce   = 1.0
	physics_mat.friction = 0.0
	wall.physics_material_override = physics_mat

	var dir: Vector2   = point_b - point_a
	var mid: Vector2   = (point_a + point_b) / 2.0
	wall.position      = mid
	wall.rotation      = dir.angle()

	var col_shape := CollisionShape2D.new()
	var rect      := RectangleShape2D.new()
	rect.size = Vector2(dir.length(), WALL_THICKNESS)
	col_shape.shape = rect
	wall.add_child(col_shape)

	$Walls.add_child(wall)


# ── Zone setup ─────────────────────────────────────────────────────────────────

func _setup_colour_zones() -> void:
	## Zones are placed OUTSIDE the polygon. The wall is absent on zone sides so balls
	## that get past the paddle exit the polygon and are caught by the outside zone.
	var n: int = _map_vertices.size()

	for ct in active_colours:
		var side_idx: int = _side_for_colour[ct]
		var a: Vector2 = _map_vertices[side_idx]
		var b: Vector2 = _map_vertices[(side_idx + 1) % n]
		var edge_dir: Vector2 = (b - a).normalized()
		var outward: Vector2  = Vector2(-edge_dir.y, edge_dir.x)  # True edge normal (CCW polygon)
		var edge_mid: Vector2 = (a + b) / 2.0
		var edge_angle: float = edge_dir.angle()
		var edge_len: float   = (b - a).length()

		var zone_pos: Vector2 = edge_mid + outward * (ZONE_DEPTH / 2.0)
		_create_zone(ct, zone_pos, Vector2(edge_len, ZONE_DEPTH), edge_angle)
		# Parallelogram draw shape: corners at the polygon vertices so adjacent
		# zones share corners and form a seamless frame (no gaps or overlaps).
		zones[ct].set_draw_shape(a, b, outward, ZONE_DEPTH)


func _create_zone(ct: int, pos: Vector2, size: Vector2, rotation_rad: float) -> void:
	var zone = zone_scene.instantiate()
	zone.colour_type = ct
	zone.position    = pos
	zone.rotation    = rotation_rad

	var shape := RectangleShape2D.new()
	shape.size = size
	zone.get_node("CollisionShape2D").shape = shape

	zone.score_up.connect(_on_score_up)
	zone.score_down.connect(_on_score_down)
	zone.wrong_catch.connect(_on_wrong_catch)

	add_child(zone)
	zones[ct] = zone


# ── Paddle setup ───────────────────────────────────────────────────────────────

func _setup_paddles() -> void:
	var n: int = _map_vertices.size()
	var half_paddle: float = 50.0  # half of default paddle_length

	# Build set of side indices that have active zones, for corner checks.
	var active_sides: Array = []
	for ct in active_colours:
		active_sides.append(_side_for_colour[ct])

	for ct in active_colours:
		var side_idx: int = _side_for_colour[ct]
		var a: Vector2 = _map_vertices[side_idx]
		var b: Vector2 = _map_vertices[(side_idx + 1) % n]
		var edge_dir: Vector2  = (b - a).normalized()
		var outward: Vector2   = Vector2(-edge_dir.y, edge_dir.x)  # True edge normal
		var edge_mid: Vector2  = (a + b) / 2.0
		var edge_angle: float  = edge_dir.angle()
		var half_zone: float   = (b - a).length() / 2.0

		# At corners shared with a neighbouring active zone, pull the paddle's
		# travel limit back by half_paddle so it stays within its own zone and
		# doesn't physically enter the adjacent zone's territory.
		var prev_side: int = (side_idx - 1 + n) % n
		var next_side: int = (side_idx + 1) % n
		var min_off: float = -(half_zone - half_paddle)
		var max_off: float =   half_zone - half_paddle
		if prev_side in active_sides:
			min_off += PADDLE_THICKNESS
		if next_side in active_sides:
			max_off -= PADDLE_THICKNESS

		# Paddle sits just inside the polygon edge, guarding the open zone side
		var paddle_pos: Vector2 = edge_mid \
			- outward * (PADDLE_THICKNESS / 2.0 + 5.0)

		_create_paddle(ct, paddle_pos, edge_dir, outward, edge_angle,
			min_off, max_off)


func _create_paddle(
		ct: int,
		pos: Vector2,
		move_dir: Vector2,
		outward: Vector2,
		rotation_rad: float,
		min_off: float,
		max_off: float
) -> void:
	var paddle: CharacterBody2D
	if ct == player_colour:
		paddle = player_paddle_scene.instantiate()
	else:
		paddle = ai_paddle_scene.instantiate()

	paddle.colour_type    = ct
	paddle.move_direction = move_dir
	paddle.outward_dir    = outward
	paddle.zone_centre    = pos
	paddle.min_offset     = min_off
	paddle.max_offset     = max_off
	paddle.position       = pos
	paddle.rotation       = rotation_rad

	add_child(paddle)
	paddles[ct] = paddle


# ── Score displays ─────────────────────────────────────────────────────────────

func _setup_score_displays() -> void:
	var n: int = _map_vertices.size()
	for ct in active_colours:
		var side_idx: int = _side_for_colour[ct]
		var a: Vector2 = _map_vertices[side_idx]
		var b: Vector2 = _map_vertices[(side_idx + 1) % n]
		var edge_dir: Vector2 = (b - a).normalized()
		var outward: Vector2  = Vector2(-edge_dir.y, edge_dir.x)  # True edge normal
		var edge_mid: Vector2 = (a + b) / 2.0
		# Place 50px inside the polygon so it's visible behind the paddle
		var display_pos: Vector2 = edge_mid - outward * 50.0
		_create_score_display(ct, display_pos - Vector2(40, 17), Vector2(80, 35))


func _create_score_display(ct: int, pos: Vector2, ctrl_size: Vector2) -> void:
	var display = score_display_scene.instantiate()
	display.set_colour_zone(ct, ct == player_colour)
	display.position = pos
	add_child(display)
	display.size = ctrl_size
	score_displays[ct] = display


# ── Timer / overlays ───────────────────────────────────────────────────────────

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


func _setup_pause_menu() -> void:
	pause_menu = pause_menu_scene.instantiate()
	pause_menu.settings_requested.connect(_on_pause_settings)
	pause_menu.exit_requested.connect(_on_pause_exit)
	add_child(pause_menu)


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_game_over:
		return
	if settings_overlay != null:
		return
	if pause_menu == null:
		return
	if pause_menu.is_open:
		pause_menu.close()
	else:
		pause_menu.open()
	get_viewport().set_input_as_handled()


func _on_pause_settings() -> void:
	settings_overlay = settings_screen_scene.instantiate()
	settings_overlay.return_to_game = true
	settings_overlay.done.connect(_on_settings_done)
	add_child(settings_overlay)


func _on_settings_done() -> void:
	settings_overlay = null
	pause_menu.show_after_settings()


func _on_pause_exit() -> void:
	_quit_game()


# ── Signals ────────────────────────────────────────────────────────────────────

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


# ── Ticket spawning ────────────────────────────────────────────────────────────

func _try_spawn_ticket() -> void:
	if is_game_over:
		return
	if get_tree().get_nodes_in_group("tickets").size() < max_tickets:
		_spawn_ticket()


func _spawn_ticket() -> void:
	var ticket := ticket_scene.instantiate()
	ticket.position = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0)

	var ct: int = active_colours[spawn_colour_index % active_colours.size()]
	spawn_colour_index += 1
	ticket.set_colour(ct)
	ticket.set_random_size()
	add_child(ticket)
	ticket.request_split.connect(_on_ticket_split)

	var vel_angle: float
	if GameConfig.has_modifier("random_directions"):
		vel_angle = randf_range(0.0, TAU)
	else:
		var base_angle: float = _get_zone_direction_angle(ct)
		vel_angle = base_angle + randf_range(-PI / 9.0, PI / 9.0)

	if GameConfig.has_modifier("speed_ball"):
		ticket.speed_multiplier = 2.0
	ticket.linear_velocity = Vector2.from_angle(vel_angle) * ticket.base_speed * ticket.speed_multiplier


func _get_zone_direction_angle(ct: int) -> float:
	## Returns the outward angle from the arena centre toward the target zone.
	var colour_index: int = active_colours.find(ct)
	var target_index: int = colour_index
	if GameConfig.has_modifier("rotated_colours"):
		target_index = (colour_index + 1) % active_colours.size()
	var target_ct: int = active_colours[target_index]
	return _zone_angles.get(target_ct, randf_range(0.0, TAU))


func _on_ticket_split(original: RigidBody2D, count: int) -> void:
	if not is_instance_valid(original):
		return
	call_deferred("_do_ticket_split", original, count)


func _do_ticket_split(original: RigidBody2D, count: int) -> void:
	if not is_instance_valid(original):
		return

	var pos: Vector2 = original.position
	var vel: Vector2 = original.linear_velocity
	var ct: int      = original.colour_type
	var sz: float    = original.size_scale

	original.queue_free()

	for i in count:
		var t: RigidBody2D = ticket_scene.instantiate()
		t.position   = pos
		t.set_colour(ct)
		t.size_scale = max(0.4, sz * 0.75)
		t.can_split  = false
		add_child(t)
		t._apply_size()

		var angle: float = vel.angle() + randf_range(-PI / 5.0, PI / 5.0)
		t.linear_velocity = Vector2.from_angle(angle) * vel.length() * 1.1
		t.request_split.connect(_on_ticket_split)


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_arena_background()
	_draw_polygon_outline()


func _draw_arena_background() -> void:
	## Fill area outside the polygon with the dead-zone colour.
	## Draw a full-screen rect first, then overdraw the polygon interior with the arena colour.
	var bg := Color(0.05, 0.05, 0.08, 1.0)
	var arena_fill := Color(0.08, 0.08, 0.12, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(ARENA_WIDTH, ARENA_HEIGHT)), bg)
	draw_colored_polygon(_map_vertices, arena_fill)


func _draw_polygon_outline() -> void:
	## Draw the arena boundary and highlight active zone sides.
	var n: int = _map_vertices.size()

	# Determine which sides are active (have zones)
	var active_sides: Array = []
	for ct in active_colours:
		active_sides.append(_side_for_colour[ct])

	for i in n:
		var a: Vector2 = _map_vertices[i]
		var b: Vector2 = _map_vertices[(i + 1) % n]

		if i in active_sides:
			# Active zone sides are dim — the paddle/zone sit here
			draw_line(a, b, Color(0.4, 0.4, 0.5, 0.5), 2.0)
		else:
			# Solid wall sides
			draw_line(a, b, Color(0.7, 0.7, 0.8, 0.9), 3.0)
