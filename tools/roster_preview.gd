extends SceneTree

## Renders the given character ids side by side (full body and portrait) into logs/screens/roster.png.
##   Godot_console.exe --path . --script res://tools/roster_preview.gd -- catknight fish


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var ids := OS.get_cmdline_user_args()
	var row := HBoxContainer.new()
	root.add_child(row)
	for id: String in ids:
		var character := CharacterRoster.character(id)
		var fighter := FighterSprite.new()
		root.add_child(fighter)
		fighter.build(character, Color("6ee65a"), 0.0, false)
		var picture := TextureRect.new()
		picture.texture = fighter.viewport.get_texture()
		picture.custom_minimum_size = Vector2(240, 336)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(picture)
		var portrait := AvatarGallery.portrait("character:" + id, root)
		var face := TextureRect.new()
		face.texture = portrait.viewport.get_texture()
		face.custom_minimum_size = Vector2(240, 240)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(face)
	await create_timer(4.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/screens/"))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://logs/screens/roster.png"))
	quit()
