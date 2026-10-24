class_name EmoteStage
extends RefCounted

## Plays an emote on a KERN: dances animate the fighter itself, lines appear
## as a speech hologram and are spoken, stickers flicker up as a hologram.
## Purely visual; the match state is never touched.


static func perform(parent: Node3D, kern: BattleUnit, team: int, emote_id: String) -> void:
	var emote := EmoteWheel.entry(emote_id)
	if emote.is_empty() or kern == null or kern.is_dead:
		return
	SoundBoard.play("emote")
	match str(emote["kind"]):
		"dance":
			if kern.rig != null:
				kern.rig.perform(emote["steps"], int(emote.get("spins", 0)))
		"voice":
			SoundBoard.speak(emote["line"])
			_hologram(parent, kern, '"%s"' % emote["line"], Color("e8ffe0"), 64, 2.6)
			if kern.rig != null:
				kern.rig.perform([["Idle_Talking", 2.4]])
		_:
			_hologram(parent, kern, emote["text"], OnitamaUI.TEAM_COLORS[team].lightened(0.35), 110, 2.0)


## Glitchy hologram above the KERN: flicker in, hover up, flicker out.
static func _hologram(parent: Node3D, kern: BattleUnit, text: String, color: Color, font_size: int, seconds: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = TerminalTheme.font()
	label.font_size = font_size
	label.outline_size = 18
	label.pixel_size = 0.006
	label.width = 900.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.85)
	parent.add_child(label)
	label.global_position = kern.global_position + Vector3(0.0, 2.6, 0.0)
	var tween := label.create_tween()
	for flicker: int in range(3):
		tween.tween_property(label, "modulate:a", 0.2, 0.05)
		tween.tween_property(label, "modulate:a", 1.0, 0.05)
	tween.tween_property(label, "position:y", label.position.y + 0.4, seconds)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
