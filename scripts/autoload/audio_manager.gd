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

const FADE_DURATION: float = 0.6   # seconds for crossfade

# Two players for crossfading — one fades out while the other fades in.
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active:   AudioStreamPlayer   # currently audible
var _inactive: AudioStreamPlayer   # ready to receive next track

# Keep music_player as an alias so any external callers still work.
var music_player: AudioStreamPlayer :
	get: return _active if _active else _player_a

var sfx_player:  AudioStreamPlayer
var current_path: String = ""
var _tween_a: Tween = null
var _tween_b: Tween = null

# Pre-generated SFX streams — built once at startup to avoid mid-game stutter
var _correct_stream: AudioStreamWAV
var _wrong_stream: AudioStreamWAV
var _game_over_stream: AudioStreamWAV


func _ready() -> void:
	_ensure_music_bus()
	_ensure_sfx_bus()

	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Music"
	add_child(_player_a)
	_player_a.finished.connect(_on_music_finished.bind(_player_a))

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Music"
	add_child(_player_b)
	_player_b.finished.connect(_on_music_finished.bind(_player_b))

	_active   = _player_a
	_inactive = _player_b

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Rising ping — pleasant "correct" sound (500 → 1500 Hz, clean sine)
	_correct_stream   = _generate_sweep(500.0, 1500.0, 0.25, 0.45, false)
	# Descending buzz — harsh "wrong" sound (420 → 120 Hz, + 3rd harmonic)
	_wrong_stream     = _generate_sweep(420.0, 120.0,  0.35, 0.45, true)
	# Dramatic minor chord stab — game over hit
	_game_over_stream = _generate_chord_stab()


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
	current_path = ""
	_kill_tween(_tween_a)
	_kill_tween(_tween_b)
	_tween_a = _tween_to(_player_a, -80.0, func() -> void: _player_a.stop())
	_tween_b = _tween_to(_player_b, -80.0, func() -> void: _player_b.stop())


func play_correct_catch() -> void:
	## Play the rising-ping SFX for a correct-colour catch.
	sfx_player.stream = _correct_stream
	sfx_player.play()


func play_wrong_catch() -> void:
	## Play the descending-buzz SFX for a wrong-colour catch.
	sfx_player.stream = _wrong_stream
	sfx_player.play()


func play_game_over() -> void:
	## Play the dramatic minor-chord stab on round end.
	sfx_player.stream = _game_over_stream
	sfx_player.play()


# ── Internal ─────────────────────────────────────────────────────────────────

func _on_music_finished(player: AudioStreamPlayer) -> void:
	## Loop the track that just finished — only if it's still the active one.
	if player == _active and current_path != "":
		player.volume_db = 0.0
		player.play()


func _play(path: String) -> void:
	if current_path == path and _active.playing:
		return  # Already playing this track — don't restart it

	var stream := load(path) as AudioStreamWAV
	if stream == null:
		push_warning("AudioManager: could not load track: " + path)
		return

	current_path = path

	# Start new track on the inactive player at silence and fade it in.
	_inactive.volume_db = -80.0
	_inactive.stream    = stream
	_inactive.play()

	# Fade inactive → full, active → silent (crossfade, both happen simultaneously).
	var fading_out: AudioStreamPlayer = _active
	var fading_in:  AudioStreamPlayer = _inactive

	_kill_tween(_tween_a if fading_out == _player_a else _tween_b)
	_kill_tween(_tween_a if fading_in  == _player_a else _tween_b)

	var t_out: Tween = _tween_to(fading_out, -80.0, func() -> void: fading_out.stop())
	var t_in:  Tween = _tween_to(fading_in,    0.0)

	if fading_out == _player_a:
		_tween_a = t_out;  _tween_b = t_in
	else:
		_tween_b = t_out;  _tween_a = t_in

	# Swap active/inactive for the next transition.
	_active   = fading_in
	_inactive = fading_out


func _tween_to(player: AudioStreamPlayer, target_db: float,
		on_done: Callable = Callable()) -> Tween:
	var t: Tween = create_tween()
	t.tween_property(player, "volume_db", target_db, FADE_DURATION)
	if on_done.is_valid():
		t.tween_callback(on_done)
	return t


func _kill_tween(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()


func _generate_chord_stab() -> AudioStreamWAV:
	## Generate a dramatic F-minor chord stab (F3 + Ab3 + C4) for game over.
	## Sharp attack, exponential decay, 0.75 s total.
	var sample_rate: int = 44100
	var duration: float  = 0.75
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var freqs: Array  = [174.6, 207.7, 261.6]  # F3, Ab3, C4 — F minor
	var phases: Array = [0.0,   0.0,   0.0]

	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		# 5 ms sharp attack then power-curve decay
		var attack: float   = minf(float(i) / (sample_rate * 0.005), 1.0)
		var envelope: float = attack * pow(1.0 - t, 1.8)

		var sample: float = 0.0
		for j in range(freqs.size()):
			sample  += sin(phases[j])
			phases[j] += freqs[j] * TAU / float(sample_rate)

		sample = (sample / float(freqs.size())) * 0.5 * envelope

		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2]     = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo   = false
	stream.data     = data
	return stream


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
