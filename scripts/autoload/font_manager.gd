extends Node
## FontManager — serves the active UI font based on the current accessibility setting.
## Falls back to Godot's built-in Noto Sans if a font file isn't present yet.
## All UI scripts call FontManager.get_font() instead of ThemeDB.fallback_font.

const ATKINSON_PATH := "res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"
const DYSLEXIC_PATH  := "res://assets/fonts/OpenDyslexic-Regular.otf"

var _atkinson: Font = null
var _dyslexic:  Font = null


func _ready() -> void:
	_atkinson = _try_load(ATKINSON_PATH)
	_dyslexic  = _try_load(DYSLEXIC_PATH)


func _try_load(path: String) -> Font:
	## Load a font directly from the filesystem using FontFile.load_dynamic_font(),
	## which bypasses Godot's .import sidecar requirement entirely.
	var sys_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(sys_path):
		push_warning("FontManager: font file not found at: " + sys_path)
		return null
	var font_file := FontFile.new()
	var err: int = font_file.load_dynamic_font(sys_path)
	if err == OK:
		return font_file
	push_warning("FontManager: failed to load font (error %d): %s" % [err, sys_path])
	return null


func get_font() -> Font:
	## Returns the font for the current accessibility setting.
	## Index 0 = Atkinson Hyperlegible (default)
	## Index 1 = OpenDyslexic
	## Index 2 = System Default (Noto Sans)
	## Automatically falls back to Noto Sans if a font file is missing.
	match SettingsManager.font_mode_index:
		0:
			# Atkinson Hyperlegible — default
			if _atkinson == null:
				_atkinson = _try_load(ATKINSON_PATH)
			return _atkinson if _atkinson != null else ThemeDB.fallback_font
		1:
			# OpenDyslexic
			if _dyslexic == null:
				_dyslexic = _try_load(DYSLEXIC_PATH)
			return _dyslexic if _dyslexic != null else ThemeDB.fallback_font
		_:
			# System Default (Noto Sans)
			return ThemeDB.fallback_font
