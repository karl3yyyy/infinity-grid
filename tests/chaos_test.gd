extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	seed(20261025)
	_test_rules()
	_test_bot()
	_test_effects()
	await _test_match_flow()
	if failures.is_empty():
		print("CHAOS TESTS PASSED")
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAILED: ", failure)
		quit(1)


func _test_rules() -> void:
	var rules := ChaosRules.new()
	rules.shifting_tiles = true
	rules.set_king(0, Vector2i(2, 4))
	rules.piece_moved(0, Vector2i(2, 4), Vector2i(2, 3))
	_expect(rules.is_king_at(0, Vector2i(2, 3)) and not rules.is_king_at(0, Vector2i(2, 4)), "King cell follows its piece")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var first := rules.advance_round(1, Vector2i(5, 5), rng)
	_expect(first["warned"].is_empty(), "No tile is warned before round 2")
	var second := rules.advance_round(2, Vector2i(5, 5), rng)
	_expect(second["warned"].size() == ChaosRules.WARNED_PER_ROUND and rules.collapsed.is_empty(), "Round 2 only warns tiles")
	var third := rules.advance_round(3, Vector2i(5, 5), rng)
	_expect(third["collapsed"].size() == ChaosRules.WARNED_PER_ROUND, "Warned tiles collapse one round later")
	for cell: Vector2i in third["collapsed"]:
		_expect(rules.is_blocked(cell), "A collapsed tile is blocked")
	for round_number: int in range(4, 40):
		rules.advance_round(round_number, Vector2i(5, 5), rng)
		_expect(rules.collapsed.size() + rules.warned.size() <= ChaosRules.MAX_COLLAPSED, "Never more than %d tiles are out" % ChaosRules.MAX_COLLAPSED)
	var calm := ChaosRules.new()
	_expect(calm.advance_round(5, Vector2i(5, 5), rng)["warned"].is_empty(), "Tiles stay put without the shifting option")
	var occupied := ChaosRules.new()
	occupied.shifting_tiles = true
	var held_cells := {Vector2i(0, 0): true, Vector2i(2, 2): true}
	var warning := occupied.advance_round(2, Vector2i(5, 5), rng, held_cells)
	_expect(warning["warned"].all(func(cell: Vector2i) -> bool: return not held_cells.has(cell)), "New warnings do not appear under pieces already on the board")


func _test_bot() -> void:
	var bot := ChaosBot.new()
	var card := MovementCard.new("Step", [Vector2i(0, 1)] as Array[Vector2i])
	var own: Array[Vector2i] = [Vector2i(2, 1)]
	var enemy: Array[Vector2i] = [Vector2i(2, 0)]
	var result := bot.choose_move(0, own, enemy, Vector2i(-1, -1), [card], [], {}, {}, 5)
	_expect(result.get("to", Vector2i(-9, -9)) == Vector2i(2, 0), "Bot captures when it can")
	var blocked := {Vector2i(2, 0): 2}
	result = bot.choose_move(0, own, enemy, Vector2i(-1, -1), [card], [], blocked, {}, 5)
	_expect(result.has("pass"), "Bot passes when the only target is collapsed")


func _test_effects() -> void:
	var board := Vector2i(5, 5)
	var own: Array[Vector2i] = [Vector2i(2, 2), Vector2i(0, 4)]
	var enemy: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 1)]
	var strike := CardEffect.targets(CardEffect.Kind.STRIKE, Vector2i(2, 2), 0, board, own, enemy, {}, {})
	_expect(strike.size() == 2 and Vector2i(3, 2) in strike, "Strike aims at adjacent enemies")
	_expect(CardEffect.targets(CardEffect.Kind.STRIKE, Vector2i(2, 2), 0, board, own, enemy, {}, {Vector2i(3, 2): 1}).size() == 1, "A shielded piece cannot be struck")
	var push := CardEffect.targets(CardEffect.Kind.PUSH, Vector2i(2, 2), 0, board, own, enemy, {Vector2i(4, 2): 2}, {})
	_expect(push.size() == 1 and push[0] == Vector2i(2, 1), "A push needs a free, standing tile behind the enemy")
	_expect(CardEffect.neighbour(Vector2i(0, 3), Vector2i(-1, 0), board) == Vector2i(4, 3), "Effects wrap horizontally")
	_expect(CardEffect.neighbour(Vector2i(0, 0), Vector2i(0, -1), board).x < 0, "Effects stop at the closed top edge")
	var swap := CardEffect.targets(CardEffect.Kind.SWAP, Vector2i(2, 2), 0, board, own, enemy, {}, {})
	_expect(swap.size() == 1 and swap[0] == Vector2i(0, 4), "Swap aims at other own pieces")
	var rules := ChaosRules.new()
	rules.protected[Vector2i(1, 1)] = 0
	rules.piece_moved(0, Vector2i(1, 1), Vector2i(1, 2))
	_expect(rules.protected.has(Vector2i(1, 2)) and not rules.protected.has(Vector2i(1, 1)), "A shield follows its piece")
	rules.expire_protection(0)
	_expect(rules.protected.is_empty(), "A shield ends when its owner's turn begins")
	var shield_bot := ChaosBot.new()
	var kinds: Array = [CardEffect.Kind.STRIKE]
	var card := MovementCard.new("Step", [Vector2i(0, 5)] as Array[Vector2i])
	var result := shield_bot.choose_move(0, own, enemy, Vector2i(-1, -1), [card], [], {}, {}, 5, kinds, {})
	_expect(result.has("effect"), "Bot uses a strike when one is available")


func _test_match_flow() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var battle := main.get_node("BattleManager") as GridBattleManager
	var ui := main.get_node("BattleUI") as GridBattleUI
	ui.main_menu.chaos_requested.emit({"hidden_king": true, "shifting_tiles": true, "card_effects": true})
	await process_frame
	_expect(battle.chaos != null and battle.chaos.shifting_tiles, "Chaos match starts with shifting tiles")
	_expect(battle.match_mode == "chaos", "Match mode remembers the variant for rematches")
	var masters := 0
	for unit: BattleUnit in battle.players + battle.enemies:
		masters += 1 if unit.is_master else 0
	_expect(masters == 0, "No piece carries the visible KERN look")
	_expect(battle.chaos.king_cells[1] != Vector2i(-1, -1), "The bot picked a secret king")
	battle._choosing_king = true
	battle.chaos_king_chosen.connect(func() -> void: pass)
	battle._pick_king(Vector2i(0, 4))
	_expect(battle.chaos.is_king_at(0, Vector2i(0, 4)) and not battle._choosing_king, "Player chooses a king among their pieces")
	battle.chaos.set_king(1, Vector2i(2, 0))
	battle.battle_over = false
	var victim := battle.grid_manager.get_unit_at(Vector2i(2, 0)) as BattleUnit
	_expect(battle.chaos.is_king_at(victim.team_id, Vector2i(2, 0)), "Capturing the secret king cell identifies the king")
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
