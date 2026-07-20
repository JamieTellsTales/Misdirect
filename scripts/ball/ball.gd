extends RigidBody2D
class_name Ball
## Ball - A bouncing ball in the arena

const ColourData = preload("res://scripts/resources/colour_data.gd")

## spread_angle: half-angle (radians) of velocity divergence between split children.
## Use a small value (e.g. 0.05) for near-identical clones, PI/5 for wide splits.
signal request_split(ball: RigidBody2D, count: int, spread_angle: float)

@export var ball_color: Color = Color.DODGER_BLUE
@export var base_speed: float = 300.0

# Colour this ball belongs to
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

## Set by arena.gd before add_child() so sizes and speeds scale with the arena.
var arena_scale: float = 1.0

# Split control — split children cannot re-split
var can_split: bool = true

# Cooldown to prevent multiple split signals from one collision
var split_cooldown: float = 0.0

# Erratic Balls / Surge Balls modifier timers (staggered per ball)
var _erratic_timer: float = 0.0
var _surge_timer:   float = 0.0

# Motion trail — recent global positions, newest last (readability aid)
const TRAIL_LEN: int = 9
var _trail: PackedVector2Array = PackedVector2Array()

# Railgun launch — a temporary speed-cap boost that decays back to normal so
# the clamp doesn't kill the launch on the next physics frame.
const RAILGUN_MULT: float = 1.8
const LAUNCH_DECAY: float = 1.2   # boost units lost per second
var _launch_boost: float = 0.0    # extra multiplier above 1.0 on the speed cap

# Deferred split — set when the ball hits the player's paddle with a split
# power-up. The ball rebounds first, then bursts a moment later out in the
# arena (looks natural, and can't drop children into the player's zone).
var _split_pending: bool = false
var _split_delay: float  = 0.0
var _split_count: int    = 0
var _split_spread: float = 0.0
const SPLIT_REBOUND_DELAY: float = 0.12


func _ready() -> void:
	add_to_group("balls")
	_apply_size()
	queue_redraw()

	_erratic_timer = randf_range(0.6, 1.6)
	_surge_timer   = randf_range(0.8, 2.0)

	body_entered.connect(_on_body_entered)
	contact_monitor = true
	max_contacts_reported = 4
	# Continuous collision so fast / small / launched balls can't tunnel through
	# the thin paddle in one physics step (which skipped the bounce and split).
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY


func set_random_size() -> void:
	size_scale = randf_range(0.5, 2.0)
	_apply_size()


func _apply_size() -> void:
	radius = 16.0 * size_scale * arena_scale

	var speed_factor: float = 1.0 / size_scale
	max_speed  = 500.0 * speed_factor * arena_scale
	min_speed  = 150.0 * speed_factor * arena_scale
	base_speed = 300.0 * speed_factor * arena_scale

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
	if _launch_boost > 0.0:
		_launch_boost = maxf(0.0, _launch_boost - LAUNCH_DECAY * delta)
	_clamp_speed()
	if split_cooldown > 0:
		split_cooldown -= delta

	# Fire a pending split once the ball has rebounded and cleared the paddle.
	if _split_pending:
		_split_delay -= delta
		if _split_delay <= 0.0:
			_split_pending = false
			request_split.emit(self, _split_count, _split_spread)
			return

	# Record motion trail (global positions; drawn via to_local so rotation-safe)
	_trail.append(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.remove_at(0)
	queue_redraw()

	# Erratic Balls: random direction jinks mid-flight
	if GameConfig.has_modifier("erratic_balls"):
		_erratic_timer -= delta
		if _erratic_timer <= 0.0:
			_erratic_timer = randf_range(0.6, 1.6)
			linear_velocity = linear_velocity.rotated(randf_range(-PI / 4.0, PI / 4.0))

	# Surge Balls: random speed changes within the ball's size-scaled band
	if GameConfig.has_modifier("surge_balls"):
		_surge_timer -= delta
		if _surge_timer <= 0.0 and linear_velocity.length_squared() > 0.0:
			_surge_timer = randf_range(0.8, 2.0)
			var new_speed: float = randf_range(min_speed, max_speed) * speed_multiplier
			linear_velocity = linear_velocity.normalized() * new_speed


func _clamp_speed() -> void:
	var effective_max: float = max_speed * speed_multiplier * (1.0 + _launch_boost)
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

		if body.is_in_group("player_paddle"):
			# ── Railgun: blast the ball out at high speed ─────────────────
			# Deferred so it fires AFTER the physics engine resolves the bounce
			# (velocity then points away from the paddle, not into the zone) and
			# isn't overwritten by the collision solver.
			if GameConfig.has_power_up_in_slot("railgun"):
				call_deferred("_fire_railgun")

			# ── Split power-ups ───────────────────────────────────────────
			# Arm a split; it fires shortly after, once the ball has rebounded
			# out into the arena (see _physics_process). First matching slot wins.
			if can_split and split_cooldown <= 0.0 and not _split_pending:
				if GameConfig.has_power_up_in_slot("multi_shot"):
					var count: int = randi_range(2, 5)
					# Double Rebound synergy: doubles Multi Shot's output
					if GameConfig.has_power_up_in_slot("double_rebound"):
						count *= 2
					_arm_split(count, PI / 5.0)
				elif GameConfig.has_power_up_in_slot("clone"):
					_arm_split(2, 0.05)
				elif GameConfig.has_power_up_in_slot("double_rebound"):
					_arm_split(2, PI / 5.0)


func _fire_railgun() -> void:
	## Launch the ball at high speed along its post-bounce direction. The launch
	## boost raises the speed cap and decays, so _clamp_speed lets it ride out.
	var dir: Vector2 = linear_velocity.normalized()
	if dir == Vector2.ZERO:
		return
	_launch_boost = RAILGUN_MULT - 1.0
	linear_velocity = dir * max_speed * speed_multiplier * RAILGUN_MULT


func _arm_split(count: int, spread: float) -> void:
	## Queue a split to fire once the ball has rebounded off the paddle.
	_split_pending = true
	_split_delay   = SPLIT_REBOUND_DELAY
	_split_count   = count
	_split_spread  = spread
	split_cooldown = 0.5


func _draw() -> void:
	_draw_trail()

	draw_circle(Vector2.ZERO, radius, ball_color, true, -1.0, true)

	var border_width: float = 2.0 + size_scale
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, ball_color.lightened(0.3), border_width, true)

	# Accessibility: a distinct symbol per colour, in a contrasting tone.
	if SettingsManager.ball_symbols:
		var sym_col: Color = Color(0.0, 0.0, 0.0, 0.85) if ball_color.get_luminance() > 0.5 else Color(1.0, 1.0, 1.0, 0.9)
		ColourData.draw_symbol(self, colour_type, Vector2.ZERO, radius * 0.6, sym_col)


func _draw_trail() -> void:
	## Fading tail behind the ball — older samples are smaller and more transparent.
	## Points are stored in global space; to_local keeps them world-aligned even
	## if the body has rotated.
	if SettingsManager.reduced_motion:
		return
	var n: int = _trail.size()
	if n < 2:
		return
	for i in range(n - 1):
		var frac: float = float(i) / float(n - 1)   # 0 (oldest) → 1 (newest)
		var seg_r: float = radius * (0.25 + 0.6 * frac)
		var alpha: float = 0.28 * frac
		draw_circle(to_local(_trail[i]), seg_r, Color(ball_color.r, ball_color.g, ball_color.b, alpha), true, -1.0, true)

	if has_blame_stamp:
		var stamp_color := Color.BLACK
		stamp_color.a = 0.7
		var stamp_size: float = radius * 0.5
		draw_line(Vector2(-stamp_size, -stamp_size), Vector2(stamp_size, stamp_size), stamp_color, 3.0, true)
		draw_line(Vector2(stamp_size, -stamp_size), Vector2(-stamp_size, stamp_size), stamp_color, 3.0, true)


func set_ball_color(color: Color) -> void:
	ball_color = color
	queue_redraw()


func set_colour(ct: int) -> void:
	colour_type = ct
	ball_color = ColourData.get_color(ct)
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
