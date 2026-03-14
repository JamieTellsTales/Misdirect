extends Node
## GameConfig — persists selected power up and active modifiers between scenes

## Canonical list of all power-ups. Add entries here to extend the shop and pre-game screen.
const POWER_UPS: Array = [
	{
		"id": "",
		"label": "None",
		"desc": "Standard game — no special abilities",
		"price": 0,
	},
	{
		"id": "gravity",
		"label": "Gravity",
		"desc": "Hold SPACE to pull nearby balls toward your paddle",
		"price": 50,
	},
	{
		"id": "double_rebound",
		"label": "Double Rebound",
		"desc": "Each ball that hits your paddle splits into two",
		"price": 75,
	},
]

## Canonical list of all modifiers. Add entries here to extend the pre-game screen.
## Optional field "unlock_wins" locks the modifier until that many games are won.
const MODIFIERS: Array = [
	{
		"id": "random_directions",
		"label": "Random Directions",
		"desc": "Balls fire in random directions instead of toward their zone",
	},
	{
		"id": "rotated_colours",
		"label": "Rotated Colours",
		"desc": "Each colour targets the next zone clockwise — nothing goes where you expect",
	},
	{
		"id": "speed_ball",
		"label": "Speed Ball",
		"desc": "All balls move at double speed — your final score is doubled to compensate",
		"unlock_wins": 10,
	},
]

var selected_power_up: String = ""  # "", "gravity", "double_rebound"
var active_modifiers: Array = []    # e.g. ["random_directions", "rotated_colours"]
var selected_map: String = "square"
var num_players: int = 4            # Total zones including player

## Which polygon sides are active per (map, player-count). Side 0 = player (bottom).
## All selections are symmetric around the vertical axis through side 0 where possible.
const MAP_ZONE_SIDES: Dictionary = {
	"triangle": {
		3: [0, 1, 2],
	},
	"square": {
		2: [0, 2],
		3: [0, 1, 3],
		4: [0, 1, 2, 3],
	},
	"pentagon": {
		3: [0, 2, 4],           # Symmetric: skip 1 and 3
		5: [0, 1, 2, 3, 4],
	},
	"hexagon": {
		2: [0, 3],              # Opposite sides
		3: [0, 2, 4],           # Alternating
		6: [0, 1, 2, 3, 4, 5],
	},
	"heptagon": {
		3: [0, 2, 5],           # Symmetric: 2 and 5 mirror about vertical axis
		6: [0, 1, 2, 4, 5, 6],  # Skip side 3 (upper-right near apex)
	},
	"octagon": {
		2: [0, 4],
		3: [0, 3, 5],
		4: [0, 2, 4, 6],
		5: [0, 1, 3, 5, 7],
		6: [0, 1, 3, 4, 5, 7],
		7: [0, 1, 2, 3, 5, 6, 7],
		8: [0, 1, 2, 3, 4, 5, 6, 7],
	},
}

## Valid player counts per map. Arrows on the map select screen step through these only.
const MAP_VALID_PLAYERS: Dictionary = {
	"triangle": [3],
	"square":   [2, 3, 4],
	"pentagon": [3, 5],
	"hexagon":  [2, 3, 6],
	"heptagon": [3, 6],
	"octagon":  [2, 3, 4, 5, 6, 7, 8],
}


func reset() -> void:
	selected_power_up = ""
	active_modifiers = []
	# selected_map and num_players are intentionally NOT reset here —
	# they are set by the map select screen and should persist into the arena.


func has_modifier(mod: String) -> bool:
	return active_modifiers.has(mod)


func toggle_modifier(mod: String) -> void:
	if active_modifiers.has(mod):
		active_modifiers.erase(mod)
	else:
		active_modifiers.append(mod)


func set_power_up(power_up: String) -> void:
	if selected_power_up == power_up:
		selected_power_up = ""  # Toggle off
	else:
		selected_power_up = power_up
