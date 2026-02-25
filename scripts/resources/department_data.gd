class_name ColourData
extends RefCounted
## Colour configuration data for ball zones

enum ColourType {
	BLUE,
	GREEN,
	RED,
	YELLOW,
	PURPLE
}

const COLOURS: Dictionary = {
	ColourType.BLUE:   Color.DODGER_BLUE,
	ColourType.GREEN:  Color.FOREST_GREEN,
	ColourType.RED:    Color.CRIMSON,
	ColourType.YELLOW: Color.GOLD,
	ColourType.PURPLE: Color.MEDIUM_PURPLE,
}

const COLOUR_NAMES: Dictionary = {
	ColourType.BLUE:   "Blue",
	ColourType.GREEN:  "Green",
	ColourType.RED:    "Red",
	ColourType.YELLOW: "Yellow",
	ColourType.PURPLE: "Purple",
}

static func get_color(colour: int) -> Color:
	return COLOURS.get(colour, Color.WHITE)

static func get_colour_name(colour: int) -> String:
	return COLOUR_NAMES.get(colour, "Unknown")
