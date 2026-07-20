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
