extends Node2D
class_name HowToPlay
## How to Play screen — explains the core misdirection mechanic.
## Drawn entirely in _draw(), consistent with the rest of the UI codebase.

const ColourData = preload("res://scripts/resources/colour_data.gd")
const CornerHUD  = preload("res://scripts/ui/corner_hud.gd")

var _back_rect: Rect2 = Rect2()
var _back_hover: bool  = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_back_hover = _back_rect.has_point(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect.has_point(get_global_mouse_position()):
			_go_back()

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_go_back()


func _go_back() -> void:
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _draw() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var cx: float = sw / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))

	# Title
	var title := "HOW TO PLAY"
	var tsz: int = 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(cx - tw / 2.0 + 2, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(cx - tw / 2.0, 64), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color.WHITE)

	var tagline := "It's all about misdirection — welcome what's yours, turn away the rest."
	var gsz: int = 16
	var gw := font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz).x
	draw_string(font, Vector2(cx - gw / 2.0, 96), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz, Color(0.6, 0.7, 0.8, 1.0))

	# Diagram on the left, rules on the right
	_draw_diagram(font, Vector2(90.0, 140.0), 380.0)
	_draw_rules(font, Vector2(540.0, 150.0), sw - 540.0 - 70.0)

	# Modes row across the bottom
	_draw_modes(font, sh)

	# Back button
	var back_lbl := "← BACK"
	var bsz: int = 18
	var bw := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
	var bx := cx - bw / 2.0
	var by := sh - 40.0
	_back_rect = Rect2(bx - 16, by - bsz, bw + 32, bsz + 12)
	draw_string(font, Vector2(bx, by), back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz,
		Color(0.6, 0.7, 0.9, 1.0) if _back_hover else Color(0.45, 0.55, 0.75, 1.0))

	CornerHUD.draw_on(self)


func _draw_diagram(font: Font, origin: Vector2, s: float) -> void:
	## A small arena square: green (player) zone at the bottom, a rival blue zone
	## at the top, with a scoring green ball and a deflected rival ball.
	var green := ColourData.get_color(ColourData.ColourType.GREEN)
	var blue  := ColourData.get_color(ColourData.ColourType.BLUE)

	var tl := origin
	var br := origin + Vector2(s, s)

	# Arena fill + walls
	draw_rect(Rect2(tl, Vector2(s, s)), Color(0.09, 0.09, 0.14, 1.0))
	# Left/right walls (solid)
	draw_line(tl, Vector2(tl.x, br.y), Color(0.7, 0.7, 0.8, 0.9), 3.0, true)
	draw_line(Vector2(br.x, tl.y), br, Color(0.7, 0.7, 0.8, 0.9), 3.0, true)

	# Player GREEN zone — bottom edge
	var zone_h: float = 26.0
	draw_rect(Rect2(Vector2(tl.x, br.y - zone_h), Vector2(s, zone_h)), Color(green.r, green.g, green.b, 0.28))
	draw_line(Vector2(tl.x, br.y), br, Color(green.r, green.g, green.b, 0.9), 3.0, true)
	# Green paddle
	var paddle_w: float = 70.0
	var paddle_cx: float = tl.x + s * 0.5
	draw_rect(Rect2(Vector2(paddle_cx - paddle_w / 2.0, br.y - zone_h - 12.0), Vector2(paddle_w, 9.0)), green)

	# Rival BLUE zone — top edge
	draw_rect(Rect2(tl, Vector2(s, zone_h)), Color(blue.r, blue.g, blue.b, 0.22))
	draw_line(tl, Vector2(br.x, tl.y), Color(blue.r, blue.g, blue.b, 0.85), 3.0, true)
	var bpaddle_cx: float = tl.x + s * 0.42
	draw_rect(Rect2(Vector2(bpaddle_cx - paddle_w / 2.0, tl.y + zone_h + 4.0), Vector2(paddle_w, 9.0)), blue)

	# GREEN ball heading into the player's zone → SCORE
	var g_ball := Vector2(paddle_cx + 24.0, br.y - zone_h - 74.0)
	draw_circle(g_ball, 12.0, green, true, -1.0, true)
	draw_arc(g_ball, 12.0, 0, TAU, 32, green.lightened(0.3), 2.0, true)
	_draw_arrow(g_ball + Vector2(0, 16), g_ball + Vector2(0, 52), Color(green.r, green.g, green.b, 0.9))
	draw_string(font, Vector2(g_ball.x + 22, g_ball.y + 44), "LET IN → SCORE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, green.lightened(0.25))

	# RIVAL ball (blue) bouncing off the player's paddle → DEFLECT
	var r_ball := Vector2(tl.x + s * 0.30, br.y - zone_h - 60.0)
	draw_circle(r_ball, 12.0, blue, true, -1.0, true)
	draw_arc(r_ball, 12.0, 0, TAU, 32, blue.lightened(0.3), 2.0, true)
	_draw_arrow(r_ball + Vector2(-4, 14), r_ball + Vector2(-34, -20), Color(blue.r, blue.g, blue.b, 0.9))
	draw_string(font, Vector2(r_ball.x - 78, r_ball.y - 30), "DEFLECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, blue.lightened(0.25))


func _draw_arrow(from: Vector2, to: Vector2, col: Color) -> void:
	draw_line(from, to, col, 2.5, true)
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := to
	var back := to - dir * 10.0
	draw_line(tip, back + perp * 5.0, col, 2.5, true)
	draw_line(tip, back - perp * 5.0, col, 2.5, true)


func _draw_rules(font: Font, origin: Vector2, w: float) -> void:
	var rules: Array = [
		["You are GREEN.", "You control the green paddle on the bottom edge.", ColourData.get_color(ColourData.ColourType.GREEN)],
		["Welcome your colour.", "Let green balls slip past into your zone to score points.", Color(0.55, 0.85, 0.55, 1.0)],
		["Turn away the rest.", "Every other colour is a trap — catching one costs you score or a life.", Color(0.95, 0.5, 0.45, 1.0)],
		["Size matters.", "Big balls are worth more points; small balls fly faster.", Color(0.7, 0.75, 0.9, 1.0)],
		["Kit yourself out.", "Spend tokens on power-ups, and toggle modifiers to change the rules.", Color(0.85, 0.75, 0.4, 1.0)],
	]

	var y: float = origin.y
	for r in rules:
		var heading: String = r[0]
		var body: String    = r[1]
		var col: Color      = r[2]

		# Bullet dot
		draw_circle(Vector2(origin.x + 6.0, y - 6.0), 5.0, col, true, -1.0, true)

		draw_string(font, Vector2(origin.x + 22.0, y), heading,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, col)
		y += 26.0
		_draw_wrapped(font, body, Vector2(origin.x + 22.0, y), w - 22.0, 16, Color(0.72, 0.74, 0.82, 1.0))
		y += 52.0


func _draw_modes(font: Font, sh: float) -> void:
	var modes: Array = [
		["NORMAL", "Beat the clock for the top score.", Color(0.4, 0.85, 0.4, 1.0)],
		["ENDLESS", "Survive on 3 lives — how long can you last?", Color(0.4, 0.65, 1.0, 1.0)],
		["ELIMINATION", "Outlast every rival zone to win.", Color(1.0, 0.45, 0.35, 1.0)],
	]
	var sw: float = get_viewport_rect().size.x
	var box_w: float = 360.0
	var gap: float = 24.0
	var total: float = modes.size() * box_w + (modes.size() - 1) * gap
	var start_x: float = (sw - total) / 2.0
	var y: float = sh - 150.0

	for i in modes.size():
		var m: Array = modes[i]
		var bx: float = start_x + i * (box_w + gap)
		var rect := Rect2(bx, y, box_w, 74.0)
		draw_rect(rect, Color(0.1, 0.1, 0.16, 1.0))
		draw_rect(rect, Color(m[2].r, m[2].g, m[2].b, 0.6), false, 1.5)
		draw_string(font, Vector2(bx + 16.0, y + 30.0), m[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, m[2])
		draw_string(font, Vector2(bx + 16.0, y + 56.0), m[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.72, 0.8, 1.0))


func _draw_wrapped(font: Font, text: String, pos: Vector2, max_w: float, size: int, col: Color) -> void:
	## Simple word-wrap for body copy.
	var words: PackedStringArray = text.split(" ")
	var line: String = ""
	var y: float = pos.y
	for word in words:
		var trial: String = word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and line != "":
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			line = word
			y += size + 6.0
		else:
			line = trial
	if line != "":
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
