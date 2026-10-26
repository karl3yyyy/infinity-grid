extends SceneTree

const EncyclopediaScript := preload("res://scripts/ui/card_encyclopedia.gd")
const MatchReplayScript := preload("res://scripts/ui/match_replay.gd")
const NetworkMatchScript := preload("res://scripts/battle/network_match.gd")
const TutorialDirectorScript := preload("res://scripts/battle/tutorial_director.gd")
const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_expect(
		TutorialDirectorScript.NODE_PING_INTRO.size() == 1
		and TutorialDirectorScript.NODE_PING_INTRO[0].contains("Node Ping")
		and TutorialDirectorScript.NODE_PING_INTRO[0].contains("Gleichstand"),
		"The tutorial briefly explains the Node Ping before dealing cards"
	)
	_expect(
		TutorialDirectorScript.MENU_RECAP.size() == 3
		and TutorialDirectorScript.MENU_RECAP[0].contains("5×5")
		and TutorialDirectorScript.MENU_RECAP[1].contains("passen")
		and TutorialDirectorScript.MENU_RECAP[2].contains("Ranked")
		and TutorialDirectorScript.MENU_RECAP[2].contains("Chaos")
		and TutorialDirectorScript.MENU_RECAP[2].contains("Finite Grid"),
		"The tutorial returns to the main menu and teases Ranked, Chaos and Finite Grid"
	)
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
	var stage := main.get_node_or_null("CameraController/CardStage") as CardStage
	var battle_ui := main.get_node("BattleUI") as GridBattleUI
	var menu := battle_ui.main_menu
	menu._login.show_email(true)
	await process_frame
	var login_fields: Array[LineEdit] = []
	for child: Node in menu._content.get_children():
		if child is LineEdit:
			login_fields.append(child)
	_expect(
		login_fields.size() == 2 and login_fields[0].visible and login_fields[1].visible
		and not login_fields[0].has_focus(),
		"Email registration displays both in-game fields without opening a system prompt"
	)
	menu._show_home()
	var emote_button := battle_ui.emote_button
	var emote_wheel := battle_ui.emote_wheel
	_expect(emote_button.custom_minimum_size.x >= 100.0, "The match emote control has enough width for a reliable tap")
	var unit_container: Node3D = main.get_node("BattleScene/Units")
	var emotes_before := unit_container.get_children().filter(func(child: Node) -> bool: return child is Label3D).size()
	emote_button.pressed.emit()
	_expect(emote_wheel.visible, "The match emote button opens its wheel")
	emote_wheel._choose("haha")
	var emotes_after := unit_container.get_children().filter(func(child: Node) -> bool: return child is Label3D).size()
	_expect(emotes_after > emotes_before, "Choosing an emote displays it above the player's KERN")
	battle.current_player = 1
	var bot_turn_emotes_before := unit_container.get_children().filter(func(child: Node) -> bool: return child is Label3D).size()
	battle._on_emote_picked("haha")
	var bot_turn_emotes_after := unit_container.get_children().filter(func(child: Node) -> bool: return child is Label3D).size()
	_expect(
		bot_turn_emotes_after > bot_turn_emotes_before
		and unit_container.get_children().filter(func(child: Node) -> bool: return child is Label3D).back().global_position.distance_to(battle.players[2].global_position + Vector3(0, 2.6, 0)) < 0.1,
		"Emotes in Bot Training stay above the local KERN during the bot's turn"
	)
	if stage != null:
		var opponent_card: Card3D
		for card_node: Card3D in stage._used_nodes():
			if card_node.team_id >= 0 and card_node.team_id != stage._placements[0]["team"]:
				opponent_card = card_node
				break
		if opponent_card != null:
			stage._hovered = opponent_card
			stage._update_hover_states()
			_expect(opponent_card._hover_target, "Hovering an opponent card highlights it")
			stage._hovered = null
			stage._update_hover_states()
			stage._toggle_preview(opponent_card)
			_expect(stage._previewed == opponent_card and opponent_card._hover_target, "Tapping an opponent card opens its enlarged preview")
			stage._toggle_preview(opponent_card)
			_expect(stage._previewed == null and not opponent_card._hover_target, "Tapping a previewed opponent card closes its preview")
		else:
			_expect(false, "The opponent hand has visible preview cards")
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
	main.queue_free()
	await process_frame
	await process_frame
	await _test_tutorial_node_ping()
	if failures.is_empty():
		print("UI FEATURE TESTS PASSED")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_tutorial_node_ping() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var battle := main.get_node("BattleManager") as GridBattleManager
	var stage := main.get_node("CameraController/CardStage") as CardStage
	battle._start_tutorial(false)
	var last_dialog := ""
	var observed_ping := false
	var checked_hidden_cards := false
	var finished_ping := false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not finished_ping:
		if battle.tutorial != null and battle.tutorial._panel.visible and battle.tutorial._next_button.visible:
			var dialog := battle.tutorial._body.text
			if dialog != last_dialog:
				last_dialog = dialog
				battle.tutorial._next_button.pressed.emit()
		var phase := battle.get_node_or_null("PingPhase") as PingPhase
		if phase != null and phase.overlay.is_open():
			observed_ping = true
			if not checked_hidden_cards:
				checked_hidden_cards = true
				_expect(last_dialog == TutorialDirectorScript.NODE_PING_INTRO[0], "The tutorial explains the Node Ping immediately before playing it")
				_expect(stage.state == CardStage.State.HIDDEN, "Tutorial cards stay hidden while the Node Ping is played")
			if phase.overlay._choice_open:
				phase.overlay._finish_choice(0)
			elif phase.overlay._arena.accepting:
				phase.overlay._arena.accepting = false
				phase.overlay._on_spot_tapped(Vector2(0.5, 0.5))
		elif observed_ping and stage.state != CardStage.State.HIDDEN:
			finished_ping = true
			_expect(not battle.pinging, "The tutorial leaves the Node Ping before dealing cards")
			_expect(stage.state == CardStage.State.DEALING, "The card animation starts after the tutorial Node Ping")
			break
		await process_frame
	_expect(observed_ping, "The tutorial launches the playable Node Ping minigame")
	_expect(checked_hidden_cards, "The card deal is gated on completing the Node Ping")
	_expect(finished_ping, "Completing the Node Ping lets the tutorial continue")
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)
