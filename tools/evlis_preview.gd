extends SceneTree

## Renders Evlis' showcase pose at a few moments of the "Cool" loop into
## logs/evlis_preview/. Run it after every change to the cigarette or arms:
##   Godot_console.exe --path . --resolution 720x720 --script res://tools/evlis_preview.gd
## Close-up on the head and hands; the drag happens between 8.5 and 12 seconds.
const TIMES: Array[float] = [9.5, 10.0, 10.7, 11.4]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://logs/evlis_preview/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fighter := FighterSprite.new()
	root.add_child(fighter)
	fighter.build(CharacterRoster.character("evlis"), Color("ff8a3c"), 0.0, false)
	fighter.viewport.size = Vector2i(720, 720)
	fighter.turn = 0.4
	fighter.camera.rotation_degrees.x = 0.0
	fighter.camera.size = 0.8
	fighter.camera.position = Vector3(0.0, 1.05, 4.0)
	var model := fighter.model as BoneFighterModel
	model.show_cool_pose()
	await create_timer(0.3).timeout
	model.animation_player.pause()
	for index: int in range(TIMES.size()):
		model.animation_player.seek(TIMES[index], true)
		# Seeking skips the method tracks; set what they would have set.
		model.cigarette_in_hand(TIMES[index] >= 9.3 and TIMES[index] < 11.0)
		await create_timer(0.4).timeout
		var path := out_dir + "pose_%d_at_%.1fs.png" % [index, TIMES[index]]
		fighter.viewport.get_texture().get_image().save_png(path)
		print("Saved ", path)
	quit()
