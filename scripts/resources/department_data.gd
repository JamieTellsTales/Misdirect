class_name DepartmentData
extends RefCounted
## Department configuration data

enum DepartmentType {
	SERVICE_DESK,
	INFRASTRUCTURE,
	SECURITY,
	DEVELOPMENT,
	MANAGEMENT
}

const DEPARTMENT_COLORS: Dictionary = {
	DepartmentType.SERVICE_DESK: Color.DODGER_BLUE,
	DepartmentType.INFRASTRUCTURE: Color.FOREST_GREEN,
	DepartmentType.SECURITY: Color.CRIMSON,
	DepartmentType.DEVELOPMENT: Color.GOLD,
	DepartmentType.MANAGEMENT: Color.MEDIUM_PURPLE,
}

const DEPARTMENT_NAMES: Dictionary = {
	DepartmentType.SERVICE_DESK: "Service Desk",
	DepartmentType.INFRASTRUCTURE: "Infrastructure",
	DepartmentType.SECURITY: "Security",
	DepartmentType.DEVELOPMENT: "Development",
	DepartmentType.MANAGEMENT: "Management",
}

static func get_color(dept: DepartmentType) -> Color:
	return DEPARTMENT_COLORS.get(dept, Color.WHITE)

static func get_department_name(dept: DepartmentType) -> String:
	return DEPARTMENT_NAMES.get(dept, "Unknown")
