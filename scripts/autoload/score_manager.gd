extends Node
class_name ScoreManager
## Global score tracking and SLA management

const DepartmentDataScript = preload("res://scripts/resources/department_data.gd")

signal score_changed(department_type: int, new_score: int)
signal sla_missed(department_type: int, ball_data: Dictionary)

# Score per department
var scores: Dictionary = {}

# SLA settings
@export var base_sla_time: float = 10.0  # Seconds to resolve a ticket
@export var sla_miss_penalty: int = 20


func _ready() -> void:
	_reset_scores()


func _reset_scores() -> void:
	scores = {
		DepartmentDataScript.DepartmentType.SERVICE_DESK: 0,
		DepartmentDataScript.DepartmentType.INFRASTRUCTURE: 0,
		DepartmentDataScript.DepartmentType.SECURITY: 0,
		DepartmentDataScript.DepartmentType.DEVELOPMENT: 0,
		DepartmentDataScript.DepartmentType.MANAGEMENT: 0,
	}


func add_score(department_type: int, points: int) -> void:
	if scores.has(department_type):
		scores[department_type] += points
		score_changed.emit(department_type, scores[department_type])


func remove_score(department_type: int, points: int) -> void:
	if scores.has(department_type):
		scores[department_type] -= points
		scores[department_type] = max(0, scores[department_type])
		score_changed.emit(department_type, scores[department_type])


func get_score(department_type: int) -> int:
	return scores.get(department_type, 0)


func get_all_scores() -> Dictionary:
	return scores.duplicate()


func apply_sla_miss_penalty(department_type: int, ball_data: Dictionary) -> void:
	remove_score(department_type, sla_miss_penalty)
	sla_missed.emit(department_type, ball_data)


func get_sla_time_for_ball(ball_data: Dictionary) -> float:
	# Different ball types could have different SLA times
	var base: float = base_sla_time
	if ball_data.has("point_value"):
		# Higher value balls get more time
		var value: int = ball_data["point_value"]
		if value >= 50:
			base *= 1.5
		elif value <= 10:
			base *= 0.8
	return base
