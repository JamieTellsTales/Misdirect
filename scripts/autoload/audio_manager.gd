extends Node
## AudioManager — background music + SFX playback.
## Creates "Music" and "SFX" audio buses at startup so SettingsManager
## can control their volumes independently.
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
var sfx_player: AudioStreamPlayer
var current_path: String = ""

# Pre-generated SFX streams — built once at startup to avoid mid-game stutter
var _correct_stream: AudioStreamWAV
var _wrong_stream: AudioStreamWAV


func _ready() -> void:
	_ensure_music_bus()
	_ensure_sfx_bus()

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Rising ping — pleasant "correct" sound (500 → 1500 Hz, clean sine)
	_correct_stream = _generate_sweep(500.0, 1500.0, 0.25, 0.45, false)
	# Descending buzz — harsh "wrong" sound (420 → 120 Hz, + 3rd harmonic)
	_wrong_stream   = _generate_sweep(420.0, 120.0,  0.35, 0.45, true)


func _ensure_music_bus() -> void:
	## Create a "Music" bus routed through Master if one doesn't already exist.
	if AudioServer.get_bus_index("Music") != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")


func _ensure_sfx_bus() -> void:
	## Create an "SFX" bus routed through Master if one doesn't already exist.
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")


# ── Public API ────────────────────────────────────────────────────────────────

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


func play_correct_catch() -> void:
	## Play the rising-ping SFX for a correct-colour catch.
	sfx_player.stream = _correct_stream
	sfx_player.play()


func play_wrong_catch() -> void:
	## Play the descending-buzz SFX for a wrong-colour catch.
	sfx_player.stream = _wrong_stream
	sfx_player.play()


# ── Internal ─────────────────────────────────────────────────────────────────

func _on_music_finished() -> void:
	## Called when the track ends — restart it to loop continuously.
	if current_path != "":
		music_player.play()


func _play(path: String) -> void:
	if current_path == path and music_player.playing:
		return  # Already playing this track — don't restart it

	var stream := load(path) as AudioStreamWAV
	if stream == null:
		push_warning("AudioManager: could not load track: " + path)
		return

	current_path = path
	music_player.stream = stream
	music_player.play()


func _generate_sweep(
		freq_start: float,
		freq_end: float,
		duration: float,
		volume: float = 0.5,
		buzzy: bool = false
) -> AudioStreamWAV:
	## Generate a short frequency-sweep tone as a WAV stream.
	## freq_start/freq_end: start and end pitch in Hz.
	## buzzy=true adds a 3rd harmonic for a harsher "wrong catch" timbre.
	var sample_rate: int = 44100
	var num_samples: int  = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono = 2 bytes per sample

	var phase: float  = 0.0
	var phase3: float = 0.0  # phase for the 3rd harmonic (buzzy only)

	for i in range(num_samples):
		var t: float    = float(i) / float(num_samples)
		var freq: float = freq_start + (freq_end - freq_start) * t

		# Envelope: very short attack then linear fade-out
		var attack: float   = minf(t * 30.0, 1.0)
		var envelope: float = attack * (1.0 - t)

		var sample: float = sin(phase)
		if buzzy:
			sample += sin(phase3) * 0.35  # 3rd harmonic adds grit/buzz

		sample = sample * volume * envelope

		phase  += freq                * TAU / float(sample_rate)
		if buzzy:
			phase3 += freq * 3.0 * TAU / float(sample_rate)

		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2]     = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo   = false
	stream.data     = data
	return stream
