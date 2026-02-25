extends Node
## GameConfig — persists selected power up and active modifiers between scenes

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
