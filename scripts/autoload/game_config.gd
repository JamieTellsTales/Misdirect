extends Node
## GameConfig — persists selected power up and active modifiers between scenes

## Canonical list of all power-ups. Add entries here to extend the shop and pre-game screen.
## "kind": "active"  → hold-key ability, goes in the single active slot (SPACE).
##         "passive" → automatic on-hit / always-on effect, goes in a passive slot.
##         "" (None) → placeholder, valid in any slot.
const POWER_UPS: Array = [
	{
		"id": "",
		"label": "None",
		"desc": "Standard game — no special abilities",
		"price": 0,
		"kind": "",
	},
	{
		"id": "gravity",
		"label": "Gravity",
		"desc": "Hold SPACE to pull nearby balls toward your paddle",
		"price": 50,
		"kind": "active",
	},
	{
		"id": "anti_gravity",
		"label": "Anti-Gravity",
		"desc": "Hold SPACE to repel nearby balls away from your paddle",
		"price": 50,
		"kind": "active",
	},
	{
		"id": "cyclone",
		"label": "Cyclone",
		"desc": "Hold SPACE to spin nearby balls wildly around your paddle",
		"price": 150,
		"kind": "active",
	},
	{
		"id": "double_rebound",
		"label": "Double Rebound",
		"desc": "Each ball hitting your paddle splits into two — doubles Multi Shot's output when equipped together",
		"price": 75,
		"kind": "passive",
	},
	{
		"id": "railgun",
		"label": "Railgun",
		"desc": "Balls that hit your paddle are launched at extreme speed",
		"price": 100,
		"kind": "passive",
	},
	{
		"id": "multi_shot",
		"label": "Multi Shot",
		"desc": "Balls hitting your paddle split into 2–5 random balls",
		"price": 125,
		"kind": "passive",
	},
	{
		"id": "clone",
		"label": "Clone",
		"desc": "Balls hitting your paddle split into two near-identical copies",
		"price": 100,
		"kind": "passive",
	},
	{
		"id": "deflector",
		"label": "Deflector",
		"desc": "Your paddle becomes a triangle that angles balls sideways on impact",
		"price": 75,
		"kind": "passive",
	},
	{
		"id": "hyper_paddle",
		"label": "Hyper Paddle",
		"desc": "Doubles your paddle's movement speed",
		"price": 125,
		"kind": "passive",
	},
]

## Canonical list of all modifiers. Add entries here to extend the pre-game screen.
## Optional field "unlock_level" locks the modifier until the player reaches that level.
const MODIFIERS: Array = [
	{
		"id": "rotated_colours",
		"label": "Rotated Colours",
		"desc": "Each colour targets the next zone anti-clockwise",
		"unlock_level": 2,
	},
	{
		"id": "chaos_ball",
		"label": "Chaos Ball",
		"desc": "Balls spawn at twice the normal rate",
		"unlock_level": 3,
	},
	{
		"id": "load_balanced",
		"label": "Load Balanced",
		"desc": "Each new ball always targets the colour with the lowest score",
		"unlock_level": 4,
	},
	{
		"id": "random_directions",
		"label": "Random Directions",
		"desc": "Balls fire in random directions instead of toward their zone",
		"unlock_level": 5,
	},
	{
		"id": "extra_time",
		"label": "Extra Time",
		"desc": "When the timer ends, play continues until all remaining balls are collected",
		"unlock_level": 6,
		"timed_only": true,
	},
	{
		"id": "final_countdown",
		"label": "Final Countdown",
		"desc": "In the last 10 seconds, balls spawn at double frequency",
		"unlock_level": 8,
		"timed_only": true,
	},
	{
		"id": "return_to_sender",
		"label": "Return to Sender",
		"desc": "Wrong catches bounce the ball back into play — faster every time",
		"unlock_level": 9,
	},
	{
		"id": "speed_ball",
		"label": "Speed Ball",
		"desc": "All balls move at double speed — your final score is doubled to compensate",
		"unlock_level": 10,
	},
	{
		"id": "erratic_balls",
		"label": "Erratic Balls",
		"desc": "Balls randomly change direction mid-flight",
		"unlock_level": 11,
	},
	{
		"id": "black_hole",
		"label": "Black Hole",
		"desc": "A black hole at the centre pulls balls in and destroys them",
		"unlock_level": 12,
	},
	{
		"id": "surge_balls",
		"label": "Surge Balls",
		"desc": "Balls randomly speed up and slow down",
		"unlock_level": 13,
	},
	{
		"id": "gravity_wells",
		"label": "Gravity Wells",
		"desc": "Roaming gravity wells pull balls off course — but don't destroy them",
		"unlock_level": 14,
	},
	{
		"id": "pillars",
		"label": "Pillars",
		"desc": "Evenly-spaced pillars around the arena deflect balls unpredictably",
		"unlock_level": 15,
	},
]

## Map unlock requirements. "wins" on "prev" map needed to unlock each map.
const MAP_UNLOCK_REQUIREMENTS: Dictionary = {
	"triangle":  {"wins": 0, "prev": ""},
	"square":    {"wins": 4, "prev": "triangle"},
	"pentagon":  {"wins": 5, "prev": "square"},
	"hexagon":   {"wins": 6, "prev": "pentagon"},
	"heptagon":  {"wins": 7, "prev": "hexagon"},
	"octagon":   {"wins": 8, "prev": "heptagon"},
}

## Total achievements defined in the game. Update this as achievements are added.
const TOTAL_ACHIEVEMENTS: int = 0

## Power-up slot definitions.
## Slot 0 is the single ACTIVE slot (hold SPACE) and is free from the start.
## Slots 1-2 are PASSIVE slots (always-on, no key) unlocked by level + token fee.
## key_primary / key_alt (active slot only) are KEY_* constants held during play.
const POWER_UP_SLOT_DEFS: Array = [
	{"kind": "active",  "key_label": "SPACE", "key_primary": KEY_SPACE, "key_alt": KEY_PAGEDOWN, "unlock_level": 1,  "unlock_price": 0},
	{"kind": "passive", "key_label": "PASSIVE", "key_primary": KEY_NONE, "key_alt": KEY_NONE,    "unlock_level": 10, "unlock_price": 200},
	{"kind": "passive", "key_label": "PASSIVE", "key_primary": KEY_NONE, "key_alt": KEY_NONE,    "unlock_level": 20, "unlock_price": 400},
]

var selected_power_up: String = ""  # Legacy — kept for compatibility; use power_up_slots
var power_up_slots: Array = ["", "", ""]  # Power-up ID assigned to each slot; "" = empty
var active_modifiers: Array = []    # e.g. ["random_directions", "rotated_colours"]
var selected_map: String = "square"
var num_players: int = 4            # Total zones including player
var game_mode: String = "normal"    # "normal", "endless", "elimination"

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
		3: [0, 2, 3],           # Player bottom, two at top (upper-right + upper-left)
		5: [0, 1, 2, 3, 4],
	},
	"hexagon": {
		2: [0, 3],              # Opposite sides
		3: [0, 2, 4],           # Alternating
		6: [0, 1, 2, 3, 4, 5],
	},
	"heptagon": {
		3: [0, 2, 5],           # Symmetric: 2 and 5 mirror about vertical axis
		7: [0, 1, 2, 3, 4, 5, 6],
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
	"heptagon": [3, 7],
	"octagon":  [2, 3, 4, 5, 6, 7, 8],
}


func _notification(what: int) -> void:
	# Android back button: route it to ui_cancel so each screen's own back /
	# pause / confirm-quit handler fires (project.godot disables the default
	# quit-on-go-back so this is the single point of control).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var press := InputEventAction.new()
		press.action = "ui_cancel"
		press.pressed = true
		Input.parse_input_event(press)
		var release := InputEventAction.new()
		release.action = "ui_cancel"
		release.pressed = false
		Input.parse_input_event(release)


func reset() -> void:
	selected_power_up = ""
	power_up_slots = ["", "", ""]
	active_modifiers = []
	game_mode = "normal"
	# selected_map and num_players are intentionally NOT reset here —
	# they are set by the map select screen and should persist into the arena.


func has_power_up_in_slot(pu_id: String) -> bool:
	## Returns true if pu_id is currently assigned to any power-up slot.
	return pu_id in power_up_slots


func powerup_kind(pu_id: String) -> String:
	## "active", "passive", or "" (None / unknown).
	for pu in POWER_UPS:
		if pu["id"] == pu_id:
			return pu.get("kind", "")
	return ""


func slot_kind(slot_idx: int) -> String:
	## "active" or "passive" for the given slot index.
	if slot_idx < 0 or slot_idx >= POWER_UP_SLOT_DEFS.size():
		return "active"
	return POWER_UP_SLOT_DEFS[slot_idx].get("kind", "active")


func has_modifier(mod: String) -> bool:
	return active_modifiers.has(mod)


func is_timed_mode() -> bool:
	## Only Normal mode has a round timer; Endless and Elimination run open-ended.
	return game_mode == "normal"


func is_modifier_compatible(mod_id: String) -> bool:
	## Timed-only modifiers (extra_time, final_countdown) do nothing without a
	## round timer, so they're unavailable in Endless / Elimination.
	for m in MODIFIERS:
		if m["id"] == mod_id and m.get("timed_only", false):
			return is_timed_mode()
	return true


func prune_incompatible_modifiers() -> void:
	## Drop any active modifiers that don't apply to the current game mode.
	for mod_id in active_modifiers.duplicate():
		if not is_modifier_compatible(mod_id):
			active_modifiers.erase(mod_id)


func toggle_modifier(mod: String) -> void:
	if not is_modifier_compatible(mod):
		return
	if active_modifiers.has(mod):
		active_modifiers.erase(mod)
	else:
		active_modifiers.append(mod)


func set_power_up(power_up: String) -> void:
	if selected_power_up == power_up:
		selected_power_up = ""  # Toggle off
	else:
		selected_power_up = power_up
