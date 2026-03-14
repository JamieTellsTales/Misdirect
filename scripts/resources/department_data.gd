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

static func get_color(colour: int) -> Color:
	return COLOURS.get(colour, Color.WHITE)

static func get_colour_name(colour: int) -> String:
	return COLOUR_NAMES.get(colour, "Unknown")
