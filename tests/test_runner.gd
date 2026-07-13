extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const AttackActionScript := preload("res://scripts/battle/attack_action.gd")
const PlayerUnitScript := preload("res://scripts/units/player_unit.gd")
const EnemyUnitScript := preload("res://scripts/units/enemy_unit.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var grid: GridManager = main.get_node_or_null("BattleScene/GridManager") as GridManager
	var battle: BattleManager = main.get_node_or_null("BattleManager") as BattleManager
	_expect(grid != null, "GridManager exists")
	_expect(battle != null, "BattleManager exists")
	if grid != null:
		_expect(grid.cells.size() == 100, "Grid contains 100 cells")
		_expect(not grid.cells[Vector2i(4, 4)].walkable, "Obstacle cell is blocked")
		var reachable := grid.get_reachable(Vector2i(0, 0), 3)
		_expect(Vector2i(2, 1) in reachable, "BFS includes reachable coordinate")
		_expect(Vector2i(4, 4) not in reachable, "BFS excludes obstacle")
		var path := grid.find_path(Vector2i(0, 0), Vector2i(3, 0))
		_expect(path.size() == 4, "Pathfinder returns shortest path")
	if battle != null:
		_expect(battle.players.size() == 3, "Three player units spawned")
		_expect(battle.enemies.size() == 3, "Three enemy units spawned")
		_expect(battle.players[0].grid_position is Vector2i, "Unit position is authoritative Vector2i")
		var camera: CameraController = main.get_node_or_null("CameraController") as CameraController
		if camera != null:
			await create_timer(0.45).timeout
			var click_position := camera.unproject_position(battle.players[0].global_position)
			var click_event := InputEventMouseButton.new()
			click_event.position = click_position
			click_event.global_position = click_position
			click_event.button_index = MOUSE_BUTTON_LEFT
			click_event.pressed = true
			var player_input: PlayerController = main.get_node_or_null("PlayerController") as PlayerController
			_expect(player_input._screen_to_grid(click_position) == battle.players[0].grid_position, "Camera ray maps to the unit grid coordinate")
			player_input._input(click_event)
			await process_frame
			_expect(battle.selected_unit == battle.players[0], "Mouse projection selects a player unit")

	var attacker: BattleUnit = PlayerUnitScript.new()
	attacker.setup_player("Test Player", Vector2i.ZERO)
	var target: BattleUnit = EnemyUnitScript.new()
	target.setup_enemy("Test Enemy", Vector2i.RIGHT)
	var attack: AttackAction = AttackActionScript.new()
	_expect(attack.calculate_damage(attacker, target) == 5, "Damage formula uses attack minus defense")
	target.defense = 99
	_expect(attack.calculate_damage(attacker, target) == 1, "Damage formula has minimum one")
	attacker.free()
	target.free()
	attack.free()

	if battle != null:
		battle._finish_battle(false)
		var ui: BattleUI = main.get_node_or_null("BattleUI") as BattleUI
		_expect(battle.turn_manager.state == TurnManager.BattleState.DEFEAT, "All-player defeat state is available")
		_expect(ui.result_overlay.visible and ui.result_label.text == "DEFEAT", "Defeat overlay is shown")

	if failures.is_empty():
		print("TEST RESULT: PASS (all core assertions succeeded)")
		main.queue_free()
		await process_frame
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
		main.queue_free()
		await process_frame
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append("FAIL: %s" % description)
