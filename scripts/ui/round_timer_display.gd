extends Control
class_name RoundTimerDisplay
## Displays the round timer countdown

signal timer_expired

@export var round_duration: float = 120.0  # 2 minutes

var time_remaining: float = 0.0
var is_running: bool = false
var is_warning: bool = false
var is_overtime: bool = false
var final_countdown: bool = false  # Set by arena when the Final Countdown modifier is on


func _ready() -> void:
	custom_minimum_size = Vector2(150, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # display only — never swallow touches
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
	var font := FontManager.get_font()
	var font_size: int = 28

	var time_text: String
	var text_color: Color
	if is_overtime:
		time_text = "OVERTIME"
		var pulse: float = (sin(Time.get_ticks_msec() / 300.0) + 1.0) / 2.0
		text_color = Color.WHITE.lerp(Color(1.0, 0.6, 0.1, 1.0), pulse)
	else:
		var minutes: int = int(time_remaining) / 60
		var seconds: int = int(time_remaining) % 60
		time_text = "%d:%02d" % [minutes, seconds]
		text_color = Color.WHITE
		if final_countdown and time_remaining <= 10.0:
			# Enlarged red text for the Final Countdown. A slow pulse by default;
			# static (no flashing) under reduced motion.
			font_size = 36
			if SettingsManager.reduced_motion:
				text_color = Color(1.0, 0.35, 0.3, 1.0)
			else:
				var pulse: float = (sin(Time.get_ticks_msec() / 260.0) + 1.0) / 2.0
				text_color = Color(1.0, 0.85, 0.2, 1.0).lerp(Color(1.0, 0.3, 0.25, 1.0), pulse)
		elif is_warning:
			var pulse: float = (sin(Time.get_ticks_msec() / 150.0) + 1.0) / 2.0
			text_color = Color.WHITE.lerp(Color.YELLOW, pulse)

	var text_size := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x: float = (size.x - text_size.x) / 2.0
	var y: float = (size.y + text_size.y) / 2.0 - 4

	# Shadow
	draw_string(font, Vector2(x + 1, y + 1), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	# Text
	draw_string(font, Vector2(x, y), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func start_timer() -> void:
	time_remaining = round_duration
	is_running = true


func stop_timer() -> void:
	is_running = false


func enter_overtime() -> void:
	is_running  = false
	is_overtime = true
	queue_redraw()


func get_time_remaining() -> float:
	return time_remaining
