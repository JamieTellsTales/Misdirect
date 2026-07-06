extends Node2D
## Arena — dynamic polygon arena built from GameConfig.selected_map and num_players.
## Polygon vertices are defined clockwise starting from the bottom-left of the player's
## side (side 0). Zone / paddle positions are computed from the polygon geometry at runtime.

const ColourData = preload("res://scripts/resources/colour_data.gd")

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

@export var ball_spawn_interval: float = 2.5
@export var max_balls: int = 10
@export var round_duration: float = 120.0

var ball_scene:        PackedScene = preload("res://scenes/components/ball.tscn")
var zone_scene:          PackedScene = preload("res://scenes/components/colour_zone.tscn")
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

const BLACK_HOLE_PULL_RANGE: float = 160.0
const BLACK_HOLE_RADIUS:     float = 22.0   # Visual radius
const BLACK_HOLE_CORE_RADIUS: float = 11.0  # Deletion core (half of visual)
const BLACK_HOLE_FORCE:      float = 700.0
const BLACK_HOLE_ACTIVE_MIN: float = 6.0    # Seconds the hole stays visible
const BLACK_HOLE_ACTIVE_MAX: float = 10.0
const BLACK_HOLE_COOLDOWN_MIN: float = 4.0  # Seconds between appearances
const BLACK_HOLE_COOLDOWN_MAX: float = 9.0
const PILLAR_RADIUS:         float = 20.0
const PILLAR_COUNT:          int   = 6
const PILLAR_RING_RADIUS:    float = 220.0   # Distance of pillars from centre

var spawn_timer:       float = 0.0
var spawn_colour_index: int  = 0
var session_time:      float = 0.0
var timer_display:     Control = null
var game_over_screen:  Control = null
var pause_menu:        Node2D  = null
var settings_overlay:  Node2D  = null
var is_game_over:      bool    = false
var _overtime:         bool    = false   # Extra Time: timer expired, waiting for balls to clear
var _pillars:          Array   = []      # Pillar StaticBody2D nodes
var _bh_active:        bool    = false   # Is the roaming black hole currently visible?
var _bh_position:      Vector2 = Vector2.ZERO
var _bh_timer:         float   = 0.0    # Counts down: active duration or cooldown
var _bh_fade:          float   = 0.0    # 0→1 appear, 1→0 vanish (over 0.4s each)
var _gw_active:        bool    = false   # Gravity Well active
var _gw_position:      Vector2 = Vector2.ZERO
var _gw_timer:         float   = 0.0
var _gw_fade:          float   = 0.0
var _design_offset: Vector2 = Vector2.ZERO
var _arena_centre:  Vector2 = Vector2.ZERO   # Canvas-space centre of the polygon bounding box
var _arena_scale:   float   = 1.0            # Uniform scale applied to the polygon in portrait mode

var _lives:              Dictionary = {}   # colour_type -> lives remaining
var _zone_outward_dirs:  Dictionary = {}   # colour_type -> outward unit vector (for lives display)
const STARTING_LIVES:    int        = 3


func _ready() -> void:
	AudioManager.play_game_music()
	_build_active_colours()
	_init_scores()
	_setup_walls()
	_setup_colour_zones()
	_setup_paddles()
	_setup_score_displays()
	_setup_timer_display()
	_setup_game_over_screen()
	_setup_pause_menu()
	_setup_pillars()
	_start_round()


func _process(delta: float) -> void:
	if is_game_over:
		return

	session_time += delta

	# Extra Time: timer expired — end once the arena is empty
	if _overtime:
		if get_tree().get_nodes_in_group("balls").size() == 0:
			_end_round()
		if GameConfig.has_modifier("black_hole"):
			_tick_black_hole(delta)
			queue_redraw()
		if GameConfig.has_modifier("gravity_wells"):
			_tick_gravity_well(delta)
			queue_redraw()
		return

	# Spawn interval — stack modifiers multiplicatively
	var effective_interval: float = ball_spawn_interval
	if GameConfig.has_modifier("chaos_ball"):
		effective_interval /= 2.0
	# Final Countdown: last 10 seconds of a normal timed round double spawn rate
	if GameConfig.has_modifier("final_countdown") and GameConfig.game_mode == "normal":
		if round_duration - session_time <= 10.0:
			effective_interval /= 2.0
	# Endless difficulty ramp: spawn interval shrinks 2% per 10 s, floored at
	# 40% so long runs stay survivable but demand real skill.
	if GameConfig.game_mode == "endless":
		effective_interval *= maxf(0.4, 1.0 - session_time / 10.0 * 0.02)

	spawn_timer += delta
	if spawn_timer >= effective_interval:
		spawn_timer = 0.0
		_try_spawn_ball()

	# Black Hole and Gravity Wells: roaming hazards
	if GameConfig.has_modifier("black_hole"):
		_tick_black_hole(delta)
		queue_redraw()
	if GameConfig.has_modifier("gravity_wells"):
		_tick_gravity_well(delta)
		queue_redraw()


# ── Active colours ─────────────────────────────────────────────────────────────

func _build_active_colours() -> void:
	## Build active_colours, _side_for_colour, _zone_angles from GameConfig.
	_map_vertices = _get_map_vertices(GameConfig.selected_map)
	var vp := get_viewport_rect().size

	const PORTRAIT_MARGIN: float = 0.0

	if vp.y > vp.x:
		# ── Portrait mode ──────────────────────────────────────────────────────
		# Scale the arena polygon uniformly so its width fills the canvas, then
		# pin the top edge near the top of the screen.  This makes the arena
		# feel full-width on portrait phones/Steam Deck portrait orientations
		# instead of sitting as a tiny 600-unit box in a 1280-unit-wide canvas.

		# Bounding box of the raw (design-space) polygon
		var min_x: float = INF;  var max_x: float = -INF
		var min_y: float = INF;  var max_y: float = -INF
		for v in _map_vertices:
			min_x = minf(min_x, v.x); max_x = maxf(max_x, v.x)
			min_y = minf(min_y, v.y); max_y = maxf(max_y, v.y)
		var poly_w: float  = max_x - min_x
		var poly_h: float  = max_y - min_y
		var poly_cx: float = (min_x + max_x) / 2.0
		var poly_cy: float = (min_y + max_y) / 2.0

		# Uniform scale: polygon width → canvas width (minus margins)
		var scale: float = (vp.x - PORTRAIT_MARGIN * 2.0) / poly_w
		_arena_scale = scale

		for i in _map_vertices.size():
			_map_vertices[i] = Vector2(
				poly_cx + (_map_vertices[i].x - poly_cx) * scale,
				poly_cy + (_map_vertices[i].y - poly_cy) * scale
			)

		# After scaling the polygon's min corner is at:
		#   (poly_cx - poly_w*scale/2,  poly_cy - poly_h*scale/2)
		# Shift so that corner lands at (PORTRAIT_MARGIN, PORTRAIT_MARGIN).
		_design_offset = Vector2(
			PORTRAIT_MARGIN - (poly_cx - poly_w * scale / 2.0),
			PORTRAIT_MARGIN - (poly_cy - poly_h * scale / 2.0)
		)
	else:
		# ── Landscape mode ─────────────────────────────────────────────────────
		_arena_scale = 1.0
		_design_offset = Vector2(
			maxf(0.0, (vp.x - ARENA_WIDTH) / 2.0),
			maxf(0.0, (vp.y - ARENA_HEIGHT) / 2.0)
		)

	for i in _map_vertices.size():
		_map_vertices[i] += _design_offset

	# Cache the polygon bounding-box centre — used for ball spawning, pillar
	# placement, the pause overlay and all angle calculations.
	var bx_min: float = INF;  var bx_max: float = -INF
	var by_min: float = INF;  var by_max: float = -INF
	for v in _map_vertices:
		bx_min = minf(bx_min, v.x); bx_max = maxf(bx_max, v.x)
		by_min = minf(by_min, v.y); by_max = maxf(by_max, v.y)
	_arena_centre = Vector2((bx_min + bx_max) / 2.0, (by_min + by_max) / 2.0)

	var sides: Array = GameConfig.MAP_ZONE_SIDES[GameConfig.selected_map][GameConfig.num_players]
	var centre := _arena_centre
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


func get_design_offset() -> Vector2:
	return _design_offset


func get_design_centre() -> Vector2:
	return _arena_centre


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
	_lives.clear()
	if GameConfig.game_mode == "endless":
		_lives[player_colour] = STARTING_LIVES
	elif GameConfig.game_mode == "elimination":
		for ct in active_colours:
			_lives[ct] = STARTING_LIVES
	if timer_display:
		if GameConfig.game_mode == "normal":
			timer_display.round_duration = round_duration
			timer_display.start_timer()
		else:
			timer_display.visible = false
	_spawn_ball()
	_spawn_ball()


func _end_round(player_eliminated: bool = false) -> void:
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

	# Count how many share the top score — a draw is not recorded as a win.
	var top_count: int = 0
	for ct in scores.keys():
		if ct not in collapsed_colours and scores[ct] == best_score:
			top_count += 1
	var is_draw: bool    = top_count > 1
	var player_won: bool = (not player_eliminated and not is_draw and winner_ct == player_colour)

	var result: Dictionary = StatsManager.record_game_end(player_score, session_time, player_won, is_draw)

	if game_over_screen:
		game_over_screen.show_results(
			scores, player_colour, collapsed_colours,
			result.get("tokens_earned", 0),
			result.get("is_new_high_score", false),
			result.get("xp_earned", 0),
			result.get("level_before", 0),
			result.get("level_after", 0),
			player_eliminated
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
	rect.size = Vector2(dir.length(), WALL_THICKNESS * _arena_scale)
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

		_zone_outward_dirs[ct] = outward

		var zone_depth: float  = ZONE_DEPTH * _arena_scale
		var zone_pos: Vector2 = edge_mid + outward * (zone_depth / 2.0)
		_create_zone(ct, zone_pos, Vector2(edge_len, zone_depth), edge_angle)
		# Parallelogram draw shape: corners at the polygon vertices so adjacent
		# zones share corners and form a seamless frame (no gaps or overlaps).
		zones[ct].set_draw_shape(a, b, outward, zone_depth)


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
	var half_paddle: float = 50.0 * _arena_scale

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
			- outward * ((PADDLE_THICKNESS / 2.0 + 5.0) * _arena_scale)

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
		paddle.use_deflector = GameConfig.has_power_up_in_slot("deflector")
	else:
		paddle = ai_paddle_scene.instantiate()

	paddle.colour_type     = ct
	paddle.move_direction  = move_dir
	paddle.outward_dir     = outward
	paddle.zone_centre     = pos
	paddle.min_offset      = min_off
	paddle.max_offset      = max_off
	paddle.position        = pos
	paddle.rotation        = rotation_rad
	paddle.paddle_length    = 100.0 * _arena_scale
	paddle.paddle_thickness = PADDLE_THICKNESS * _arena_scale
	paddle.arena_scale      = _arena_scale

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
		var display_pos: Vector2 = edge_mid - outward * 50.0 * _arena_scale
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
	timer_display.position = get_design_centre() - Vector2(75, 20)
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
	# Resume where the player left off — no scene reload, so the round keeps
	# its state. Resolution changes apply live; the arena keeps its current
	# geometry (same-aspect resolution changes don't move the canvas).
	if pause_menu and pause_menu.is_open:
		pause_menu.show_after_settings()
	else:
		get_tree().paused = false


func _on_pause_exit() -> void:
	_quit_game()


# ── Signals ────────────────────────────────────────────────────────────────────

func _on_timer_expired() -> void:
	if GameConfig.has_modifier("extra_time"):
		_overtime = true
		if timer_display:
			timer_display.enter_overtime()
	else:
		_end_round()


func _on_score_up(ct: int, points: int) -> void:
	if scores.has(ct):
		var old_score: int = scores[ct]
		scores[ct] += points
		if score_displays.has(ct):
			score_displays[ct].set_score(scores[ct])
		# Endless: gain 1 life per 100-point milestone crossed
		if GameConfig.game_mode == "endless" and ct == player_colour:
			var gained: int = scores[ct] / 100 - old_score / 100
			if gained > 0:
				_lives[ct] = _lives.get(ct, 0) + gained


func _on_score_down(ct: int, points: int) -> void:
	# Endless: player wrong catches cost a life, not score
	if GameConfig.game_mode == "endless" and ct == player_colour:
		return
	if scores.has(ct):
		scores[ct] = max(0, scores[ct] - points)
		if score_displays.has(ct):
			score_displays[ct].set_score(scores[ct])


func _on_wrong_catch(_ball: Node2D, ct: int) -> void:
	match GameConfig.game_mode:
		"endless":
			if ct == player_colour:
				_lose_life(ct)
		"elimination":
			_lose_life(ct)


# ── Ball spawning ──────────────────────────────────────────────────────────────

func _try_spawn_ball() -> void:
	if is_game_over:
		return
	if get_tree().get_nodes_in_group("balls").size() < max_balls:
		_spawn_ball()


func _spawn_ball() -> void:
	var ball := ball_scene.instantiate()
	ball.position   = get_design_centre()
	ball.arena_scale = _arena_scale

	var ct: int
	if GameConfig.has_modifier("load_balanced"):
		ct = _get_lowest_score_colour()
	else:
		var available: Array = []
		for c in active_colours:
			if c not in collapsed_colours:
				available.append(c)
		if available.is_empty():
			ball.queue_free()
			return
		ct = available[spawn_colour_index % available.size()]
		spawn_colour_index += 1
	ball.set_colour(ct)
	ball.set_random_size()
	add_child(ball)
	ball.request_split.connect(_on_ball_split)

	var vel_angle: float
	if GameConfig.has_modifier("random_directions"):
		vel_angle = randf_range(0.0, TAU)
	else:
		var base_angle: float = _get_zone_direction_angle(ct)
		vel_angle = base_angle + randf_range(-PI / 9.0, PI / 9.0)

	if GameConfig.has_modifier("speed_ball"):
		ball.speed_multiplier = 2.0
	ball.linear_velocity = Vector2.from_angle(vel_angle) * ball.base_speed * ball.speed_multiplier


func _get_zone_direction_angle(ct: int) -> float:
	## Returns the outward angle from the arena centre toward the target zone.
	var colour_index: int = active_colours.find(ct)
	var target_index: int = colour_index
	if GameConfig.has_modifier("rotated_colours"):
		target_index = (colour_index - 1 + active_colours.size()) % active_colours.size()
	var target_ct: int = active_colours[target_index]
	return _zone_angles.get(target_ct, randf_range(0.0, TAU))


func _on_ball_split(original: RigidBody2D, count: int, spread_angle: float) -> void:
	if not is_instance_valid(original):
		return
	call_deferred("_do_ball_split", original, count, spread_angle)


func _do_ball_split(original: RigidBody2D, count: int, spread_angle: float) -> void:
	if not is_instance_valid(original):
		return

	var pos: Vector2 = original.position
	var vel: Vector2 = original.linear_velocity
	var ct: int      = original.colour_type
	var sz: float    = original.size_scale

	original.queue_free()

	for i in count:
		var t: RigidBody2D = ball_scene.instantiate()
		t.position    = pos
		t.arena_scale = _arena_scale
		t.set_colour(ct)
		t.size_scale  = max(0.4, sz * 0.75)
		t.can_split   = false
		add_child(t)
		t._apply_size()

		var angle: float = vel.angle() + randf_range(-spread_angle, spread_angle)
		t.linear_velocity = Vector2.from_angle(angle) * vel.length() * 1.1
		t.request_split.connect(_on_ball_split)


# ── Modifier helpers ───────────────────────────────────────────────────────────

func _get_lowest_score_colour() -> int:
	## Returns the active colour with the lowest score (random among ties).
	var min_score: int = 2147483647
	for ct in active_colours:
		if ct not in collapsed_colours:
			min_score = mini(min_score, scores.get(ct, 0))
	var candidates: Array = []
	for ct in active_colours:
		if ct not in collapsed_colours and scores.get(ct, 0) == min_score:
			candidates.append(ct)
	if candidates.is_empty():
		return active_colours[0]
	return candidates[randi() % candidates.size()]


func _tick_black_hole(delta: float) -> void:
	## Manage the roaming black hole lifecycle and apply physics when active.
	const FADE_TIME: float = 0.4

	if _bh_active:
		_bh_timer -= delta
		_bh_fade   = minf(_bh_fade + delta / FADE_TIME, 1.0)

		# Pull and destroy balls while visible
		var bh_range: float = BLACK_HOLE_PULL_RANGE * _arena_scale
		var bh_core:  float = BLACK_HOLE_CORE_RADIUS * _arena_scale
		var range_sq: float = bh_range * bh_range
		var core_sq: float  = bh_core * bh_core
		for ball in get_tree().get_nodes_in_group("balls"):
			var offset: Vector2 = _bh_position - ball.global_position
			var dist_sq: float  = offset.length_squared()
			if dist_sq <= core_sq:
				ball.queue_free()
			elif dist_sq <= range_sq:
				var dist: float   = sqrt(dist_sq)
				var pull: float   = 1.0 - (dist / bh_range)
				ball.apply_central_force(offset.normalized() * BLACK_HOLE_FORCE * _arena_scale * pull * _bh_fade)

		if _bh_timer <= 0.0:
			# Begin fade-out then switch to cooldown
			_bh_active = false
			_bh_timer  = randf_range(BLACK_HOLE_COOLDOWN_MIN, BLACK_HOLE_COOLDOWN_MAX)
	else:
		# Cooldown — fade out visually
		_bh_fade  = maxf(_bh_fade - delta / FADE_TIME, 0.0)
		_bh_timer -= delta
		if _bh_timer <= 0.0:
			_bh_active   = true
			_bh_timer    = randf_range(BLACK_HOLE_ACTIVE_MIN, BLACK_HOLE_ACTIVE_MAX)
			_bh_position = _random_interior_point()

func _tick_gravity_well(delta: float) -> void:
	## Like the black hole but balls are deflected, not destroyed.
	## Uses slightly weaker pull and shorter active windows so it plays differently.
	const FADE_TIME:     float = 0.4
	const PULL_RANGE:    float = 140.0
	const PULL_FORCE:    float = 450.0
	const ACTIVE_MIN:    float = 5.0
	const ACTIVE_MAX:    float = 9.0
	const COOLDOWN_MIN:  float = 5.0
	const COOLDOWN_MAX:  float = 11.0

	if _gw_active:
		_gw_timer -= delta
		_gw_fade   = minf(_gw_fade + delta / FADE_TIME, 1.0)

		var gw_range: float = PULL_RANGE * _arena_scale
		var range_sq: float = gw_range * gw_range
		for ball in get_tree().get_nodes_in_group("balls"):
			var offset: Vector2 = _gw_position - ball.global_position
			var dist_sq: float  = offset.length_squared()
			if dist_sq > 0.0 and dist_sq <= range_sq:
				var dist: float  = sqrt(dist_sq)
				var pull: float  = 1.0 - (dist / gw_range)
				ball.apply_central_force(offset.normalized() * PULL_FORCE * _arena_scale * pull * _gw_fade)

		if _gw_timer <= 0.0:
			_gw_active = false
			_gw_timer  = randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
	else:
		_gw_fade  = maxf(_gw_fade - delta / FADE_TIME, 0.0)
		_gw_timer -= delta
		if _gw_timer <= 0.0:
			_gw_active   = true
			_gw_timer    = randf_range(ACTIVE_MIN, ACTIVE_MAX)
			_gw_position = _random_interior_point()


func _random_interior_point() -> Vector2:
	## Returns a random point well inside the polygon (using bounding box rejection).
	var margin: float = 120.0 * _arena_scale
	var min_x: float = INF;  var max_x: float = -INF
	var min_y: float = INF;  var max_y: float = -INF
	for v in _map_vertices:
		min_x = minf(min_x, v.x); max_x = maxf(max_x, v.x)
		min_y = minf(min_y, v.y); max_y = maxf(max_y, v.y)
	min_x += margin; max_x -= margin; min_y += margin; max_y -= margin
	for _attempt in 30:
		var p := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if Geometry2D.is_point_in_polygon(p, _map_vertices):
			return p
	# Fallback: design centre
	return get_design_centre()


func _setup_pillars() -> void:
	## Spawn evenly-spaced bouncy pillars around the arena centre.
	if not GameConfig.has_modifier("pillars"):
		return
	var centre: Vector2 = get_design_centre()
	for i in PILLAR_COUNT:
		var angle: float = i * TAU / PILLAR_COUNT
		var pos: Vector2 = centre + Vector2.from_angle(angle) * PILLAR_RING_RADIUS * _arena_scale
		_create_pillar(pos)


func _create_pillar(pos: Vector2) -> void:
	var pillar := StaticBody2D.new()
	pillar.position = pos

	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce   = 1.0
	physics_mat.friction = 0.0
	pillar.physics_material_override = physics_mat

	var col_shape := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius = PILLAR_RADIUS * _arena_scale
	col_shape.shape = circle
	pillar.add_child(col_shape)

	add_child(pillar)
	_pillars.append(pillar)


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_arena_background()
	_draw_polygon_outline()
	if GameConfig.has_modifier("pillars"):
		_draw_pillars()
	if GameConfig.has_modifier("black_hole"):
		_draw_black_hole()
	if GameConfig.has_modifier("gravity_wells"):
		_draw_gravity_well()
	if not _lives.is_empty():
		_draw_lives()


func _draw_arena_background() -> void:
	## Fill area outside the polygon with the dead-zone colour.
	## Draw a full-screen rect first, then overdraw the polygon interior with the arena colour.
	var bg := Color(0.05, 0.05, 0.08, 1.0)
	var arena_fill := Color(0.08, 0.08, 0.12, 1.0)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), bg)
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
			draw_line(a, b, Color(0.4, 0.4, 0.5, 0.5), 2.0, true)
		else:
			# Solid wall sides
			draw_line(a, b, Color(0.7, 0.7, 0.8, 0.9), 3.0, true)


func _draw_pillars() -> void:
	var pr: float = PILLAR_RADIUS * _arena_scale
	for pillar in _pillars:
		var pos: Vector2 = pillar.position
		draw_circle(pos, pr, Color(0.22, 0.22, 0.32, 1.0), true, -1.0, true)
		draw_arc(pos, pr, 0, TAU, 48, Color(0.55, 0.55, 0.72, 1.0), 2.5, true)
		# Inner highlight
		draw_arc(pos, pr * 0.55, 0, TAU, 32, Color(0.65, 0.65, 0.82, 0.4), 1.5, true)


func _draw_black_hole() -> void:
	if _bh_fade <= 0.0:
		return
	var pos: Vector2  = _bh_position
	var f: float      = _bh_fade          # 0–1 fade multiplier
	var t: float      = Time.get_ticks_msec() / 1000.0
	var bhr: float    = BLACK_HOLE_RADIUS * _arena_scale
	var bhpr: float   = BLACK_HOLE_PULL_RANGE * _arena_scale

	# Faint pull-range glow rings
	for i in 3:
		var ring_r: float     = bhpr * (0.35 + i * 0.22)
		var ring_alpha: float = (0.07 - i * 0.018) * f
		draw_circle(pos, ring_r, Color(0.45, 0.1, 0.8, ring_alpha), true, -1.0, true)

	# Spinning accretion arc wisps
	for i in 4:
		var a0: float = i * TAU / 4.0 + t * 1.8
		draw_arc(pos, bhpr * 0.52, a0, a0 + 0.5, 12, Color(0.55, 0.2, 0.9, 0.45 * f), 2.0, true)
		draw_arc(pos, bhpr * 0.32, a0 + 0.35, a0 + 0.85, 10, Color(0.6, 0.25, 0.95, 0.3 * f), 1.5, true)

	# Core
	draw_circle(pos, bhr * f, Color(0.03, 0.0, 0.08, 1.0), true, -1.0, true)
	draw_arc(pos, bhr * f, 0, TAU, 64, Color(0.65, 0.25, 1.0, 0.95 * f), 3.0, true)
	draw_circle(pos, bhr * 0.45 * f, Color(0.0, 0.0, 0.0, 1.0), true, -1.0, true)


func _draw_gravity_well() -> void:
	if _gw_fade <= 0.0:
		return
	const PULL_RANGE: float = 140.0
	const RADIUS:     float = 18.0
	var pos: Vector2  = _gw_position
	var f: float      = _gw_fade
	var t: float      = Time.get_ticks_msec() / 1000.0
	var gwr: float    = RADIUS * _arena_scale
	var gwpr: float   = PULL_RANGE * _arena_scale

	# Pull-range glow rings (teal/cyan palette to distinguish from black hole)
	for i in 3:
		var ring_r: float     = gwpr * (0.3 + i * 0.22)
		var ring_alpha: float = (0.07 - i * 0.018) * f
		draw_circle(pos, ring_r, Color(0.1, 0.55, 0.7, ring_alpha), true, -1.0, true)

	# Spinning arc wisps (counter-clockwise to feel distinct)
	for i in 4:
		var a0: float = i * TAU / 4.0 - t * 1.5
		draw_arc(pos, gwpr * 0.5, a0, a0 + 0.5, 12, Color(0.2, 0.75, 0.9, 0.4 * f), 2.0, true)
		draw_arc(pos, gwpr * 0.3, a0 + 0.3, a0 + 0.8, 10, Color(0.25, 0.8, 0.95, 0.25 * f), 1.5, true)

	# Core — open ring (no solid fill) to signal balls pass through safely
	draw_circle(pos, gwr * f, Color(0.05, 0.18, 0.25, 0.9), true, -1.0, true)
	draw_arc(pos, gwr * f, 0, TAU, 64, Color(0.3, 0.9, 1.0, 0.95 * f), 3.0, true)
	# Inner ring gap — visually signals "no destruction zone"
	draw_arc(pos, gwr * 0.5 * f, 0, TAU, 32, Color(0.4, 1.0, 1.0, 0.5 * f), 2.0, true)


func _draw_lives() -> void:
	## Draw life dots near each zone's score display.
	## In endless mode only the player zone is shown.
	for ct in _lives.keys():
		if ct in collapsed_colours:
			continue
		if not score_displays.has(ct):
			continue
		var lives: int      = _lives[ct]
		var col: Color      = ColourData.get_color(ct)
		var outward: Vector2 = _zone_outward_dirs.get(ct, Vector2(0.0, 1.0))
		var along: Vector2   = Vector2(-outward.y, outward.x)  # perpendicular, along edge

		# Centre of score display, then step outward toward the edge
		var sd_centre: Vector2 = score_displays[ct].position + Vector2(40.0, 17.0)
		var base_pos: Vector2  = sd_centre + outward * 28.0 * _arena_scale

		var dot_r: float       = 5.0
		var dot_spacing: float = 14.0
		var half_span: float   = (STARTING_LIVES - 1) * dot_spacing / 2.0

		for i in STARTING_LIVES:
			var dot_pos: Vector2 = base_pos + along * (i * dot_spacing - half_span)
			var filled: bool = i < lives
			var fill_col: Color   = Color(col.r, col.g, col.b, 0.9) if filled else Color(col.r, col.g, col.b, 0.18)
			var border_col: Color = Color(col.r, col.g, col.b, 1.0) if filled else Color(col.r, col.g, col.b, 0.4)
			draw_circle(dot_pos, dot_r, fill_col, true, -1.0, true)
			draw_arc(dot_pos, dot_r, 0, TAU, 24, border_col, 1.0, true)


func _lose_life(ct: int) -> void:
	## Deduct one life from ct. Triggers zone collapse or game over at zero.
	if ct in collapsed_colours:
		return
	_lives[ct] = max(0, _lives.get(ct, 0) - 1)
	queue_redraw()
	# Elimination: an AI paddle on its last life plays sharper.
	if _lives[ct] == 1 and GameConfig.game_mode == "elimination":
		var p = paddles.get(ct)
		if p and p.has_method("enter_desperation"):
			p.enter_desperation()
	if _lives[ct] == 0:
		if GameConfig.game_mode == "elimination":
			_collapse_zone(ct)
		else:  # endless — only player reaches this
			_end_round(true)


func _collapse_zone(ct: int) -> void:
	## Seal a collapsed zone: remove its paddle and zone, wall off the edge, end round if needed.
	if ct in collapsed_colours:
		return
	collapsed_colours.append(ct)

	# Remove the zone (balls can no longer enter it)
	if zones.has(ct):
		zones[ct].queue_free()
		zones.erase(ct)

	# Remove the paddle
	if paddles.has(ct):
		paddles[ct].queue_free()
		paddles.erase(ct)

	# Seal the previously open edge with a wall
	var n: int       = _map_vertices.size()
	var side_idx: int = _side_for_colour.get(ct, -1)
	if side_idx >= 0:
		var a: Vector2 = _map_vertices[side_idx]
		var b: Vector2 = _map_vertices[(side_idx + 1) % n]
		_create_segment_wall(a, b)

	# Remove score display
	if score_displays.has(ct):
		score_displays[ct].queue_free()
		score_displays.erase(ct)

	queue_redraw()

	# End round if player was eliminated, or only one active zone remains
	if ct == player_colour:
		_end_round(true)
	else:
		var remaining: int = 0
		for c in active_colours:
			if c not in collapsed_colours:
				remaining += 1
		if remaining <= 1:
			_end_round()
