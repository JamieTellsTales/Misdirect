extends Node
## ProfileManager — manages player profiles, each with their own stats.
## Registered as an autoload BEFORE StatsManager so StatsManager can read the
## active profile path during its own _ready().
## Settings (audio/display) are device-level and are NOT per-profile.

const INDEX_PATH := "user://profiles/index.cfg"
const MAX_NAME_LENGTH := 20

# Array of {id: String, name: String} — ordered as they were created
var profiles: Array = []

# ID of the currently active profile — matches one entry in `profiles`
var active_id: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://profiles")
	_load_index()
	if profiles.is_empty():
		_migrate_legacy_data()


# ── Path helpers ───────────────────────────────────────────────────────────────

func profile_dir(id: String) -> String:
	## Returns the user:// directory path for a given profile ID.
	return "user://profiles/" + id + "/"


func active_name() -> String:
	## Returns the display name of the active profile, or "Player" as fallback.
	for p in profiles:
		if p["id"] == active_id:
			return p["name"]
	return "Player"


# ── Profile CRUD ───────────────────────────────────────────────────────────────

func create_profile(name: String) -> String:
	## Creates a new profile with the given display name.
	## Automatically switches to it and saves the index.
	## Returns the new profile ID.
	var id := _generate_id()
	DirAccess.make_dir_recursive_absolute(profile_dir(id))
	profiles.append({"id": id, "name": name.strip_edges()})
	active_id = id
	_save_index()
	return id


func switch_profile(id: String) -> void:
	## Sets the active profile and reloads StatsManager with the new profile's data.
	if not _profile_exists(id):
		return
	active_id = id
	_save_index()
	StatsManager.load_stats()


func rename_profile(id: String, new_name: String) -> void:
	## Renames an existing profile.
	for p in profiles:
		if p["id"] == id:
			p["name"] = new_name.strip_edges()
			_save_index()
			return


func delete_profile(id: String) -> bool:
	## Deletes a profile and its stats file.
	## Returns false if it is the last profile or the currently active profile.
	if profiles.size() <= 1:
		return false
	if id == active_id:
		return false

	# Remove stats file and directory
	var dir := DirAccess.open(profile_dir(id))
	if dir:
		# Remove stats.cfg if it exists
		dir.remove("stats.cfg")
	# Remove the (now empty) profile directory
	DirAccess.open("user://profiles").remove(id)

	# Remove from array
	for i in range(profiles.size() - 1, -1, -1):
		if profiles[i]["id"] == id:
			profiles.remove_at(i)
			break

	_save_index()
	return true


func can_delete(id: String) -> bool:
	## Returns true if this profile can be deleted (not active, not last).
	return profiles.size() > 1 and id != active_id


# ── Persistence ────────────────────────────────────────────────────────────────

func _load_index() -> void:
	var config := ConfigFile.new()
	if config.load(INDEX_PATH) != OK:
		return  # No index yet — fresh install or first profile not yet created

	active_id = config.get_value("index", "active_id", "")

	var ids: Array   = config.get_value("index", "profile_ids",   [])
	var names: Array = config.get_value("index", "profile_names", [])
	profiles.clear()
	for i in ids.size():
		profiles.append({"id": ids[i], "name": names[i] if i < names.size() else "Player"})


func _save_index() -> void:
	var config := ConfigFile.new()
	config.set_value("index", "active_id", active_id)

	var ids: Array   = []
	var names: Array = []
	for p in profiles:
		ids.append(p["id"])
		names.append(p["name"])
	config.set_value("index", "profile_ids",   ids)
	config.set_value("index", "profile_names", names)
	config.save(INDEX_PATH)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _profile_exists(id: String) -> bool:
	for p in profiles:
		if p["id"] == id:
			return true
	return false


func _generate_id() -> String:
	## Generates a unique ID from timestamp + random suffix.
	return str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(randi() % 9000 + 1000)


func _migrate_legacy_data() -> void:
	## If a pre-profile stats.cfg exists in user://, migrate it to a new "Player 1" profile
	## so existing saves aren't lost after the profile system is introduced.
	if not FileAccess.file_exists("user://stats.cfg"):
		return

	var id := _generate_id()
	DirAccess.make_dir_recursive_absolute(profile_dir(id))

	# Copy old stats.cfg content into the new profile directory
	var old_bytes := FileAccess.get_file_as_bytes("user://stats.cfg")
	var new_file := FileAccess.open(profile_dir(id) + "stats.cfg", FileAccess.WRITE)
	if new_file:
		new_file.store_buffer(old_bytes)
		new_file.close()

	# Delete the old flat file so it doesn't cause confusion
	DirAccess.open("user://").remove("stats.cfg")

	profiles.append({"id": id, "name": "Player 1"})
	active_id = id
	_save_index()
