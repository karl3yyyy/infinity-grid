class_name SoundBoard
extends Node

## All sound in the game, synthesised at start-up so no audio files ship:
## effects (boot hum, glitch snap, clicks, combat), a looping synth track and
## the design bible's voice lines through the device's text-to-speech.
## Everything else calls the static helpers; they do nothing until the board
## exists and while sound is switched off.

const RATE := 22050
const MUSIC_RATE := 11025
const PROFILE_PATH := "user://ring_duel_profile.cfg"
const VOICE_LINES := {
	"start": "Link established. Tactical control granted.",
	"ping": "Node ping. Select your signal.",
	"collision": "Signal collided. Recalibrating initiative vector.",
	"capture": "Unit offline.",
	"victory": "Core overwrite complete. Victory established.",
	"defeat": "Critical breach. Core lost.",
}

static var _board: SoundBoard

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _voice := ""


static func play(sound: String, volume_db: float = 0.0) -> void:
	if _board != null and _board.enabled and _board._streams.has(sound):
		_board._play(sound, volume_db)


## Speaks one of VOICE_LINES (robot-like where the device lets us).
static func say(line: String) -> void:
	if VOICE_LINES.has(line):
		speak(VOICE_LINES[line])


## Speaks any English text, e.g. a KERN's emote line.
static func speak(text: String) -> void:
	if _board == null or not _board.enabled or _board._voice.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _board._voice, 70, 0.7, 1.05)


static func is_enabled() -> bool:
	return _board != null and _board.enabled


static func set_enabled(on: bool) -> void:
	if _board == null:
		return
	_board.enabled = on
	if _board._music != null:
		_board._music.stream_paused = not on
		if on and not _board._music.playing and _board._music.stream != null:
			_board._music.play()
	if not on:
		DisplayServer.tts_stop()
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("profile", "sound", on)
	config.save(PROFILE_PATH)


func _ready() -> void:
	_board = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	enabled = bool(config.get_value("profile", "sound", true))
	for index: int in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_effects()
	if DisplayServer.get_name() != "headless":
		var voices := DisplayServer.tts_get_voices_for_language("en")
		_voice = voices[0] if not voices.is_empty() else ""
		_build_music()


func _exit_tree() -> void:
	if _board == self:
		_board = null


func _play(sound: String, volume_db: float) -> void:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = _streams[sound]
			player.volume_db = volume_db - 6.0
			player.play()
			return


# --- Synthesis ------------------------------------------------------------

func _build_effects() -> void:
	_streams["boot"] = _make(1.3, func(t: float) -> float:
		var swell := minf(t / 0.5, 1.0) * (1.0 - t / 1.3)
		return swell * (0.6 * sin(TAU * 55.0 * t) + 0.3 * sin(TAU * 110.0 * t + sin(TAU * 2.0 * t)) + 0.08 * randf_range(-1.0, 1.0)))
	_streams["glitch"] = _make(0.28, func(t: float) -> float:
		var gate := 1.0 if fmod(t * 37.0, 1.0) < 0.55 else 0.0
		return gate * _crush(randf_range(-1.0, 1.0) * 0.7 + 0.4 * _square(880.0 * (1.0 + t * 3.0), t), 4) * (1.0 - t / 0.28))
	_streams["click"] = _make(0.04, func(t: float) -> float: return 0.35 * _square(1800.0, t) * (1.0 - t / 0.04))
	_streams["select"] = _make(0.09, func(t: float) -> float: return 0.4 * _square(lerpf(700.0, 1500.0, t / 0.09), t) * (1.0 - t / 0.09))
	_streams["move"] = _make(0.32, func(t: float) -> float: return randf_range(-1.0, 1.0) * 0.35 * sin(PI * t / 0.32))
	_streams["teleport"] = _make(0.55, func(t: float) -> float:
		var pitch := lerpf(260.0, 2000.0, pow(t / 0.55, 1.6))
		return 0.45 * sin(TAU * pitch * t) * (0.6 + 0.4 * sin(TAU * 18.0 * t)) * (1.0 - t / 0.55))
	_streams["zap"] = _make(0.42, func(t: float) -> float:
		var crackle := randf_range(-1.0, 1.0) * (1.0 if randf() < 0.35 else 0.2)
		return (0.6 * crackle + 0.25 * sin(TAU * 3200.0 * t)) * (1.0 - t / 0.42))
	_streams["shot"] = _make(0.2, func(t: float) -> float:
		return (randf_range(-1.0, 1.0) * 0.7 * exp(-t * 30.0) + 0.6 * sin(TAU * 120.0 * t) * exp(-t * 18.0)))
	_streams["punch"] = _make(0.22, func(t: float) -> float:
		return 0.9 * sin(TAU * lerpf(140.0, 45.0, t / 0.22) * t) * exp(-t * 14.0) + randf_range(-1.0, 1.0) * 0.4 * exp(-t * 60.0))
	_streams["capture"] = _make(0.55, func(t: float) -> float:
		return _crush(randf_range(-1.0, 1.0) * 0.6 + 0.4 * _square(lerpf(400.0, 60.0, t / 0.55), t), 5) * exp(-t * 4.0))
	_streams["signal"] = _make(0.9, func(t: float) -> float:
		var beep := sin(TAU * 1320.0 * t) * exp(-t * 9.0)
		var echo := sin(TAU * 1320.0 * (t - 0.22)) * exp(-(t - 0.22) * 9.0) * 0.45 if t > 0.22 else 0.0
		return 0.5 * (beep + echo))
	_streams["emote"] = _make(0.16, func(t: float) -> float: return 0.35 * _square(1046.0 if t < 0.07 else 1568.0, t) * (1.0 - t / 0.16))
	_streams["victory"] = _notes([523.0, 659.0, 784.0, 1046.0], 0.14, 0.5)
	_streams["defeat"] = _notes([392.0, 330.0, 262.0, 196.0], 0.2, 0.5)


## A short melody of square-ish notes.
func _notes(pitches: Array, step: float, tail: float) -> AudioStreamWAV:
	var length := step * pitches.size() + tail
	return _make(length, func(t: float) -> float:
		var index := mini(int(t / step), pitches.size() - 1)
		var local := t - index * step
		var decay := exp(-local * (6.0 if index < pitches.size() - 1 else 2.5))
		return 0.4 * (0.6 * _square(float(pitches[index]), t) + 0.4 * sin(TAU * float(pitches[index]) * t)) * decay)


func _make(seconds: float, wave: Callable, rate: int = RATE) -> AudioStreamWAV:
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in range(count):
		var sample := clampf(float(wave.call(float(index) / rate)), -1.0, 1.0)
		data.encode_s16(index * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


## A dark looping track: drone, slow minor arpeggio and a soft pulse. Built
## a slice per frame so the start-up never stalls.
func _build_music() -> void:
	var seconds := 16.0
	var count := int(seconds * MUSIC_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var chords: Array = [[220.0, 261.6, 329.6], [196.0, 246.9, 293.7], [174.6, 220.0, 261.6], [196.0, 246.9, 329.6]]
	var step := 60.0 / 112.0 / 2.0
	var index := 0
	while index < count:
		var end := mini(index + 4000, count)
		for i: int in range(index, end):
			var t := float(i) / MUSIC_RATE
			var chord: Array = chords[int(t / 4.0) % chords.size()]
			var note: float = chord[int(t / step) % chord.size()] * (2.0 if int(t / step / 3.0) % 2 == 1 else 1.0)
			var local := fmod(t, step)
			var arp := 0.18 * _square(note, t) * exp(-local * 7.0)
			var root: float = chord[0] / 4.0
			var drone := 0.22 * sin(TAU * root * t) + 0.08 * sin(TAU * root * 2.003 * t)
			var pulse := 0.06 * sin(TAU * 40.0 * t) * exp(-fmod(t, step * 2.0) * 10.0)
			data.encode_s16(i * 2, int(clampf(arp + drone + pulse, -1.0, 1.0) * 26000.0))
		index = end
		await get_tree().process_frame
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -17.0
	add_child(_music)
	if enabled:
		_music.play()


static func _square(frequency: float, t: float) -> float:
	return 1.0 if fmod(t * frequency, 1.0) < 0.5 else -1.0


## Bit-crush: fewer amplitude steps for a digital, broken sound.
static func _crush(value: float, bits: int) -> float:
	var steps := float(1 << bits)
	return round(value * steps) / steps
