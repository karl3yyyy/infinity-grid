class_name GridBattleManager
extends Node

const PlayerUnitScript := preload("res://scripts/units/player_unit.gd")
const EnemyUnitScript := preload("res://scripts/units/enemy_unit.gd")
const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const BotAIScript := preload("res://scripts/battle/bot_ai.gd")
const NetworkMatchScript := preload("res://scripts/battle/network_match.gd")
const ChaosBotScript := preload("res://scripts/chaos/chaos_bot.gd")
## The same position with the same side to move ends the match in a draw on this count.
const DRAW_REPETITIONS: int = 3

var grid_manager: GridManager
var camera_controller: CameraController
var battle_ui: GridBattleUI
var player_controller: PlayerController
var unit_movement: UnitMovement
var units_parent: Node3D

var players: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var hands: Array = [[], []]
var pass_card: MovementCard
var selected_unit: BattleUnit
var selected_card_slot: int = -1
var movement_targets: Array[Vector2i] = []
var current_player: int = 0
## Who moved first; rounds count from this side. Decided by the Node Ping.
var starting_player: int = 0
## True during the Node Ping; board clicks go to the ping instead.
var pinging: bool = false
var round_number: int = 1
var input_locked: bool = true
var battle_over: bool = false
var bot_opponent_enabled: bool = true
var bot_difficulty: int = BotAI.Difficulty.MEDIUM
## True when no figure of the side to move can use either card; it then gives a card away.
var must_pass: bool = false
## Position key -> how often it occurred, for the repetition draw.
var position_counts: Dictionary = {}
## Team this device controls in a Wi-Fi match; -1 outside of one.
var network_team: int = -1
var network_match: NetworkMatch
## Completed turns (moves and passes) in this match; numbers network turns.
var turns_played: int = 0
## Set in chaos mode (hidden king, optionally shifting tiles); null otherwise.
var chaos: ChaosRules
var _choosing_king: bool = false
var tutorial: TutorialDirector
## Chaos card effects: true while the player aims the card's effect instead of its step.
var _effect_mode: bool = false
signal chaos_king_chosen
## Mode of the running match ("bot", "local", "network"); see _new_match.
var match_mode: String = ""
## Survives the scene reload so "Neue Partie" starts the same mode again.
static var _replay_mode: String = ""
static var _replay_chaos_options: Dictionary = {}
static var _replay_ffa: Array = []
## Cards dealt for this match (hands + pass); the bot indexes into this list.
var match_cards: Array[MovementCard] = []
## Read-only snapshots after each move/pass/effect, including the card exchange.
var match_history: Array[Dictionary] = []
## Look per team: {"character", "echo", "board"} (see CharacterRoster).
var team_looks: Array[Dictionary] = [{}, {}]
## Normal online games: seconds per move, and how many in a row may run out.
const MOVE_SECONDS: float = 30.0
const MAX_TIMEOUTS_IN_A_ROW: int = 3
var turn_timer: TurnTimer
var _timeouts_in_a_row: int = 0
var ffa_battle: FfaBattle


func setup(
	grid: GridManager,
	camera: CameraController,
	ui: GridBattleUI,
	player_input: PlayerController,
	movement: UnitMovement,
	unit_container: Node3D
) -> void:
	grid_manager = grid
	camera_controller = camera
	battle_ui = ui
	battle_ui.set_opponent_bot(bot_opponent_enabled)
	battle_ui.board_insets_changed.connect(camera_controller.set_board_insets)
	var insets := battle_ui.get_board_insets()
	camera_controller.set_board_insets(insets.x, insets.y)
	player_controller = player_input
	unit_movement = movement
	units_parent = unit_container
	grid_manager.intro_started.connect(func() -> void: units_parent.visible = false)
	grid_manager.intro_finished.connect(_beam_in_units)
	turn_timer = TurnTimer.new()
	add_child(turn_timer)
	turn_timer.ticked.connect(battle_ui.set_turn_timer)
	turn_timer.expired.connect(_on_turn_timeout)
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_requested)
	battle_ui.card_selected.connect(_on_card_selected)
	battle_ui.history_requested.connect(_show_match_history)
	battle_ui.bot_training_requested.connect(_start_bot_training)
	battle_ui.tutorial_requested.connect(_start_tutorial.bind(false))
	battle_ui.local_multiplayer_requested.connect(_start_local_multiplayer)
	battle_ui.chaos_requested.connect(_start_chaos)
	battle_ui.effect_requested.connect(_on_effect_requested)
	battle_ui.lan_match_requested.connect(_start_lan_match)
	battle_ui.online_create_requested.connect(_start_online_create)
	battle_ui.online_join_requested.connect(_start_online_join)
	battle_ui.online_quick_requested.connect(_start_online_quick)
	battle_ui.online_ranked_requested.connect(_start_online_ranked)
	battle_ui.emote_picked.connect(_on_emote_picked)
	battle_ui.online_resume_requested.connect(_start_online_resume)
	battle_ui.restart_pressed.connect(_restart_battle)
	battle_ui.new_match_pressed.connect(_new_match)
	battle_ui.quit_pressed.connect(func() -> void: get_tree().quit())
	_deal_cards()
	_spawn_armies()
	_record_position()
	call_deferred("_show_title_menu")


func _deal_cards() -> void:
	var deck := MovementCardScript.draw_match_cards(5)
	match_cards = deck.duplicate()
	hands[0] = [deck[0], deck[1]]
	hands[1] = [deck[2], deck[3]]
	pass_card = deck[4]


func _spawn_armies() -> void:
	for team_id: int in range(2):
		var team: Array[BattleUnit] = players if team_id == 0 else enemies
		for column: int in range(5):
			var is_master := column == 2
			var coordinate := Vector2i(column, 4 if team_id == 0 else 0)
			var display_name := "P%d Master" % (team_id + 1) if is_master else "P%d Student" % (team_id + 1)
			var unit: BattleUnit
			if team_id == 0:
				unit = PlayerUnitScript.new()
				unit.setup_player(display_name, coordinate)
			else:
				unit = EnemyUnitScript.new()
				unit.setup_enemy(display_name, coordinate)
			unit.is_master = is_master
			# Resting figurines look at the player; moves turn them toward the target.
			unit.rest_yaw = FigureFacing.yaw_for(team_id, 0)
			unit.rotation.y = unit.rest_yaw
			unit.scale = Vector3.ONE * (1.08 if is_master else 1.0)
			units_parent.add_child(unit)
			unit.position = grid_manager.grid_to_world(coordinate)
			unit.create_wrap_projections(units_parent, float(grid_manager.grid_size.x) * GridManager.CELL_SIZE)
			team.append(unit)
			grid_manager.set_occupant(coordinate, unit)
			unit.died.connect(_on_unit_died)


func _show_title_menu() -> void:
	if _replay_mode != "":
		var mode := _replay_mode
		_replay_mode = ""
		if mode == "bot":
			_start_bot_training()
		elif mode == "chaos":
			_start_chaos(_replay_chaos_options)
		elif mode == "ffa":
			battle_ui.ffa_requested.emit(int(_replay_ffa[0]), bool(_replay_ffa[1]), bool(_replay_ffa[2]))
		else:
			_start_local_multiplayer()
		return
	# Headless test runs drive the menu themselves.
	if not TutorialProgress.is_done() and DisplayServer.get_name() != "headless":
		_start_tutorial(true)
		return
	input_locked = true
	player_controller.enabled = false
	grid_manager.get_parent().visible = false
	battle_ui.main_menu.open_menu(false)
	camera_controller.set_player_view(0)
	_refresh_ui()
	battle_ui.set_instruction("Wähle einen Spielmodus.")


## Practice match with fixed cards and no Node Ping; Doc Voss guides the player.
func _start_tutorial(mandatory: bool) -> void:
	if battle_over:
		return
	_apply_match_looks(0)
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	match_mode = "bot"
	bot_opponent_enabled = true
	bot_difficulty = BotAI.Difficulty.EASY
	battle_ui.set_opponent_bot(true, BotAI.label_for(bot_difficulty))
	var dealt := TutorialDirector.cards()
	match_cards.assign(dealt)
	hands[0] = [dealt[0], dealt[1]]
	hands[1] = [dealt[2], dealt[3]]
	pass_card = dealt[4]
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	add_child(tutorial)
	tutorial.setup(self, mandatory)
	camera_controller.set_player_view(0)
	_refresh_ui()
	set_starter(0)


func _start_bot_training() -> void:
	if battle_over:
		return
	_apply_match_looks(0)
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	match_mode = "bot"
	bot_opponent_enabled = true
	bot_difficulty = battle_ui.main_menu.bot_difficulty
	battle_ui.set_opponent_bot(true, BotAI.label_for(bot_difficulty))
	camera_controller.set_player_view(0)
	_refresh_ui()
	set_starter(await _ping_phase().run_local(true))


## The four-player mode runs in FfaBattle; this only lets "Neue Partie" repeat it.
func remember_ffa(humans: int, shifting_tiles: bool, card_effects: bool) -> void:
	match_mode = "ffa"
	_replay_ffa = [humans, shifting_tiles, card_effects]


func _start_chaos(options: Dictionary) -> void:
	if battle_over:
		return
	chaos = ChaosRules.new()
	chaos.hidden_king = bool(options.get("hidden_king", false))
	chaos.shifting_tiles = bool(options.get("shifting_tiles", false))
	chaos.card_effects = bool(options.get("card_effects", false))
	_replay_chaos_options = options.duplicate()
	chaos.set_king(0, temple_of(0))
	chaos.set_king(1, temple_of(1))
	grid_manager.set_temple_markers_visible(not chaos.hidden_king)
	if chaos.hidden_king:
		# Nobody wears the KERN look: all ten pieces must look alike.
		for team: Array[BattleUnit] in [players, enemies]:
			for unit: BattleUnit in team:
				unit.is_master = false
				unit.scale = Vector3.ONE
				unit.role_override = "FIGUR"
				unit.refresh_role_label()
		chaos.set_king(1, enemies.pick_random().grid_position)
	_apply_match_looks(0)
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	match_mode = "chaos"
	bot_opponent_enabled = true
	bot_difficulty = BotAI.Difficulty.MEDIUM
	battle_ui.set_opponent_bot(true, "CHAOS")
	camera_controller.set_player_view(0)
	_refresh_ui()
	set_starter(await _ping_phase().run_local(true))


## Chaos: the player secretly taps one of their five pieces to be the king.
func _choose_secret_king() -> void:
	_choosing_king = true
	input_locked = false
	player_controller.enabled = true
	battle_ui.set_instruction("Wähle geheim deinen KERN. Der Bot sieht nicht, wen du wählst.")
	await chaos_king_chosen
	input_locked = true
	player_controller.enabled = false


func _pick_king(coordinate: Vector2i) -> void:
	var unit := grid_manager.get_unit_at(coordinate) as BattleUnit
	if unit == null or unit.team_id != 0:
		battle_ui.set_instruction("Tippe auf eine deiner Figuren.")
		return
	chaos.set_king(0, coordinate)
	unit.role_override = "DEIN KERN"
	unit.refresh_role_label()
	unit.mark_as_king()
	_choosing_king = false
	SoundBoard.play("click")
	chaos_king_chosen.emit()


func _is_protected(coordinate: Vector2i, occupant: BattleUnit) -> bool:
	return chaos != null and occupant != null and chaos.protected.has(coordinate)


func _effects_on() -> bool:
	return chaos != null and chaos.card_effects


## The effect kind of each card in a hand, for the bot.
func _hand_effects(team: int) -> Array:
	if not _effects_on():
		return []
	var kinds: Array = []
	for card: MovementCard in hands[team]:
		kinds.append(CardEffect.kind_of(card))
	return kinds


func _effect_targets(card: MovementCard) -> Array[Vector2i]:
	var own: Array[Vector2i] = []
	var enemy: Array[Vector2i] = []
	for unit: BattleUnit in (players if current_player == 0 else enemies):
		if not unit.is_dead:
			own.append(unit.grid_position)
	for unit: BattleUnit in (enemies if current_player == 0 else players):
		if not unit.is_dead:
			enemy.append(unit.grid_position)
	return CardEffect.targets(
		CardEffect.kind_of(card), selected_unit.grid_position, current_player,
		grid_manager.grid_size, own, enemy, chaos.collapsed, chaos.protected
	)


## The EFFEKT button: switch between the card's step and its effect.
func _on_effect_requested() -> void:
	if input_locked or battle_over or not _effects_on() or selected_card_slot < 0:
		return
	SoundBoard.play("click")
	_effect_mode = not _effect_mode
	_refresh_targets()
	_refresh_effect_button()
	var card: MovementCard = hands[current_player][selected_card_slot]
	if not _effect_mode:
		battle_ui.set_instruction("Schritt gewählt. Tippe auf ein leuchtendes Feld.")
	elif selected_unit == null:
		battle_ui.set_instruction("Wähle zuerst die Figur, die den Effekt auslöst.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("Kein Ziel für diesen Effekt. Schritt oder andere Figur wählen.")
	elif battle_ui.has_capture_warning():
		battle_ui.set_instruction("KERN-ALARM: Dieser Effekt kann den gegnerischen KERN schlagen.")
	else:
		battle_ui.set_instruction(str(CardEffect.HINTS[CardEffect.kind_of(card)]))


func _refresh_effect_button() -> void:
	var can_show := _effects_on() and not battle_over and not input_locked and not must_pass and selected_card_slot >= 0 and current_player == _viewer_team()
	if not can_show:
		battle_ui.set_effect_button(false)
		return
	var card: MovementCard = hands[current_player][selected_card_slot]
	battle_ui.set_effect_button(true, "SCHRITT" if _effect_mode else CardEffect.button_text(CardEffect.kind_of(card)))


## Uses the selected card's effect on `target` instead of stepping.
func _perform_effect(target: Vector2i) -> void:
	input_locked = true
	player_controller.enabled = false
	var caster := selected_unit
	var origin := caster.grid_position
	var card: MovementCard = hands[current_player][selected_card_slot]
	var kind := CardEffect.kind_of(card)
	var color: Color = GridBattleUI.TEAM_COLORS[current_player]
	var other := grid_manager.get_unit_at(target) as BattleUnit
	var king_hit := false
	grid_manager.clear_highlights()
	battle_ui.set_effect_button(false)
	match kind:
		CardEffect.Kind.STRIKE:
			king_hit = chaos.is_king_at(other.team_id, target)
			CombatEffects.pillar(units_parent, other.global_position, color)
			await other.shatter(caster.global_position, color)
		CardEffect.Kind.PUSH:
			var occupied: Array[Vector2i] = []
			for unit: BattleUnit in players + enemies:
				if not unit.is_dead:
					occupied.append(unit.grid_position)
			var landing := CardEffect.push_landing(origin, target, grid_manager.grid_size, occupied, chaos.collapsed)
			await _slide_unit(other, landing)
		CardEffect.Kind.SHIELD:
			chaos.protected[origin] = current_player
			caster.shielded = true
			caster.refresh_role_label()
			CombatEffects.pillar(units_parent, caster.global_position, color)
			await get_tree().create_timer(0.3).timeout
		CardEffect.Kind.SWAP:
			chaos.pieces_swapped(current_player, origin, target)
			grid_manager.set_occupant(origin, other)
			grid_manager.set_occupant(target, caster)
			await _swap_units(caster, other)
	_effect_mode = false
	var received_card := pass_card.card_name
	_exchange_card(selected_card_slot)
	_record_match_history({
		"type": "effect", "team": current_player, "from": origin, "to": target,
		"played_card": card.card_name, "received_card": received_card,
		"effect": CardEffect.button_text(kind), "master_capture": king_hit,
	})
	_deselect_unit()
	if king_hit:
		_finish_battle(current_player)
		return
	_advance_turn()


func _slide_unit(unit: BattleUnit, landing: Vector2i) -> void:
	var from_cell := unit.grid_position
	var tween := unit.create_tween()
	tween.tween_property(unit, "position", grid_manager.grid_to_world(landing), 0.3)
	await tween.finished
	unit.grid_position = landing
	grid_manager.move_occupant(unit, from_cell, landing)
	chaos.piece_moved(unit.team_id, from_cell, landing)


func _swap_units(first: BattleUnit, second: BattleUnit) -> void:
	var first_cell := first.grid_position
	first.grid_position = second.grid_position
	second.grid_position = first_cell
	var tween := first.create_tween().set_parallel(true)
	tween.tween_property(first, "position", grid_manager.grid_to_world(first.grid_position), 0.3)
	tween.tween_property(second, "position", grid_manager.grid_to_world(second.grid_position), 0.3)
	await tween.finished


func _is_blocked(coordinate: Vector2i) -> bool:
	return chaos != null and chaos.is_blocked(coordinate)


## At each round change: warned tiles collapse (taking the pieces on them), old
## holes return and new tiles are warned. Returns the message and the winner
## (-2: match goes on, -1: both kings fell, otherwise the surviving team).
func _shift_tiles() -> Dictionary:
	var board_size := grid_manager.grid_size
	var rng := RandomNumberGenerator.new()
	var occupied: Dictionary = {}
	for y: int in range(board_size.y):
		for x: int in range(board_size.x):
			var cell := Vector2i(x, y)
			if grid_manager.get_unit_at(cell) != null:
				occupied[cell] = true
	var shift := chaos.advance_round(round_number, board_size, rng, occupied)
	var lost_kings: Array[int] = []
	for cell: Vector2i in shift["restored"]:
		grid_manager.set_tile_state(cell, 0)
	for cell: Vector2i in shift["collapsed"]:
		var unit := grid_manager.get_unit_at(cell) as BattleUnit
		grid_manager.set_tile_state(cell, 2)
		if unit == null:
			continue
		if chaos.is_king_at(unit.team_id, cell):
			lost_kings.append(unit.team_id)
		unit.play_death()
	for cell: Vector2i in shift["warned"]:
		grid_manager.set_tile_state(cell, 1)
	var parts: PackedStringArray = []
	if not shift["collapsed"].is_empty():
		parts.append("Felder sind weggebrochen.")
	if not shift["warned"].is_empty():
		parts.append("Orange Felder brechen als Nächstes weg!")
	var winner := -2
	if lost_kings.size() == 2:
		winner = -1
	elif lost_kings.size() == 1:
		winner = 1 - lost_kings[0]
	return {"message": " ".join(parts), "winner": winner}


func _start_local_multiplayer() -> void:
	if battle_over:
		return
	_apply_match_looks(0)
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	bot_opponent_enabled = false
	battle_ui.set_opponent_bot(false)
	camera_controller.set_player_view(0)
	_refresh_ui()
	match_mode = "local"
	set_starter(await _ping_phase().run_local(false))


func _start_lan_match() -> void:
	_start_network_match().start(MatchClient.lan_url(), "Verbinde mit dem PC ...", "Verbunden. Warte auf eine zweite Person ...")


## invite_username: a friend who gets the room code as an invitation.
func _start_online_create(invite_username: String = "") -> void:
	var network := _start_network_match()
	network.invite_username = invite_username
	network.start(MatchClient.online_create_url(), "Erstelle ein Spiel ...", "Verbunden. Gleich gibt es einen Raum-Code ...")


func _start_online_join(code: String) -> void:
	_start_network_match().start(MatchClient.online_join_url(code), "Suche Raum %s ..." % code, "Verbunden. Trete Raum %s bei ..." % code)


func _start_online_quick() -> void:
	_start_network_match().start(MatchClient.online_quick_url(), "Verbinde ...", "Suche einen Gegner ...")


func _start_online_ranked(ticket: String) -> void:
	var network := _start_network_match()
	network.ranked = true
	network.start(MatchClient.online_ranked_url(ticket), "Verbinde ...", "Suche einen Ranked-Gegner ...")


## Shows the rating change once the server has rated a ranked game.
func show_ranked_result(result: Dictionary) -> void:
	battle_over = true
	input_locked = true
	player_controller.enabled = false
	battle_ui.hide_side_action()
	var score := float(result.get("score", 0.0))
	var title := "SIEG!" if score > 0.75 else ("UNENTSCHIEDEN" if score > 0.25 else "NIEDERLAGE")
	if str(result.get("reason", "")) == "time":
		title += "  ·  ZEIT ABGELAUFEN" if score < 0.25 else "  ·  GEGNER OHNE ZEIT"
	battle_ui.show_result("%s
%+d PUNKTE  ·  %d  %s" % [title, int(result.get("delta", 0)), int(result.get("after", 0)), str(result.get("rank", ""))])
	battle_ui.main_menu.account.connect_account()


func _start_online_resume(session: Dictionary) -> void:
	_start_network_match().resume(session)


func _start_network_match() -> NetworkMatch:
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	bot_opponent_enabled = false
	battle_ui.set_opponent_bot(false)
	battle_ui.set_opponent_remote(true)
	input_locked = true
	player_controller.enabled = false
	match_mode = "network"
	network_match = NetworkMatchScript.new()
	network_match.name = "NetworkMatch"
	add_child(network_match)
	network_match.setup(self, battle_ui)
	_refresh_ui()
	return network_match


## Sets up a fresh board for a match against another device.
func begin_network_match(team: int, card_names: Array) -> bool:
	var cards := MovementCardScript.cards_from_names(card_names)
	if cards.size() != 5 or team < 0 or team > 1:
		return false
	network_team = team
	match_cards = cards.duplicate()
	hands[0] = [cards[0], cards[1]]
	hands[1] = [cards[2], cards[3]]
	pass_card = cards[4]
	current_player = 0
	round_number = 1
	turns_played = 0
	must_pass = false
	position_counts.clear()
	_record_position()
	_apply_match_looks(team)
	camera_controller.set_player_view(team)
	# Online the Node Ping (or a resume) decides who starts; see set_starter().
	return true


## Starts play with the side the Node Ping chose; the arena flies in first.
func set_starter(team: int) -> void:
	starting_player = team
	current_player = team
	apply_figure_facing()
	await grid_manager.play_intro()
	pinging = false
	if tutorial != null:
		input_locked = true
		player_controller.enabled = false
		await tutorial.after_intro()
		await tutorial.before_node_ping()
		team = await _ping_phase().run_local(true)
		pinging = false
		starting_player = team
		current_player = team
		apply_figure_facing()
		input_locked = true
		player_controller.enabled = false
	SoundBoard.play("glitch")
	SoundBoard.say("start")
	position_counts.clear()
	_record_position()
	if not bot_opponent_enabled and network_team < 0:
		camera_controller.set_player_view(team)
	_refresh_ui()
	await battle_ui.play_card_deal()
	if tutorial != null:
		await tutorial.after_deal()
	if chaos != null and chaos.hidden_king:
		await _choose_secret_king()
	match_history.clear()
	_record_match_history({"type": "start", "team": team})
	_begin_turn(1)


## The local player sent an emote: show it over their KERN, pass it on.
func _on_emote_picked(emote_id: String) -> void:
	if ffa_battle != null and ffa_battle.is_active():
		ffa_battle.play_local_emote(emote_id)
		return
	var team := network_team if network_team >= 0 else current_player
	show_emote(team, emote_id)
	if network_match != null:
		network_match.client.send_emote(emote_id)
	elif bot_opponent_enabled and randf() < 0.4:
		# The bot sometimes answers.
		await get_tree().create_timer(1.2).timeout
		show_emote(1, EmoteWheel.CATALOGUE.pick_random()["id"])


## Only the KERN performs emotes.
func show_emote(team: int, emote_id: String) -> void:
	var units: Array[BattleUnit] = players if team == 0 else enemies
	for unit: BattleUnit in units:
		if unit.is_master and not unit.is_dead:
			EmoteStage.perform(units_parent, unit, team, emote_id)
			return


func _ping_phase() -> PingPhase:
	var phase := PingPhase.new()
	phase.name = "PingPhase"
	add_child(phase)
	phase.setup(self, player_controller)
	return phase


## Plays one turn received over the network for whichever side is to move.
## Returns false when it does not fit this board (the two devices disagree).
func apply_network_turn(message: Dictionary) -> bool:
	var slot := int(message.get("slot", -1))
	if slot < 0 or slot > 1 or battle_over:
		return false
	_deselect_unit()
	selected_card_slot = -1
	if str(message.get("type", "")) == "pass":
		_pass_turn(slot)
		return true
	var from_values: Array = message.get("from", [])
	var to_values: Array = message.get("to", [])
	if from_values.size() != 2 or to_values.size() != 2:
		return false
	var unit := grid_manager.get_unit_at(Vector2i(int(from_values[0]), int(from_values[1]))) as BattleUnit
	var destination := Vector2i(int(to_values[0]), int(to_values[1]))
	if unit == null or unit.team_id != current_player:
		return false
	selected_card_slot = slot
	_select_unit(unit)
	if destination not in movement_targets:
		_deselect_unit()
		return false
	await _perform_move(destination)
	return true


## Ends the match with a message instead of a winner (connection problems).
func end_with_message(reason: String) -> void:
	if battle_over:
		return
	battle_over = true
	input_locked = true
	player_controller.enabled = false
	battle_ui.hide_side_action()
	battle_ui.show_result(reason)


## Quick play found nobody; drop the search and play the bot instead.
func switch_to_bot() -> void:
	if network_match != null:
		network_match.leave()
		network_match.queue_free()
		network_match = null
	network_team = -1
	battle_ui.set_opponent_remote(false)
	_start_bot_training()


func refresh_turn_instruction() -> void:
	_begin_turn(0)


## The player's own look goes to their team; the other side gets a random one
## until (online) the opponent's real choice arrives.
func _apply_match_looks(own_team: int) -> void:
	var own := CharacterRoster.load_look()
	apply_team_look(own_team, own)
	var rival := CharacterRoster.random_character_id(own["character"])
	apply_team_look(1 - own_team, {
		"character": rival,
		"skin": CharacterRoster.random_skin_id(rival),
		"echo": CharacterRoster.ECHO_STYLES.pick_random()["id"],
		"board": CharacterRoster.BOARD_SKINS.pick_random()["id"],
	})


## Shows a team's master portrait, student echoes and board half skin.
func apply_team_look(team: int, look: Dictionary) -> void:
	team_looks[team] = look
	var character := CharacterRoster.dressed_character(look)
	var echo := str(CharacterRoster.echo_style(str(look.get("echo", "")))["id"])
	var tint: Color = GridBattleUI.TEAM_COLORS[team]
	var team_units: Array[BattleUnit] = players if team == 0 else enemies
	for index: int in range(team_units.size()):
		var unit := team_units[index]
		if unit.is_dead:
			continue
		# The fighter needs to be in the tree before it builds its own world.
		var fighter := FighterSprite.new()
		fighter.name = "FighterSprite"
		unit.apply_figure(fighter)
		if unit.is_master:
			fighter.build(character, tint)
		else:
			fighter.build(CharacterRoster.echo_look(echo, character, tint), tint, 0.75 if echo == "echo" else 0.0)
		unit.refresh_projections()
	var skin := CharacterRoster.board_skin(str(look.get("board", "")))
	grid_manager.set_side_skin(team, skin)


func _on_card_selected(team_id: int, slot: int) -> void:
	if input_locked or battle_over or team_id != current_player or slot < 0 or slot >= 2:
		return
	SoundBoard.play("click")
	if must_pass:
		if network_match != null:
			_timeouts_in_a_row = 0
			network_match.send_local_turn({"type": "pass", "seq": turns_played, "slot": slot})
		_pass_turn(slot)
		return
	selected_card_slot = slot
	_effect_mode = false
	_refresh_targets()
	_refresh_ui()
	if selected_unit == null:
		battle_ui.set_instruction("Wähle jetzt eine deiner Figuren.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("Mit dieser Karte kann die Figur nicht ziehen.")
	else:
		_set_target_instruction("Tippe auf ein leuchtendes Feld. Die goldene Kante ist der Übergang.")


func _on_cell_clicked(coordinate: Vector2i) -> void:
	if pinging or input_locked or battle_over or not grid_manager.is_inside(coordinate):
		return
	if _choosing_king:
		_pick_king(coordinate)
		return
	if must_pass:
		battle_ui.set_instruction(_pass_instruction())
		return
	var clicked_unit := grid_manager.get_unit_at(coordinate) as BattleUnit
	var aims_effect := _effect_mode and selected_unit != null and coordinate in movement_targets
	if clicked_unit != null and clicked_unit.team_id == current_player and not aims_effect:
		_select_unit(clicked_unit)
		return
	if aims_effect:
		await _perform_effect(coordinate)
	elif selected_unit != null and selected_card_slot >= 0 and coordinate in movement_targets:
		if network_match != null:
			_timeouts_in_a_row = 0
			network_match.send_local_turn({"type": "move", "seq": turns_played, "from": selected_unit.grid_position, "slot": selected_card_slot, "to": coordinate})
		await _perform_move(coordinate)
	elif selected_card_slot < 0:
		battle_ui.set_instruction("Wähle zuerst eine deiner zwei Karten.")
	else:
		battle_ui.set_instruction("Dieses Feld erlaubt die Karte nicht.")


func _select_unit(unit: BattleUnit) -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	_refresh_targets()
	_refresh_ui()
	if selected_card_slot < 0:
		battle_ui.set_instruction("Wähle jetzt eine deiner zwei Karten.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("Diese Figur hat mit der Karte kein Zielfeld.")
	else:
		_set_target_instruction("Tippe auf ein leuchtendes Feld. Wer den KERN schlägt, gewinnt.")


func _refresh_targets() -> void:
	movement_targets.clear()
	if selected_unit == null or selected_card_slot < 0:
		grid_manager.clear_highlights()
		battle_ui.set_capture_warning(false)
		return
	var card: MovementCard = hands[current_player][selected_card_slot]
	if _effect_mode:
		movement_targets = _effect_targets(card)
		var effect_wins := _master_capture_targets(movement_targets)
		grid_manager.show_movement_targets(movement_targets, selected_unit.grid_position, current_player, effect_wins)
		battle_ui.set_capture_warning(not effect_wins.is_empty())
		return
	for coordinate: Vector2i in card.destinations(selected_unit.grid_position, current_player, grid_manager.grid_size.x):
		var occupant := grid_manager.get_unit_at(coordinate) as BattleUnit
		if (occupant == null or occupant.team_id != current_player) and not _is_blocked(coordinate) and not _is_protected(coordinate, occupant):
			movement_targets.append(coordinate)
	var winning_targets := _master_capture_targets(movement_targets)
	grid_manager.show_movement_targets(movement_targets, selected_unit.grid_position, current_player, winning_targets)
	battle_ui.set_capture_warning(not winning_targets.is_empty())


func _master_capture_targets(coordinates: Array[Vector2i]) -> Array[Vector2i]:
	var winning: Array[Vector2i] = []
	for coordinate: Vector2i in coordinates:
		var occupant := grid_manager.get_unit_at(coordinate) as BattleUnit
		var captures_master := occupant != null and occupant.team_id != current_player and (
			occupant.is_master or (chaos != null and chaos.hidden_king and chaos.is_king_at(occupant.team_id, coordinate))
		)
		var reaches_temple := (chaos == null or not chaos.hidden_king) and coordinate == temple_of(1 - current_player)
		var strikes_hidden_king := (
			_effect_mode and _effects_on()
			and CardEffect.kind_of(hands[current_player][selected_card_slot]) == CardEffect.Kind.STRIKE
			and occupant != null and chaos.is_king_at(occupant.team_id, coordinate)
		)
		if captures_master or reaches_temple or strikes_hidden_king:
			winning.append(coordinate)
	return winning


func _set_target_instruction(fallback: String) -> void:
	if battle_ui.has_capture_warning():
		battle_ui.set_instruction("KERN-ALARM: Ein möglicher Gewinnzug leuchtet gold.")
	else:
		battle_ui.set_instruction(fallback)


func _perform_move(destination: Vector2i) -> void:
	input_locked = true
	player_controller.enabled = false
	var moving_unit := selected_unit
	var source := moving_unit.grid_position
	var captured_unit := grid_manager.get_unit_at(destination) as BattleUnit
	var captured_master := captured_unit != null and captured_unit.is_master
	if chaos != null:
		captured_master = captured_unit != null and chaos.is_king_at(captured_unit.team_id, destination)
	# Any piece reaching the enemy KERN's starting square wins too.
	var reached_temple := (chaos == null or not chaos.hidden_king) and destination == temple_of(1 - current_player)
	grid_manager.clear_highlights()
	# Each side moves in its master character's fighting style.
	var character := CharacterRoster.character(str(team_looks[current_player].get("character", "")))
	await unit_movement.perform_move(
		moving_unit, captured_unit, source, destination, grid_manager,
		str(character.get("style", "brawler")), GridBattleUI.TEAM_COLORS[current_player]
	)
	moving_unit.grid_position = destination
	grid_manager.move_occupant(moving_unit, source, destination)
	if chaos != null:
		chaos.piece_moved(current_player, source, destination)
	if _is_local_move():
		var played: MovementCard = hands[current_player][selected_card_slot]
		MatchStats.add_card("card_plays", played.card_name)
		if captured_unit != null:
			MatchStats.add("nodes_claimed")
			MatchStats.add_card("card_captures", played.card_name)
	var received_card := pass_card.card_name
	var played_card: MovementCard = hands[current_player][selected_card_slot]
	_exchange_card(selected_card_slot)
	_record_match_history({
		"type": "move", "team": current_player, "from": source, "to": destination,
		"played_card": played_card.card_name, "received_card": received_card,
		"captured": ("KERN" if captured_master else "ECHO") if captured_unit != null else "",
		"master_capture": captured_master, "temple_win": reached_temple,
	})
	_deselect_unit()
	if captured_master or reached_temple:
		_finish_battle(current_player)
		return
	if tutorial != null:
		_refresh_ui()
		await tutorial.after_move(current_player)
	_advance_turn()


## The player's own move in an online match (bot and hot-seat games do not count).
func _is_local_move() -> bool:
	return network_team >= 0 and current_player == network_team


## Where a team's KERN starts; any enemy piece stepping onto it wins.
static func temple_of(team: int) -> Vector2i:
	return Vector2i(2, 4 if team == 0 else 0)


## Gives the card in slot to the pass space and takes the waiting card.
func _exchange_card(slot: int) -> void:
	var used_card: MovementCard = hands[current_player][slot]
	hands[current_player][slot] = pass_card
	pass_card = used_card
	turns_played += 1


## Card-game rule: a side without any legal move still has to give one card away.
func _pass_turn(slot: int) -> void:
	input_locked = true
	player_controller.enabled = false
	_deselect_unit()
	var received_card := pass_card.card_name
	var played_card: MovementCard = hands[current_player][slot]
	_exchange_card(slot)
	_record_match_history({
		"type": "pass", "team": current_player, "played_card": played_card.card_name,
		"received_card": received_card,
	})
	_advance_turn()


func _advance_turn() -> void:
	current_player = 1 - current_player
	if not bot_opponent_enabled and network_team < 0:
		camera_controller.set_player_view(current_player)
	_effect_mode = false
	if chaos != null:
		chaos.expire_protection(current_player)
		for unit: BattleUnit in (players if current_player == 0 else enemies):
			if unit.shielded:
				unit.shielded = false
				unit.refresh_role_label()
	var tile_notice := ""
	if current_player == starting_player:
		round_number += 1
		if chaos != null and chaos.shifting_tiles:
			var shift := _shift_tiles()
			tile_notice = str(shift["message"])
			if int(shift["winner"]) != -2:
				selected_card_slot = -1
				_refresh_latest_match_snapshot()
				_refresh_ui()
				_finish_battle(int(shift["winner"]))
				return
	_refresh_latest_match_snapshot()
	selected_card_slot = -1
	var repetitions := _record_position()
	if repetitions >= DRAW_REPETITIONS:
		_refresh_ui()
		_finish_battle(-1)
		return
	_begin_turn(repetitions)
	if tile_notice != "":
		battle_ui.set_instruction(tile_notice)


## Unlocks input for the side to move (or hands over to the bot / the other
## device) and tells the player what to do.
func _begin_turn(repetitions: int) -> void:
	if network_team < 0 and not bot_opponent_enabled:
		apply_figure_facing()
	must_pass = not _has_legal_move(current_player)
	_refresh_core_threat_warning()
	var bot_turn := bot_opponent_enabled and current_player == 1
	var remote_turn := network_team >= 0 and current_player != network_team
	if network_team >= 0 and not remote_turn and not network_match.ranked and not battle_over:
		turn_timer.start(MOVE_SECONDS)
	else:
		turn_timer.stop()
	input_locked = bot_turn or remote_turn
	player_controller.enabled = not input_locked
	battle_ui.ensure_cards_visible()
	_refresh_ui()
	if tutorial != null and not bot_turn and not must_pass:
		tutorial.on_player_turn()
	if bot_turn:
		battle_ui.set_instruction("Der Bot denkt nach ...")
		call_deferred("_run_bot_turn")
	elif remote_turn:
		battle_ui.set_instruction("Der Gegner ist am Zug ...")
		network_match.call_deferred("play_pending_turns")
	elif must_pass:
		battle_ui.set_instruction(_pass_instruction())
	elif repetitions == DRAW_REPETITIONS - 1:
		battle_ui.set_instruction("Diese Stellung gab es schon. Noch einmal, und es ist Unentschieden.")
	elif bot_opponent_enabled or network_team >= 0:
		battle_ui.set_instruction("Wähle eine Karte und eine Figur.")
	else:
		battle_ui.set_instruction("Spieler %d: Wähle eine Karte und eine Figur." % (current_player + 1))


func _refresh_core_threat_warning() -> void:
	var standard_match := match_mode in ["bot", "local", "network"]
	var ranked_match := match_mode == "network" and network_match != null and network_match.ranked
	var threatened := (
		standard_match and not ranked_match and not battle_over and not pinging
		and _has_master_capture_next_turn(_viewer_team())
	)
	battle_ui.set_core_threat_warning(threatened)


func _has_master_capture_next_turn(defending_team: int) -> bool:
	var defending_master := _find_master(players if defending_team == 0 else enemies)
	if defending_master == null:
		return false
	var attacking_team := 1 - defending_team
	var attackers: Array[BattleUnit] = enemies if attacking_team == 1 else players
	for unit: BattleUnit in attackers:
		if unit.is_dead:
			continue
		for card: MovementCard in hands[attacking_team]:
			for destination: Vector2i in card.destinations(unit.grid_position, attacking_team, grid_manager.grid_size.x):
				if destination != defending_master.grid_position:
					continue
				var occupant := grid_manager.get_unit_at(destination) as BattleUnit
				if occupant == defending_master and not _is_blocked(destination) and not _is_protected(destination, occupant):
					return true
	return false


## The clock ran out in a normal online game: the grid plays a loose move for
## the player; three in a row forfeit the match.
func _on_turn_timeout() -> void:
	if battle_over or input_locked or network_team < 0 or current_player != network_team:
		return
	_timeouts_in_a_row += 1
	if _timeouts_in_a_row >= MAX_TIMEOUTS_IN_A_ROW:
		battle_ui.set_instruction("Dreimal nicht gezogen. Das Grid gibt für dich auf.")
		network_match.leave()
		_finish_battle(1 - network_team)
		return
	battle_ui.set_instruction("Zeit abgelaufen. Das Grid zieht für dich.")
	var result := BotAIScript.new(BotAI.Difficulty.EASY).choose_move(build_ai_state(), current_player)
	if result.is_empty():
		return
	input_locked = true
	if result.has("pass"):
		network_match.send_local_turn({"type": "pass", "seq": turns_played, "slot": int(result["slot"])})
		_pass_turn(int(result["slot"]))
		return
	var unit := grid_manager.get_unit_at(result["from"]) as BattleUnit
	if unit == null:
		return
	selected_card_slot = int(result["slot"])
	_select_unit(unit)
	network_match.send_local_turn({"type": "move", "seq": turns_played, "from": unit.grid_position, "slot": selected_card_slot, "to": result["to"]})
	await _perform_move(result["to"])


func _pass_instruction() -> String:
	return "Keine Figur kann ziehen. Tippe auf eine Karte, um sie abzugeben."


func _has_legal_move(team_id: int) -> bool:
	var team: Array[BattleUnit] = players if team_id == 0 else enemies
	for unit: BattleUnit in team:
		if unit.is_dead:
			continue
		for card: MovementCard in hands[team_id]:
			for coordinate: Vector2i in card.destinations(unit.grid_position, team_id, grid_manager.grid_size.x):
				var occupant := grid_manager.get_unit_at(coordinate) as BattleUnit
				if (occupant == null or occupant.team_id != team_id) and not _is_blocked(coordinate) and not _is_protected(coordinate, occupant):
					return true
	return false


## Counts the current position (figures, cards, side to move) and returns how often it has occurred.
func _record_position() -> int:
	var key := _position_key()
	position_counts[key] = int(position_counts.get(key, 0)) + 1
	return position_counts[key]


func _position_key() -> String:
	var parts: PackedStringArray = []
	for unit: BattleUnit in players + enemies:
		if not unit.is_dead:
			parts.append("%d%s%d,%d" % [unit.team_id, "M" if unit.is_master else "S", unit.grid_position.x, unit.grid_position.y])
	parts.sort()
	for team_id: int in range(2):
		var names: PackedStringArray = [hands[team_id][0].card_name, hands[team_id][1].card_name]
		names.sort()
		parts.append("|".join(names))
	parts.append(pass_card.card_name)
	parts.append(str(current_player))
	if chaos != null:
		parts.append(chaos.state_key())
	return ";".join(parts)


func _run_bot_turn() -> void:
	await get_tree().create_timer(0.4).timeout
	if battle_over or current_player != 1 or not bot_opponent_enabled:
		return
	# Let the "thinking" text render before the search blocks the frame.
	await get_tree().process_frame
	var choice := _choose_chaos_move() if chaos != null else _choose_bot_move()
	if choice.is_empty():
		return
	if choice.has("pass"):
		_pass_turn(int(choice["slot"]))
		if not battle_over and not must_pass:
			battle_ui.set_instruction("Der Bot konnte nicht ziehen und hat eine Karte abgegeben.")
		return
	selected_card_slot = int(choice["slot"])
	_effect_mode = choice.has("effect")
	_select_unit(choice["unit"] as BattleUnit)
	await get_tree().create_timer(0.18).timeout
	if not battle_over and current_player == 1:
		if _effect_mode:
			await _perform_effect(choice["destination"])
		else:
			await _perform_move(choice["destination"])


func _choose_chaos_move() -> Dictionary:
	var own: Array[Vector2i] = []
	var enemy: Array[Vector2i] = []
	for unit: BattleUnit in enemies:
		if not unit.is_dead:
			own.append(unit.grid_position)
	for unit: BattleUnit in players:
		if not unit.is_dead:
			enemy.append(unit.grid_position)
	var result := ChaosBotScript.new().choose_move(
		1, own, enemy, chaos.king_cells[1], hands[1], hands[0], chaos.collapsed, chaos.warned, grid_manager.grid_size.x,
		_hand_effects(1), chaos.protected
	)
	if result.has("pass"):
		return {"slot": int(result["slot"]), "pass": true}
	if result.has("effect"):
		var caster := grid_manager.get_unit_at(result["from"]) as BattleUnit
		if caster == null:
			return {}
		return {"unit": caster, "slot": int(result["slot"]), "destination": result["to"], "effect": true}
	var unit := grid_manager.get_unit_at(result["from"]) as BattleUnit
	if unit == null:
		return {}
	return {"unit": unit, "slot": int(result["slot"]), "destination": result["to"]}


func _choose_bot_move() -> Dictionary:
	if tutorial != null:
		return tutorial.choose_bot_move()
	var ai: BotAI = BotAIScript.new(bot_difficulty)
	var result := ai.choose_move(build_ai_state(), 1)
	if result.is_empty():
		return {}
	if result.has("pass"):
		return {"slot": int(result["slot"]), "pass": true}
	var unit := grid_manager.get_unit_at(result["from"]) as BattleUnit
	if unit == null:
		return {}
	return {"unit": unit, "slot": int(result["slot"]), "destination": result["to"]}


## Compact copy of the match for BotAI; never shares scene nodes.
func build_ai_state() -> Dictionary:
	var pieces := PackedInt32Array()
	var teams := PackedInt32Array()
	pieces.resize(25)
	teams.resize(25)
	for team: Array[BattleUnit] in [players, enemies]:
		for unit: BattleUnit in team:
			if unit.is_dead:
				continue
			var cell := unit.grid_position.y * 5 + unit.grid_position.x
			pieces[cell] = 2 if unit.is_master else 1
			teams[cell] = unit.team_id
	var cards: Array[MovementCard] = []
	for card: MovementCard in match_cards:
		cards.append(card)
	for card: MovementCard in [hands[0][0], hands[0][1], hands[1][0], hands[1][1], pass_card]:
		if card not in cards:
			cards.append(card)
	return {
		"pieces": pieces,
		"teams": teams,
		"hands": [
			[cards.find(hands[0][0]), cards.find(hands[0][1])],
			[cards.find(hands[1][0]), cards.find(hands[1][1])],
		],
		"pass": cards.find(pass_card),
		"cards": cards,
	}


func _find_master(team: Array[BattleUnit]) -> BattleUnit:
	for unit: BattleUnit in team:
		if unit.is_master and not unit.is_dead:
			return unit
	return null


func _deselect_unit() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = null
	movement_targets.clear()
	grid_manager.clear_highlights()
	battle_ui.set_capture_warning(false)


func _record_match_history(action: Dictionary) -> void:
	var pieces: Array[Dictionary] = []
	for unit: BattleUnit in players + enemies:
		if unit.is_dead:
			continue
		pieces.append({"team": unit.team_id, "master": unit.is_master, "cell": unit.grid_position})
	var hand_names: Array = []
	for team: int in range(2):
		var team_hand: Array[String] = []
		for card: MovementCard in hands[team]:
			team_hand.append(card.card_name)
		hand_names.append(team_hand)
	var tiles := PackedInt32Array()
	for row: int in range(grid_manager.grid_size.y):
		for column: int in range(grid_manager.grid_size.x):
			var cell: GridCell = grid_manager.cells[Vector2i(column, row)]
			tiles.append(cell.tile_state)
	match_history.append({
		"action": action.duplicate(true),
		"pieces": pieces,
		"hands": hand_names,
		"pass_card": pass_card.card_name,
		"tiles": tiles,
		"round": round_number,
		"side_to_move": current_player if str(action.get("type", "")) == "start" else 1 - current_player,
	})
	battle_ui.set_match_history(match_history)


func _refresh_latest_match_snapshot() -> void:
	if match_history.is_empty():
		return
	var latest: Dictionary = match_history.back()
	var pieces: Array[Dictionary] = []
	for unit: BattleUnit in players + enemies:
		if unit.is_dead:
			continue
		pieces.append({"team": unit.team_id, "master": unit.is_master, "cell": unit.grid_position})
	var tiles := PackedInt32Array()
	for row: int in range(grid_manager.grid_size.y):
		for column: int in range(grid_manager.grid_size.x):
			var cell: GridCell = grid_manager.cells[Vector2i(column, row)]
			tiles.append(cell.tile_state)
	latest["pieces"] = pieces
	latest["tiles"] = tiles
	latest["round"] = round_number
	latest["side_to_move"] = current_player
	match_history[match_history.size() - 1] = latest
	battle_ui.set_match_history(match_history)


func _show_match_history() -> void:
	battle_ui.show_match_history(match_history)


func _on_unit_died(unit: BattleUnit) -> void:
	grid_manager.remove_occupant(unit.grid_position, unit)


## winner -1 means a draw by repetition.
func _finish_battle(winner: int) -> void:
	battle_over = true
	battle_ui.set_core_threat_warning(false)
	if tutorial != null:
		tutorial.on_battle_over(winner)
	turn_timer.stop()
	var local_won := winner >= 0 and (winner == network_team if network_team >= 0 else (winner == 0 or not bot_opponent_enabled))
	# Only ranked and normal online matches count (not bot or hot-seat games).
	if winner >= 0 and network_team >= 0:
		var mode := "ranked" if network_match != null and network_match.ranked else "online"
		MatchStats.record_match(mode, local_won, turns_played)
		battle_ui.result_extra = AccessLevel.award(mode, local_won)
		if mode == "online":
			battle_ui.main_menu.account.report_online_result(local_won)
	if chaos != null and chaos.hidden_king:
		_reveal_kings()
	SoundBoard.play("victory" if local_won else "defeat")
	SoundBoard.say("victory" if local_won else "defeat")
	input_locked = true
	player_controller.enabled = false
	if network_match != null:
		network_match.finished()
	if winner < 0:
		battle_ui.show_result("UNENTSCHIEDEN")
	elif network_team >= 0:
		battle_ui.show_result("SIEG!\n" + GridLore.win_line() if winner == network_team else "NIEDERLAGE\n" + GridLore.loss_line())
	elif bot_opponent_enabled:
		battle_ui.show_result("SIEG!\n" + GridLore.win_line() if winner == 0 else "NIEDERLAGE\n" + GridLore.loss_line())
		if winner == 0 and chaos == null:
			_collect_bot_reward()
	else:
		battle_ui.show_result("SPIELER %d GEWINNT" % (winner + 1))


## The match is over: every surviving king shows its role.
func _reveal_kings() -> void:
	for team: int in range(2):
		for unit: BattleUnit in (players if team == 0 else enemies):
			if not unit.is_dead and chaos.is_king_at(team, unit.grid_position):
				unit.role_override = "KERN"
				unit.refresh_role_label()
				unit.mark_as_king()


## Credits for beating the bot; the server adds them and caps them per day.
func _collect_bot_reward() -> void:
	var account := battle_ui.main_menu.account
	if not account.has_account():
		return
	var before := account.credits()
	await account.report_bot_win(bot_difficulty)
	if not battle_over:
		return
	if account.credits() > before:
		battle_ui.show_result("SIEG!\n+%d CREDITS" % (account.credits() - before))
	elif account._last_error == "daily_limit":
		battle_ui.show_result("SIEG!\nCredit-Limit für heute erreicht")


func _refresh_ui() -> void:
	battle_ui.update_header(current_player, round_number)
	battle_ui.update_hands(hands, pass_card, current_player, selected_card_slot, _viewer_team())
	battle_ui.update_selection(selected_unit)
	_refresh_effect_button()


func _viewer_team() -> int:
	if network_team >= 0:
		return network_team
	return current_player if not bot_opponent_enabled else 0


func _on_cancel_requested() -> void:
	if input_locked or battle_over:
		return
	if selected_unit != null:
		_deselect_unit()
		_refresh_ui()
		battle_ui.set_instruction("Auswahl aufgehoben. Wähle Karte und Figur.")
	else:
		battle_ui.toggle_menu(true)


## Starts the same mode again; online there is no rematch, so it goes to the menu.
func _new_match() -> void:
	if match_mode in ["bot", "local", "chaos", "ffa"]:
		_replay_mode = match_mode
	_restart_battle()


func _restart_battle() -> void:
	if network_match != null and not battle_over:
		network_match.leave()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

## Turns every resting figure to the look chosen in the settings. The camera
## sits at the seat of the local player; in a two-player match on one device
## it is the seat of whoever is to move.
func apply_figure_facing() -> void:
	var seat := network_team if network_team >= 0 else (current_player if not bot_opponent_enabled else 0)
	for units: Array[BattleUnit] in [players, enemies]:
		for unit: BattleUnit in units:
			unit.rest_yaw = FigureFacing.yaw_for(unit.team_id, seat)
			if not unit.facing_locked:
				unit.rotation.y = unit.rest_yaw


## The figures are beamed onto the platforms once these have landed: a column
## of light, then each one grows out of it, one after another.
func _beam_in_units() -> void:
	var beamed: Array[BattleUnit] = []
	for units: Array[BattleUnit] in [players, enemies]:
		for unit: BattleUnit in units:
			if not unit.is_dead:
				unit.visual_root.scale = Vector3(0.05, 1.7, 0.05)
				beamed.append(unit)
	units_parent.visible = true
	SoundBoard.play("teleport")
	for index: int in range(beamed.size()):
		_beam_in(beamed[index], float(index) * 0.05)


func _beam_in(unit: BattleUnit, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(unit) or unit.is_dead:
		return
	CombatEffects.pillar(units_parent, unit.global_position, GridBattleUI.TEAM_COLORS[unit.team_id])
	var grow := unit.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(unit.visual_root, "scale", Vector3.ONE, 0.25)
