extends Control
class_name RoundTimerDisplay
## Displays the round timer countdown

signal timer_expired

@export var round_duration: float = 120.0  # 2 minutes

var time_remaining: float = 0.0
var is_running: bool = false
var is_warning: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(150, 40)
	time_remaining = round_duration
	queue_redraw()


func _process(delta: float) -> void:
	if is_running and time_remaining > 0:
		time_remaining -= delta

		# Warning state when low on time
		var was_warning: bool = is_warning
		is_warning = time_remaining < 30.0

		if time_remaining <= 0:
			time_remaining = 0
			is_running = false
			timer_expired.emit()

		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Background
	var bg_color := Color(0.1, 0.1, 0.2, 0.9)
	if is_warning:
		var pulse: float = (sin(Time.get_ticks_msec() / 150.0) + 1.0) / 2.0
		bg_color = bg_color.lerp(Color(0.4, 0.1, 0.1, 0.9), pulse * 0.5)
	draw_rect(rect, bg_color)

	# Border
	draw_rect(rect, Color.WHITE, false, 2.0)

	# Time text
	var font := ThemeDB.fallback_font
	var minutes: int = int(time_remaining) / 60
	var seconds: int = int(time_remaining) % 60
	var time_text: String = "%d:%02d" % [minutes, seconds]

	var font_size: int = 28
	var text_size := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(
		(size.x - text_size.x) / 2,
		(size.y + text_size.y) / 2 - 4
	)

	var text_color := Color.WHITE if not is_warning else Color.YELLOW
	draw_string(font, text_pos, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func start_timer() -> void:
	time_remaining = round_duration
	is_running = true


func stop_timer() -> void:
	is_running = false


func get_time_remaining() -> float:
	return time_remaining
