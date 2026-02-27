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


func reset() -> void:
	selected_power_up = ""
	active_modifiers = []


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
