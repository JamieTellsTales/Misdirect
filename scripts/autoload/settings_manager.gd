extends Node
## SettingsManager — loads, saves and applies all player-facing settings.
## Persists to user://settings.cfg via Godot's ConfigFile.
## Registered as an autoload so any scene can read or change settings.

const CONFIG_PATH := "user://settings.cfg"

# ── Supported window resolutions (windowed mode) ────────────────────────────
const RESOLUTIONS: Array = [
	# ── Landscape ─────────────────────────────────────────────────────────────
	Vector2i(1280,  720),
	Vector2i(1280,  800),  # Steam Deck native
	Vector2i(1334,  750),  # iPhone 6/7/8
	Vector2i(1366,  768),  # Common laptop
	Vector2i(1440,  900),
	Vector2i(1600,  900),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),  # 16:10 widescreen
	Vector2i(2340, 1080),  # iPhone 11 / 19.5:9 Android
	Vector2i(2400, 1080),  # 20:9 Android (Pixel etc.)
	Vector2i(2532, 1170),  # iPhone 12/13
	Vector2i(2560, 1080),  # Ultrawide 1080p
	Vector2i(2560, 1440),
	Vector2i(2778, 1284),  # iPhone 14 Pro Max
	Vector2i(3440, 1440),  # Ultrawide 1440p
	Vector2i(3840, 2160),  # 4K
	# ── Portrait ──────────────────────────────────────────────────────────────
	Vector2i( 750, 1334),  # iPhone 6/7/8
	Vector2i(1080, 1920),  # Android Full HD
	Vector2i(1080, 2340),  # iPhone 11 / 19.5:9 Android
	Vector2i(1080, 2400),  # 20:9 Android (Pixel etc.)
	Vector2i(1170, 2532),  # iPhone 12/13
	Vector2i(1284, 2778),  # iPhone 14 Pro Max
]

# ── Supported font modes ────────────────────────────────────────────────────
const FONT_MODES: Array = [
	{"id": "atkinson", "label": "Atkinson Hyperlegible"},
	{"id": "dyslexic", "label": "OpenDyslexic"},
	{"id": "default",  "label": "System Default"},
]

# ── Current values (defaults shown) ─────────────────────────────────────────
var fullscreen: bool = false
var vsync: bool = true
var resolution_index: int = 0   # Index into RESOLUTIONS
var font_mode_index: int = 0    # Index into FONT_MODES
var master_volume: float = 1.0  # 0.0 – 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

# Accessibility: per-zone colour overrides. Maps ColourType (int) → index into
# ColourData.ACCESSIBLE_PALETTE. Absent / -1 = use the zone's default colour.
var zone_colours: Dictionary = {}
# Accessibility toggles.
var reduced_motion: bool = false  # Disable shake / hit-stop / trails / flashing
var ball_symbols: bool = false    # Draw a distinct symbol per colour on balls & zones
var touch_scheme: String = "joystick"  # Touch control layout: "joystick" or "slide"


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
	font_mode_index  = config.get_value("display", "font_mode_index",   0)
	font_mode_index  = clampi(font_mode_index, 0, FONT_MODES.size() - 1)
	master_volume    = config.get_value("audio",   "master_volume",     1.0)
	music_volume     = config.get_value("audio",   "music_volume",      0.8)
	sfx_volume       = config.get_value("audio",   "sfx_volume",        1.0)
	zone_colours     = config.get_value("colours", "zone_colours",      {})
	reduced_motion   = config.get_value("accessibility", "reduced_motion", false)
	ball_symbols     = config.get_value("accessibility", "ball_symbols",   false)
	touch_scheme     = config.get_value("accessibility", "touch_scheme",   "joystick")


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen",       fullscreen)
	config.set_value("display", "vsync",            vsync)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "font_mode_index",  font_mode_index)
	config.set_value("audio",   "master_volume",    master_volume)
	config.set_value("audio",   "music_volume",     music_volume)
	config.set_value("audio",   "sfx_volume",       sfx_volume)
	config.set_value("colours", "zone_colours",     zone_colours)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "ball_symbols",   ball_symbols)
	config.set_value("accessibility", "touch_scheme",   touch_scheme)
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
		# Only reposition when the size actually changes — avoids snapping the window
		# to the primary monitor every time an unrelated setting (e.g. volume) is previewed.
		if DisplayServer.window_get_size() != res:
			DisplayServer.window_set_size(res)
			# Centre on whichever screen the window currently lives on, not screen 0.
			var screen: int       = DisplayServer.window_get_current_screen()
			var screen_pos: Vector2i  = DisplayServer.screen_get_position(screen)
			var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
			# Centre the window on screen, but clamp so it never goes above or
			# left of the display — handles portrait windows taller than the monitor.
			DisplayServer.window_set_position(
				screen_pos + Vector2i(
					maxi(0, (screen_size.x - res.x) / 2),
					maxi(0, (screen_size.y - res.y) / 2)
				)
			)


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

func get_available_resolution_indices() -> Array:
	## Returns indices into RESOLUTIONS that fit within the current display.
	## Excludes any resolution larger than the monitor in either dimension.
	var screen: int           = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var result: Array = []
	for i in RESOLUTIONS.size():
		var res: Vector2i = RESOLUTIONS[i]
		if res.x <= screen_size.x and res.y <= screen_size.y:
			result.append(i)
	return result


func get_resolution_label() -> String:
	var res: Vector2i = RESOLUTIONS[resolution_index]
	return "%d × %d" % [res.x, res.y]


func step_resolution(direction: int) -> void:
	## Cycles through only resolutions that fit the current display.
	var avail: Array = get_available_resolution_indices()
	if avail.is_empty():
		return
	var cur_pos: int = avail.find(resolution_index)
	if cur_pos == -1:
		resolution_index = avail[0]
	else:
		resolution_index = avail[wrapi(cur_pos + direction, 0, avail.size())]


# ── Accessibility: zone colours ─────────────────────────────────────────────

func get_zone_colour_index(colour_type: int) -> int:
	## Palette index chosen for this zone, or -1 for the default colour.
	return int(zone_colours.get(colour_type, -1))


func set_zone_colour_index(colour_type: int, palette_index: int) -> void:
	## palette_index < 0 clears the override (back to default). Saves immediately.
	if palette_index < 0:
		zone_colours.erase(colour_type)
	else:
		zone_colours[colour_type] = palette_index
	save_settings()


func reset_zone_colours() -> void:
	zone_colours.clear()
	save_settings()
