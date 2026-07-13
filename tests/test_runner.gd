extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const AttackActionScript := preload("res://scripts/battle/attack_action.gd")
const RangedAttackActionScript := preload("res://scripts/battle/ranged_attack_action.gd")
const HealActionScript := preload("res://scripts/battle/heal_action.gd")
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
	_expect(attack.calculate_damage(attacker, target) == 4, "Damage formula uses attack minus defense")
	target.defense = 99
	_expect(attack.calculate_damage(attacker, target) == 1, "Damage formula has minimum one")
	attacker.free()
	target.free()
	attack.free()

	if grid != null:
		var swordsman: BattleUnit = PlayerUnitScript.new()
		swordsman.setup_player("Melee Test", Vector2i(0, 0), UnitClassData.UnitClass.SWORDSMAN)
		var melee_target: BattleUnit = EnemyUnitScript.new()
		melee_target.setup_enemy("Melee Target", Vector2i(0, 1), UnitClassData.UnitClass.SWORDSMAN)
		var melee_action: AttackAction = AttackActionScript.new()
		_expect(melee_action.can_attack(swordsman, melee_target, grid), "Swordsman melee attack")

		var archer: BattleUnit = PlayerUnitScript.new()
		archer.setup_player("Archer Test", Vector2i(0, 0), UnitClassData.UnitClass.ARCHER)
		var ranged_target: BattleUnit = EnemyUnitScript.new()
		ranged_target.setup_enemy("Range Target", Vector2i(0, 1), UnitClassData.UnitClass.SWORDSMAN)
		var ranged_action: RangedAttackAction = RangedAttackActionScript.new()
		main.add_child(ranged_action)
		_expect(not ranged_action.can_attack(archer, ranged_target, grid), "Archer minimum range")
		ranged_target.grid_position = Vector2i(0, 5)
		_expect(
			ranged_action.can_attack(archer, ranged_target, grid)
			and not _can_ranged_at(ranged_action, archer, ranged_target, grid, Vector2i(0, 6)),
			"Archer maximum range"
		)
		_expect(not grid.has_line_of_sight(Vector2i(4, 2), Vector2i(4, 6)), "Line of sight blocking")

		main.add_child(archer)
		main.add_child(ranged_target)
		archer.position = grid.grid_to_world(archer.grid_position)
		ranged_target.grid_position = Vector2i(0, 2)
		ranged_target.position = grid.grid_to_world(ranged_target.grid_position)
		await process_frame
		var hp_before_arrow := ranged_target.current_hp
		ranged_action.execute(archer, ranged_target, grid)
		_expect(ranged_target.current_hp == hp_before_arrow, "Arrow damage waits for impact")
		await create_timer(1.1).timeout
		_expect(
			ranged_action.damage_applied_on_last_impact and ranged_target.current_hp < hp_before_arrow,
			"Arrow impact applies damage"
		)

		var healer: BattleUnit = EnemyUnitScript.new()
		healer.setup_enemy("Healer Test", Vector2i(1, 1), UnitClassData.UnitClass.PRIEST)
		var enemy_of_healer: BattleUnit = PlayerUnitScript.new()
		enemy_of_healer.setup_player("Enemy of Healer", Vector2i(1, 2), UnitClassData.UnitClass.SWORDSMAN)
		enemy_of_healer.current_hp -= 3
		var healing_action: HealAction = HealActionScript.new()
		_expect(not healing_action.can_heal(healer, enemy_of_healer, grid), "Priest cannot heal enemies")
		var dead_ally: BattleUnit = EnemyUnitScript.new()
		dead_ally.setup_enemy("Dead Ally", Vector2i(2, 1), UnitClassData.UnitClass.SWORDSMAN)
		dead_ally.is_dead = true
		dead_ally.current_hp = 0
		_expect(not healing_action.can_heal(healer, dead_ally, grid), "Priest cannot heal dead units")
		var wounded_ally: BattleUnit = EnemyUnitScript.new()
		wounded_ally.setup_enemy("Wounded Ally", Vector2i(2, 1), UnitClassData.UnitClass.SWORDSMAN)
		wounded_ally.current_hp = wounded_ally.max_hp - 2
		var restored := wounded_ally.apply_healing(healer.heal_power)
		_expect(restored == 2 and wounded_ally.current_hp == wounded_ally.max_hp, "Priest healing does not exceed max HP")

		var enemy_ai: EnemyController = main.get_node_or_null("EnemyController") as EnemyController
		var low_ally: BattleUnit = EnemyUnitScript.new()
		low_ally.setup_enemy("Low Ally", Vector2i(3, 3), UnitClassData.UnitClass.SWORDSMAN)
		low_ally.current_hp = 2
		var higher_ally: BattleUnit = EnemyUnitScript.new()
		higher_ally.setup_enemy("Higher Ally", Vector2i(3, 4), UnitClassData.UnitClass.SWORDSMAN)
		higher_ally.current_hp = 9
		var ai_allies: Array[BattleUnit] = [healer, higher_ally, low_ally]
		_expect(enemy_ai._lowest_health_ratio_ally(healer, ai_allies) == low_ally, "AI priest prioritizes lowest health ratio")
		var preferred_score := enemy_ai.score_ranged_position(Vector2i(0, 0), Vector2i(0, 3), 2, 5, 3)
		var close_score := enemy_ai.score_ranged_position(Vector2i(0, 2), Vector2i(0, 3), 2, 5, 3)
		_expect(preferred_score > close_score, "AI archer keeps ranged distance")

		var glb_paths: Array[String] = [
			"res://assets/characters/player/player_swordsman.glb",
			"res://assets/characters/player/player_archer.glb",
			"res://assets/characters/player/player_priest.glb",
			"res://assets/characters/enemy/enemy_swordsman.glb",
			"res://assets/characters/enemy/enemy_archer.glb",
			"res://assets/characters/enemy/enemy_priest.glb",
		]
		var all_glbs_load := glb_paths.all(func(path: String) -> bool:
			return ResourceLoader.exists(path) and load(path) is PackedScene
		)
		_expect(all_glbs_load, "GLB character resources load")
		var required_animation_keys: Array[StringName] = [&"idle", &"walk", &"slash", &"ranged", &"cast", &"heal", &"hit", &"death"]
		var battle_units: Array[BattleUnit] = []
		battle_units.append_array(battle.players)
		battle_units.append_array(battle.enemies)
		var animation_maps_resolve := true
		for battle_unit: BattleUnit in battle_units:
			animation_maps_resolve = animation_maps_resolve and battle_unit.using_licensed_model
			for animation_key: StringName in required_animation_keys:
				animation_maps_resolve = animation_maps_resolve and battle_unit.has_imported_animation(animation_key)
		_expect(animation_maps_resolve, "Animation mappings resolve to imported clips")

		var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
		_expect('name="Windows Desktop"' in presets, "Windows preset exists")
		_expect('name="Web Single-Threaded"' in presets, "Web preset exists")
		_expect('name="Android APK"' in presets, "Android preset exists")
		var license_files: Array[String] = [
			"res://assets/licenses/KayKit-Adventurers-CC0.txt",
			"res://assets/licenses/KayKit-Skeletons-CC0.txt",
			"res://assets/licenses/KayKit-Dungeon-Remastered-CC0.txt",
			"res://assets/licenses/KayKit-Fantasy-Weapons-Bits-CC0.txt",
			"res://assets/licenses/Kenney-Nature-Kit-CC0.txt",
			"res://assets/licenses/Poly-Haven-Cloud-Layers-CC0.txt",
		]
		var licenses_complete := FileAccess.file_exists("res://THIRD_PARTY_ASSETS.md") and license_files.all(func(path: String) -> bool:
			return FileAccess.file_exists(path) and "CC0" in FileAccess.get_file_as_string(path)
		)
		_expect(licenses_complete, "All third-party assets have license records")

		var touch_controller: PlayerController = main.get_node_or_null("PlayerController") as PlayerController
		var camera: CameraController = main.get_node_or_null("CameraController") as CameraController
		touch_controller.cell_click_emission_count = 0
		touch_controller.mouse_suppressed_until_msec = 0
		var touch_position := camera.unproject_position(battle.players[0].global_position)
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 0
		touch_down.position = touch_position
		touch_down.pressed = true
		touch_controller._input(touch_down)
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 0
		touch_up.position = touch_position
		touch_up.pressed = false
		touch_controller._input(touch_up)
		var emulated_mouse := InputEventMouseButton.new()
		emulated_mouse.position = touch_position
		emulated_mouse.button_index = MOUSE_BUTTON_LEFT
		emulated_mouse.pressed = true
		touch_controller._input(emulated_mouse)
		_expect(touch_controller.cell_click_emission_count == 1 and touch_controller.is_mouse_event_suppressed(), "Touch input does not duplicate mouse input")

		swordsman.free()
		melee_target.free()
		melee_action.free()
		archer.free()
		ranged_target.free()
		ranged_action.free()
		healing_action.free()
		healer.free()
		enemy_of_healer.free()
		dead_ally.free()
		wounded_ally.free()
		low_ally.free()
		higher_ally.free()

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


func _can_ranged_at(
	action: RangedAttackAction,
	attacker: BattleUnit,
	target: BattleUnit,
	grid: GridManager,
	coordinate: Vector2i
) -> bool:
	target.grid_position = coordinate
	return action.can_attack(attacker, target, grid)
