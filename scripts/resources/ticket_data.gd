class_name BallData
extends RefCounted
## Ball type definitions and properties

enum BallType {
	PASSWORD_RESET,      # Fast, predictable, common
	NETWORK_OUTAGE,      # Slow, large, high value
	PHISHING_ALERT,      # Erratic movement, splits on wrong catch
	FEATURE_REQUEST,     # Accelerates randomly after bounces
	QUICK_FAVOR,         # "Can you just quickly..." - splits on first deflect
	VAGUE_STRATEGIC,     # Enormous hitbox, very slow
}

# Ball type properties
const BALL_PROPERTIES: Dictionary = {
	BallType.PASSWORD_RESET: {
		"name": "Password Reset",
		"base_speed": 400.0,
		"radius": 14.0,
		"spawn_weight": 30,  # Common
		"point_value": 10,
	},
	BallType.NETWORK_OUTAGE: {
		"name": "Network Outage",
		"base_speed": 200.0,
		"radius": 24.0,
		"spawn_weight": 15,
		"point_value": 50,
	},
	BallType.PHISHING_ALERT: {
		"name": "Phishing Alert",
		"base_speed": 320.0,
		"radius": 16.0,
		"spawn_weight": 15,
		"point_value": 25,
	},
	BallType.FEATURE_REQUEST: {
		"name": "Feature Request",
		"base_speed": 250.0,
		"radius": 16.0,
		"spawn_weight": 20,
		"point_value": 30,
	},
	BallType.QUICK_FAVOR: {
		"name": "Quick Favor",
		"base_speed": 300.0,
		"radius": 12.0,
		"spawn_weight": 15,
		"point_value": 5,
	},
	BallType.VAGUE_STRATEGIC: {
		"name": "Strategic Request",
		"base_speed": 120.0,
		"radius": 40.0,
		"spawn_weight": 5,  # Rare
		"point_value": 100,
	},
}


static func get_properties(ticket_type: BallType) -> Dictionary:
	return BALL_PROPERTIES.get(ticket_type, BALL_PROPERTIES[BallType.PASSWORD_RESET])


static func get_random_type() -> BallType:
	# Weighted random selection
	var total_weight: int = 0
	for props in BALL_PROPERTIES.values():
		total_weight += props["spawn_weight"]

	var roll: int = randi() % total_weight
	var cumulative: int = 0

	for type_key in BALL_PROPERTIES.keys():
		cumulative += BALL_PROPERTIES[type_key]["spawn_weight"]
		if roll < cumulative:
			return type_key

	return BallType.PASSWORD_RESET
