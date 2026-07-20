class_name ColourData
extends RefCounted
## Colour configuration data for ball zones

enum ColourType {
	BLUE,
	GREEN,
	RED,
	YELLOW,
	PURPLE,
	ORANGE,
	CYAN,
	PINK,
}

const COLOURS: Dictionary = {
	ColourType.BLUE:   Color.DODGER_BLUE,
	ColourType.GREEN:  Color.FOREST_GREEN,
	ColourType.RED:    Color.CRIMSON,
	ColourType.YELLOW: Color.GOLD,
	ColourType.PURPLE: Color.MEDIUM_PURPLE,
	ColourType.ORANGE: Color(1.0, 0.55, 0.0, 1.0),
	ColourType.CYAN:   Color(0.0, 0.85, 0.85, 1.0),
	ColourType.PINK:   Color(1.0, 0.4, 0.7, 1.0),
}

const COLOUR_NAMES: Dictionary = {
	ColourType.BLUE:   "Blue",
	ColourType.GREEN:  "Green",
	ColourType.RED:    "Red",
	ColourType.YELLOW: "Yellow",
	ColourType.PURPLE: "Purple",
	ColourType.ORANGE: "Orange",
	ColourType.CYAN:   "Cyan",
	ColourType.PINK:   "Pink",
}

## Curated colour-blind-friendly palette (based on the Okabe-Ito set) that the
## player can assign to any zone in the accessibility settings. Every entry is
## chosen to stay distinguishable under common colour-vision deficiencies.
const ACCESSIBLE_PALETTE: Array = [
	{"name": "Orange",       "color": Color(0.90, 0.60, 0.00)},
	{"name": "Sky Blue",     "color": Color(0.35, 0.70, 0.90)},
	{"name": "Bluish Green", "color": Color(0.00, 0.62, 0.45)},
	{"name": "Yellow",       "color": Color(0.95, 0.90, 0.25)},
	{"name": "Blue",         "color": Color(0.00, 0.45, 0.70)},
	{"name": "Vermillion",   "color": Color(0.84, 0.37, 0.00)},
	{"name": "Purple",       "color": Color(0.80, 0.60, 0.70)},
	{"name": "White",        "color": Color(0.95, 0.95, 0.95)},
]

static func get_color(colour: int) -> Color:
	## Returns the player's chosen override for this zone, else the default.
	var idx: int = SettingsManager.get_zone_colour_index(colour)
	if idx >= 0 and idx < ACCESSIBLE_PALETTE.size():
		return ACCESSIBLE_PALETTE[idx]["color"]
	return COLOURS.get(colour, Color.WHITE)

static func get_default_color(colour: int) -> Color:
	return COLOURS.get(colour, Color.WHITE)

static func get_colour_name(colour: int) -> String:
	return COLOUR_NAMES.get(colour, "Unknown")


static func draw_symbol(ci: CanvasItem, colour: int, center: Vector2, r: float, col: Color) -> void:
	## Draw a distinct symbol per colour (accessibility — identify a zone/ball
	## without relying on colour). Used by balls and zones when "Ball symbols" is on.
	match colour:
		ColourType.BLUE:    # ring
			ci.draw_arc(center, r * 0.82, 0, TAU, 28, col, maxf(2.0, r * 0.34), true)
		ColourType.GREEN:   # triangle
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -r), center + Vector2(r * 0.92, r * 0.72), center + Vector2(-r * 0.92, r * 0.72)]), col)
		ColourType.RED:     # square
			ci.draw_rect(Rect2(center - Vector2(r * 0.74, r * 0.74), Vector2(r * 1.48, r * 1.48)), col)
		ColourType.YELLOW:  # diamond
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -r), center + Vector2(r, 0.0), center + Vector2(0.0, r), center + Vector2(-r, 0.0)]), col)
		ColourType.PURPLE:  # plus
			var t: float = r * 0.34
			ci.draw_rect(Rect2(center - Vector2(t, r * 0.85), Vector2(t * 2.0, r * 1.7)), col)
			ci.draw_rect(Rect2(center - Vector2(r * 0.85, t), Vector2(r * 1.7, t * 2.0)), col)
		ColourType.ORANGE:  # cross (X)
			var w: float = maxf(2.0, r * 0.32)
			ci.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), col, w, true)
			ci.draw_line(center + Vector2(r * 0.7, -r * 0.7), center + Vector2(-r * 0.7, r * 0.7), col, w, true)
		ColourType.CYAN:    # hexagon
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(center + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * r)
			ci.draw_colored_polygon(hex, col)
		ColourType.PINK:    # 5-point star
			var star := PackedVector2Array()
			for i in 10:
				var rr: float = r if i % 2 == 0 else r * 0.45
				star.append(center + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rr)
			ci.draw_colored_polygon(star, col)
		_:
			ci.draw_circle(center, r * 0.6, col)
