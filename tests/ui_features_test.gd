extends SceneTree

const EncyclopediaScript := preload("res://scripts/ui/card_encyclopedia.gd")
const MatchReplayScript := preload("res://scripts/ui/match_replay.gd")
const NetworkMatchScript := preload("res://scripts/battle/network_match.gd")
const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var cards := MovementCard.create_deck()
	var encyclopedia: CardEncyclopedia = EncyclopediaScript.new(cards)
	root.add_child(encyclopedia)
	await process_frame
	_expect(encyclopedia._selected == cards[0], "The card encyclopedia starts with an example card selected")
	encyclopedia._select_card(cards[1])
	_expect(encyclopedia._selected == cards[1], "Selecting a card updates the interactive example")
	_expect(cards[1].description().contains("vorne"), "Movement cards provide a readable German description")
	var demo: CardDemoBoard = encyclopedia._demo_board
	demo.size = Vector2(250.0, 250.0)
	var touch := InputEventMouseButton.new()
	touch.button_index = MOUSE_BUTTON_LEFT
	touch.pressed = true
	touch.position = Vector2(25.0, 25.0)
	demo._gui_input(touch)
	_expect(demo.origin == Vector2i(0, 0), "Tapping the preview board moves the demonstration figure")

	var history: Array[Dictionary] = [
		{
			"action": {"type": "start", "team": 0},
			"pieces": [{"team": 0, "master": true, "cell": Vector2i(2, 4)}],
			"hands": [["Shell", "Crane"], ["Pulse", "Echo"]],
			"pass_card": "Orbit", "tiles": PackedInt32Array(), "round": 1, "side_to_move": 0,
		},
		{
			"action": {
				"type": "move", "team": 0, "from": Vector2i(2, 4), "to": Vector2i(2, 3),
				"played_card": "Shell", "received_card": "Orbit",
			},
			"pieces": [{"team": 0, "master": true, "cell": Vector2i(2, 3)}],
			"hands": [["Orbit", "Crane"], ["Pulse", "Echo"]],
			"pass_card": "Shell", "tiles": PackedInt32Array(), "round": 1, "side_to_move": 1,
		},
	]
	var replay: MatchReplay = MatchReplayScript.new()
	root.add_child(replay)
	await process_frame
	replay.open(history)
	_expect(replay.visible and replay._selected_index == 1, "The replay opens at the latest recorded turn")
	replay._step(-1)
	_expect(replay._selected_index == 0, "The replay can step back through prior positions")
	_expect(replay._cards_label.text.contains("Shell"), "The replay shows the cards and exchanged middle card")
	replay._step(1)
	_expect(replay._board._snapshot["pieces"][0]["cell"] == Vector2i(2, 3), "The replay board follows the selected historical position")
	replay.close()
	_expect(not replay.visible, "Closing replay returns to the unchanged match")

	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var grid := main.get_node_or_null("BattleScene/GridManager") as GridManager
	var battle := main.get_node_or_null("BattleManager") as GridBattleManager
	if grid != null and battle != null:
		var attacking_master: BattleUnit = battle.players[2]
		var defending_master: BattleUnit = battle.enemies[2]
		grid.remove_occupant(attacking_master.grid_position, attacking_master)
		grid.remove_occupant(defending_master.grid_position, defending_master)
		attacking_master.grid_position = Vector2i(2, 2)
		defending_master.grid_position = Vector2i(2, 1)
		grid.set_occupant(attacking_master.grid_position, attacking_master)
		grid.set_occupant(defending_master.grid_position, defending_master)
		battle.hands[0][0] = MovementCard.new("Kernschlag-Test", [Vector2i(0, 1)])
		battle.pass_card = MovementCard.new("Wechsel-Test", [Vector2i(1, 0)])
		battle.current_player = 0
		battle.input_locked = false
		battle.selected_card_slot = 0
		battle.bot_opponent_enabled = false
		battle.match_mode = "local"
		battle.hands[1][0] = MovementCard.new("Gegnerischer Schlag-Test", [Vector2i(0, 1)])
		battle._refresh_core_threat_warning()
		_expect(battle.battle_ui.has_core_threat_warning(), "A legal enemy Master capture warns the threatened side")
		var ranked_match: NetworkMatch = NetworkMatchScript.new()
		ranked_match.ranked = true
		battle.match_mode = "network"
		battle.network_match = ranked_match
		battle._refresh_core_threat_warning()
		_expect(not battle.battle_ui.has_core_threat_warning(), "Ranked matches do not show the incoming Master capture warning")
		battle.match_mode = "local"
		battle.network_match = null
		ranked_match.free()
		battle._select_unit(attacking_master)
		_expect(battle.battle_ui.has_capture_warning(), "A legal Master capture raises a visible warning")
		_expect(grid.cells[Vector2i(2, 1)].highlight == GridCell.Highlight.WIN, "A winning destination has a distinct gold highlight")
		battle.match_history.clear()
		battle._record_match_history({"type": "start", "team": 0})
		await battle._perform_move(defending_master.grid_position)
		_expect(battle.match_history.size() == 2, "The match records its initial state and completed turn")
		var last_action: Dictionary = battle.match_history.back().get("action", {})
		_expect(last_action.get("played_card", "") == "Kernschlag-Test" and last_action.get("received_card", "") == "Wechsel-Test", "The move history records both exchanged cards")
		var live_position := attacking_master.grid_position
		var live_hand: Array = battle.hands[0].duplicate()
		var live_pass := battle.pass_card
		battle._show_match_history()
		_expect(battle.battle_ui.match_replay.visible, "The in-match control opens the move replay")
		battle.battle_ui.match_replay._step(-1)
		battle.battle_ui.match_replay._step(1)
		_expect(attacking_master.grid_position == live_position and battle.hands[0] == live_hand and battle.pass_card == live_pass, "Replay navigation does not mutate the live board or cards")
		battle.battle_ui.match_replay.close()
	if failures.is_empty():
		print("UI FEATURE TESTS PASSED")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)
