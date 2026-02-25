extends Node
## AudioManager — background music playback.
## Creates a "Music" AudioBus at startup so SettingsManager can control volume.
## Registered as an autoload; music persists across scene changes.

const MENU_TRACK := "res://assets/audio/Action & Dramatic Theme #2 (looped).wav"

const GAME_TRACKS: Array = [
	"res://assets/audio/Action & Dramatic Theme #1 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #2 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #3 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #4 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #5 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #6 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #7 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #8 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #9 (looped).wav",
	"res://assets/audio/Action & Dramatic Theme #10 (looped).wav",
]

var music_player: AudioStreamPlayer
var current_path: String = ""


func _ready() -> void:
	_ensure_music_bus()

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)


func _ensure_music_bus() -> void:
	## Create a "Music" bus routed through Master if one doesn't already exist.
	## This lets SettingsManager's music_volume slider control music independently.
	if AudioServer.get_bus_index("Music") != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")


# ── Public API ───────────────────────────────────────────────────────────────

func play_menu_music() -> void:
	## Always play the dedicated menu track, looped.
	_play(MENU_TRACK)


func play_game_music() -> void:
	## Pick one random game track and loop it for the entire session.
	## Called once when the player enters the pre-game config screen so the
	## same track carries through config → arena without re-rolling.
	var track: String = GAME_TRACKS[randi() % GAME_TRACKS.size()]
	_play(track)


func stop_music() -> void:
	music_player.stop()
	current_path = ""


# ── Internal ─────────────────────────────────────────────────────────────────

func _play(path: String) -> void:
	if current_path == path and music_player.playing:
		return  # Already playing this track — don't restart it

	var stream := load(path) as AudioStreamWAV
	if stream == null:
		push_warning("AudioManager: could not load track: " + path)
		return

	# Ensure the stream loops from start to end regardless of embedded loop points
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 0  # 0 = loop to end of data

	current_path = path
	music_player.stream = stream
	music_player.play()
