class_name SoundBoard
extends Node

## All sound in the game, synthesised at start-up (SoundSynth) so no audio files ship:
## effects (boot hum, glitch snap, clicks, combat), a looping synth track and
## the design bible's voice lines through the device's text-to-speech.
## Everything else calls the static helpers; they do nothing until the board
## exists and while sound is switched off.

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
var _music_tween: Tween
var _danger_mode: bool = false


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


static func set_danger_mode(enabled: bool) -> void:
	if _board != null:
		_board._set_danger_mode(enabled)


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
	_streams = SoundSynth.effects()
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


func _build_music() -> void:
	var stream := await SoundSynth.build_music(get_tree())
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -10.0 if _danger_mode else -14.0
	_music.pitch_scale = 1.08 if _danger_mode else 1.0
	add_child(_music)
	if enabled:
		_music.play()


func _set_danger_mode(enabled: bool) -> void:
	if _danger_mode == enabled:
		return
	_danger_mode = enabled
	if enabled:
		_play("glitch", -18.0)
	if _music == null:
		return
	if _music_tween != null and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(_music, "volume_db", -10.0 if enabled else -14.0, 1.1)
	_music_tween.tween_property(_music, "pitch_scale", 1.08 if enabled else 1.0, 1.1)
