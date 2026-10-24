class_name EmoteWheel
extends Control

## Radial emote picker opened from the HUD's EMOTE button. Only the KERN
## performs emotes: it dances, says a line (speech hologram + voice) or shows
## a sticker. Which eight emotes sit on the wheel is chosen in
## Sammlung > EMOTE-RAD and saved on the device.

signal picked(emote_id: String)

const KIND_NAMES := {"dance": "TANZ", "voice": "SPRUCH", "sticker": "STICKER"}
const KIND_COLORS := {"dance": Color("7fe3ff"), "voice": Color("e8ffe0"), "sticker": Color("6ee65a")}
## Shared with the server's relay whitelist (server/online/worker.js).
## dance: animation steps [name, seconds] and spins; voice: the spoken line.
const CATALOGUE: Array[Dictionary] = [
	{"id": "dance", "kind": "dance", "text": "DANCE", "steps": [["Dance", 3.0]]},
	{"id": "spin", "kind": "dance", "text": "SPIN", "steps": [["Dance", 2.0]], "spins": 2},
	{"id": "hop", "kind": "dance", "text": "HOP", "steps": [["Jump", 1.2], ["Jump", 1.2]]},
	{"id": "shadowbox", "kind": "dance", "text": "SHADOWBOX", "steps": [["Punch_Jab", 0.6], ["Punch_Cross", 0.7], ["Punch_Jab", 0.6], ["Punch_Cross", 0.8]]},
	{"id": "chill", "kind": "dance", "text": "CHILL", "steps": [["Sitting_Enter", 1.2], ["Sitting_Idle", 1.6], ["Sitting_Exit", 0.9]]},
	{"id": "glitch", "kind": "dance", "text": "GLITCH", "steps": [["Spell_Simple_Enter", 0.4], ["Spell_Simple_Shoot", 0.5], ["Spell_Simple_Shoot", 0.5]], "spins": 1},
	{"id": "twerk", "kind": "dance", "text": "TWERK", "steps": [["Twerk", 3.0]]},
	{"id": "smoke", "kind": "dance", "text": "SMOKE", "steps": [["Smoke", 4.5]]},
	{"id": "laugh", "kind": "dance", "text": "LACHEN", "steps": [["Laugh", 2.5]]},
	{"id": "cheer", "kind": "dance", "text": "JUBEL", "steps": [["Cheer", 2.5]]},
	{"id": "gg", "kind": "voice", "text": "GG", "line": "Good game."},
	{"id": "glhf", "kind": "voice", "text": "GL HF", "line": "Good luck. Have fun."},
	{"id": "e404", "kind": "voice", "text": "ERROR 404", "line": "Error 404. Skill not found."},
	{"id": "lag", "kind": "voice", "text": "LAG?", "line": "Lag detected. Not on my side."},
	{"id": "nice", "kind": "voice", "text": "NICE", "line": "Nice move."},
	{"id": "heat", "kind": "voice", "text": "OVERHEAT", "line": "Warning. System overheating."},
	{"id": "haha", "kind": "sticker", "text": "HAHA"},
	{"id": "what", "kind": "sticker", "text": "?!"},
	{"id": "heart", "kind": "sticker", "text": "<3"},
	{"id": "skull", "kind": "sticker", "text": "x_x"},
	{"id": "fire", "kind": "sticker", "text": "!!!"},
	{"id": "eyes", "kind": "sticker", "text": "O_O"},
]
const SLOT_COUNT: int = 8
const DEFAULT_LOADOUT: Array[String] = ["dance", "gg", "spin", "glhf", "haha", "e404", "chill", "what"]
const PROFILE_PATH := "user://ring_duel_profile.cfg"
const COOLDOWN_SECONDS: float = 3.0
const RADIUS: float = 190.0

var _ready_at: float = 0.0


static func entry(emote_id: String) -> Dictionary:
	for emote: Dictionary in CATALOGUE:
		if emote["id"] == emote_id:
			return emote
	return {}


## The eight emote ids on the wheel, in clockwise order from the top.
static func load_loadout() -> Array[String]:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	var saved: Array = config.get_value("profile", "emote_wheel", [])
	var loadout: Array[String] = DEFAULT_LOADOUT.duplicate()
	for slot: int in range(mini(saved.size(), SLOT_COUNT)):
		if not entry(str(saved[slot])).is_empty():
			loadout[slot] = str(saved[slot])
	return loadout


static func save_loadout(loadout: Array[String]) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("profile", "emote_wheel", loadout)
	config.save(PROFILE_PATH)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(shade)


func open() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ready_at:
		return
	for child: Node in get_children():
		if child is Button or child is Label:
			child.queue_free()
	var center := get_viewport_rect().size * Vector2(0.5, 0.45)
	var hint := Label.new()
	hint.text = "Belegung: Sammlung > EMOTE-RAD"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", TerminalTheme.GREEN_DIM)
	add_child(hint)
	hint.position = center + Vector2(-hint.get_minimum_size().x / 2.0, RADIUS + 70.0)
	var loadout := load_loadout()
	for index: int in range(loadout.size()):
		var emote := entry(loadout[index])
		var angle := -PI / 2.0 + TAU * index / loadout.size()
		var button := Button.new()
		button.text = emote["text"]
		button.add_theme_font_size_override("font_size", 28)
		button.add_theme_color_override("font_color", KIND_COLORS[emote["kind"]])
		button.custom_minimum_size = Vector2(150.0, 58.0)
		add_child(button)
		button.size = button.custom_minimum_size
		var target := center + Vector2.from_angle(angle) * RADIUS - button.size / 2.0
		button.position = center - button.size / 2.0
		button.modulate.a = 0.0
		# Buttons fly out from the centre like a radial menu unfolding.
		var tween := button.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position", target, 0.22).set_delay(index * 0.02)
		tween.tween_property(button, "modulate:a", 1.0, 0.18).set_delay(index * 0.02)
		button.pressed.connect(_choose.bind(emote["id"]))
	visible = true
	SoundBoard.play("click")


func close() -> void:
	visible = false


func _choose(emote_id: String) -> void:
	close()
	_ready_at = Time.get_ticks_msec() / 1000.0 + COOLDOWN_SECONDS
	picked.emit(emote_id)
