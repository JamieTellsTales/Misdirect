extends Node
## SettingsManager — loads, saves and applies all player-facing settings.
## Persists to user://settings.cfg via Godot's ConfigFile.
## Registered as an autoload so any scene can read or change settings.

const CONFIG_PATH := "user://settings.cfg"

# ── Supported window resolutions (windowed mode) ────────────────────────────
const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

# ── Current values (defaults shown) ─────────────────────────────────────────
var fullscreen: bool = false
var vsync: bool = true
var resolution_index: int = 0   # Index into RESOLUTIONS
var master_volume: float = 1.0  # 0.0 – 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0


func _ready() -> void:
	load_settings()
	apply_settings()


# ── Persistence ──────────────────────────────────────────────────────────────

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return  # File doesn't exist yet — use defaults

	fullscreen       = config.get_value("display", "fullscreen",        false)
	vsync            = config.get_value("display", "vsync",             true)
	resolution_index = config.get_value("display", "resolution_index",  0)
	resolution_index = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	master_volume    = config.get_value("audio",   "master_volume",     1.0)
	music_volume     = config.get_value("audio",   "music_volume",      0.8)
	sfx_volume       = config.get_value("audio",   "sfx_volume",        1.0)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen",       fullscreen)
	config.set_value("display", "vsync",            vsync)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("audio",   "master_volume",    master_volume)
	config.set_value("audio",   "music_volume",     music_volume)
	config.set_value("audio",   "sfx_volume",       sfx_volume)
	config.save(CONFIG_PATH)


# ── Apply ────────────────────────────────────────────────────────────────────

func apply_settings() -> void:
	_apply_display()
	_apply_audio()


func _apply_display() -> void:
	# VSync
	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# Fullscreen / windowed
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[resolution_index]
		DisplayServer.window_set_size(res)
		# Centre the window on screen after resize
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var win_pos: Vector2i = Vector2i(
			(screen_size.x - res.x) / 2,
			(screen_size.y - res.y) / 2
		)
		DisplayServer.window_set_position(win_pos)


func _apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music",  music_volume)
	_set_bus_volume("SFX",    sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


# ── Helpers used by the settings screen ─────────────────────────────────────

func get_resolution_label() -> String:
	var res: Vector2i = RESOLUTIONS[resolution_index]
	return "%d × %d" % [res.x, res.y]


func step_resolution(direction: int) -> void:
	resolution_index = wrapi(resolution_index + direction, 0, RESOLUTIONS.size())
