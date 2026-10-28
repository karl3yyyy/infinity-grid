extends SceneTree

## Saves screenshots of menu pages into logs/screens/:
##   Godot_console.exe --path . --resolution 720x1280 --script res://tools/screenshot_views.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://logs/screens/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	TutorialProgress._store_flag()
	var main_scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await create_timer(4.0).timeout
	var menu := (main_scene.get_node("BattleManager") as GridBattleManager).battle_ui.main_menu
	menu.account.code = "TEST"
	menu.account.account = {"credits": 1250, "owned": ["skin:agent_red"], "shop": {"daily": ["character:baby"], "weekly": ["skin:agent_red", "skin:wired_ice", "echo:agents", "cards:lava", "character:doc"], "daily_ends": (Time.get_unix_time_from_system() + 27000.0) * 1000.0, "weekly_ends": (Time.get_unix_time_from_system() + 200000.0) * 1000.0}, "packs": [
		{"id": "s", "credits": 500, "label": "4,99 €"}, {"id": "m", "credits": 1200, "label": "9,99 €"}, {"id": "l", "credits": 3000, "label": "19,99 €"}]}
	menu._shop.show_shop()
	await create_timer(0.5).timeout
	menu._shop.show_shop()
	await create_timer(3.0).timeout
	root.get_viewport().get_texture().get_image().save_png(out_dir + "shop.png")
	menu._content.get_child(menu._content.get_child_count() - 2).get_child(0).scroll_vertical = 700
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out_dir + "shop2.png")
	await create_timer(2.5).timeout
	quit()
