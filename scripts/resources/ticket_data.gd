class_name TicketData
extends RefCounted
## Ticket type definitions and properties

enum TicketType {
	PASSWORD_RESET,      # Fast, predictable, common
	NETWORK_OUTAGE,      # Slow, large, high value
	PHISHING_ALERT,      # Erratic movement, splits on wrong catch
	FEATURE_REQUEST,     # Accelerates randomly after bounces
	QUICK_FAVOR,         # "Can you just quickly..." - splits on first deflect
	VAGUE_STRATEGIC,     # Enormous hitbox, very slow
}

# Ticket type properties
const TICKET_PROPERTIES: Dictionary = {
	TicketType.PASSWORD_RESET: {
		"name": "Password Reset",
		"base_speed": 400.0,
		"radius": 14.0,
		"spawn_weight": 30,  # Common
		"point_value": 10,
	},
	TicketType.NETWORK_OUTAGE: {
		"name": "Network Outage",
		"base_speed": 200.0,
		"radius": 24.0,
		"spawn_weight": 15,
		"point_value": 50,
	},
	TicketType.PHISHING_ALERT: {
		"name": "Phishing Alert",
		"base_speed": 320.0,
		"radius": 16.0,
		"spawn_weight": 15,
		"point_value": 25,
	},
	TicketType.FEATURE_REQUEST: {
		"name": "Feature Request",
		"base_speed": 250.0,
		"radius": 16.0,
		"spawn_weight": 20,
		"point_value": 30,
	},
	TicketType.QUICK_FAVOR: {
		"name": "Quick Favor",
		"base_speed": 300.0,
		"radius": 12.0,
		"spawn_weight": 15,
		"point_value": 5,
	},
	TicketType.VAGUE_STRATEGIC: {
		"name": "Strategic Request",
		"base_speed": 120.0,
		"radius": 40.0,
		"spawn_weight": 5,  # Rare
		"point_value": 100,
	},
}


static func get_properties(ticket_type: TicketType) -> Dictionary:
	return TICKET_PROPERTIES.get(ticket_type, TICKET_PROPERTIES[TicketType.PASSWORD_RESET])


static func get_random_type() -> TicketType:
	# Weighted random selection
	var total_weight: int = 0
	for props in TICKET_PROPERTIES.values():
		total_weight += props["spawn_weight"]

	var roll: int = randi() % total_weight
	var cumulative: int = 0

	for type_key in TICKET_PROPERTIES.keys():
		cumulative += TICKET_PROPERTIES[type_key]["spawn_weight"]
		if roll < cumulative:
			return type_key

	return TicketType.PASSWORD_RESET
