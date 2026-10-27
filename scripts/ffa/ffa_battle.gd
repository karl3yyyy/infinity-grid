class_name FfaBattle
extends Node

## Four-player free-for-all in the 3D game: same figures, cards, camera and
## fighting styles as the main match, on the flat FfaFloor. FfaRules decides
## everything; this node shows it and takes the input of the humans.

const BotScript := preload("res://scripts/ffa/ffa_bot.gd")

var rules: FfaRules
var bot_delay: float = 0.7

var battle_ui: GridBattleUI
var camera: CameraController
var player_controller: PlayerController
var unit_movement: UnitMovement
var battle_manager: GridBattleManager
var board_root: Node3D
var floor_grid: FfaFloor
var units_root: Node3D

var _active: bool = false
## Changes with every start so coroutines of an abandoned game stop.
var _game_id: int = 0
var _busy: bool = false
var _must_pass: bool = false
var _humans: int = 1
var _shifting_tiles: bool = false
var _is_human: Array[bool] = [false, false, false, false]
var _view_seat: int = 0
var _looks: Array[Dictionary] = []
var _units: Array[BattleUnit] = []
var _bot: FfaBot
var _selected: BattleUnit
var _slot: int = -1
var _targets: Array[Vector2i] = []
var _notice: String = ""
var _previous_grid: GridManager
var _world_hands: FfaWorldHands
var _top_row: Control
## Room with friends: every client plays the rules itself and the server relays the turns.
var client: GroupClient
var _online: bool = false
var _spectator: bool = false
var _my_seat: int = 0
var _is_host: bool = false
var _names: Array[String] = ["", "", "", ""]
## Turns played so far; the number of the next turn.
var _turns_done: int = 0
var _incoming: Array[Dictionary] = []
var _animating_remote: bool = false
var _effects: bool = false
var _reconnecting: bool = false
## True while the player aims the card's effect instead of its step.
var _effect_mode: bool = false


func setup(ui: GridBattleUI, camera_controller: CameraController, input: PlayerController, movement: UnitMovement, manager: GridBattleManager) -> void:
	battle_ui = ui
	camera = camera_controller
	player_controller = input
	unit_movement = movement
	battle_manager = manager
	battle_manager.ffa_battle = self
	board_root = Node3D.new()
	board_root.name = "FfaBoard"
	board_root.visible = false
	get_parent().add_child(board_root)
	floor_grid = FfaFloor.new()
	floor_grid.name = "FfaFloor"
	board_root.add_child(floor_grid)
	units_root = Node3D.new()
	units_root.name = "FfaUnits"
	board_root.add_child(units_root)
	_install_hands()
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_requested)
	battle_ui.card_selected.connect(_on_card_selected)
	battle_ui.restart_pressed.connect(_leave_room)
	battle_ui.effect_requested.connect(_on_effect_requested)


## The opponent row of the HUD is not used; the other hands lie beside the board.
func _install_hands() -> void:
	_top_row = battle_ui.hand_rows[1]
	_world_hands = FfaWorldHands.new()
	_world_hands.name = "FfaHands"
	board_root.add_child(_world_hands)


## humans: 0 (bots only, tests), 1, 2 (opposite seats) or 4.
func start(humans: int, shifting_tiles: bool, card_effects: bool = false) -> void:
	var seats: Array = {0: [], 1: [0], 2: [0, 2], 4: [0, 1, 2, 3]}.get(humans, [0])
	_online = false
	_spectator = false
	_my_seat = 0
	battle_manager.remember_ffa(humans, shifting_tiles, card_effects)
	await _begin_game(seats, shifting_tiles, -1, [], card_effects)


## The room started: `info` is the server's group_start message.
func start_online(info: Dictionary) -> void:
	_online = true
	_spectator = false
	_my_seat = int(info["seat"])
	_is_host = bool(info.get("host", false))
	for seat: int in range(FfaRules.PLAYERS):
		_names[seat] = str((info.get("names", []) as Array)[seat])
	var settings: Dictionary = info.get("settings", {})
	var seats: Array = []
	for seat: Variant in info.get("humans", []):
		seats.append(int(seat))
	await _begin_game(seats, bool(settings.get("tiles", false)), int(info["seed"]), info["cards"] as Array, bool(settings.get("effects", false)))


func resume_online(info: Dictionary) -> void:
	_online = true
	_spectator = false
	_my_seat = int(info["seat"])
	_is_host = bool(info.get("host", false))
	var names: Array = info.get("names", [])
	for seat: int in range(FfaRules.PLAYERS):
		_names[seat] = str(names[seat])
	var settings: Dictionary = info.get("settings", {})
	var seats: Array = []
	for seat: Variant in info.get("humans", []):
		seats.append(int(seat))
	await _begin_game(
		seats, bool(settings.get("tiles", false)), int(info["seed"]),
		info["cards"] as Array, bool(settings.get("effects", false)), info,
	)


func _begin_game(
	seats: Array, shifting_tiles: bool, rng_seed: int, card_names: Array,
	card_effects: bool, resume_info: Dictionary = {},
) -> void:
	_game_id += 1
	var game := _game_id
	_humans = seats.size()
	_shifting_tiles = shifting_tiles
	_effects = card_effects
	_effect_mode = false
	_reconnecting = false
	_turns_done = 0
	_incoming.clear()
	_animating_remote = false
	for seat: int in range(FfaRules.PLAYERS):
		_is_human[seat] = seat in seats
	_view_seat = 0 if _spectator else _my_seat
	ScreenLayout.set_finite_grid_active(true)
	_active = true
	_busy = true
	battle_ui.main_menu.close_menu()
	if _previous_grid == null:
		_previous_grid = player_controller.grid_manager
	player_controller.grid_manager = floor_grid
	rules = FfaRules.new()
	rules.setup(shifting_tiles, rng_seed, card_names, card_effects)
	_bot = BotScript.new()
	_clear_units()
	floor_grid.setup()
	board_root.visible = true
	_top_row.visible = false
	camera.set_board(FfaRules.SIZE, false, FfaWorldHands.FRAMING_MARGIN_CELLS)
	camera.set_seat_view(0 if _spectator else _my_seat)
	_make_looks()
	if _online:
		battle_ui.set_opponent_remote(true)
	else:
		battle_ui.set_opponent_remote(false)
		battle_ui.set_opponent_bot(true)
	_refresh_ui()
	if resume_info.is_empty():
		_spawn_units()
		battle_ui.set_instruction(GridLore.finite_start_line())
		if seats.size() > 0:
			var starter := await _run_ping(seats)
			if game != _game_id:
				return
			rules.current = starter
			_refresh_ui()
		await battle_ui.play_card_deal()
	else:
		var starter := int(resume_info.get("starter", -1))
		if starter < 0:
			starter = await _run_ping(seats)
		if game != _game_id:
			return
		rules.current = starter
		var history: Array = resume_info.get("moves", [])
		if not _replay_turns(history):
			_out_of_sync()
			return
		_turns_done = history.size()
		_spawn_rules_pieces()
		_sync_tiles()
		_sync_shields()
		battle_ui.ensure_cards_visible()
		battle_ui.show_toast("Finite Grid ist wieder verbunden.")
	if game == _game_id:
		if rules.winner == FfaRules.RUNNING:
			if _online and not _spectator and client != null and not client.watch_key.is_empty():
				call_deferred("_publish_live_match")
			_begin_turn()
		else:
			_finish()


## Node Ping before the first turn: returns the seat that starts.
func _run_ping(seats: Array) -> int:
	var ping := FfaPing.new()
	ping.name = "FfaPing"
	add_child(ping)
	ping.setup(battle_manager, player_controller)
	if _online:
		return await ping.run_online(client, _my_seat)
	return await ping.run_seats(seats)


func _clear_units() -> void:
	for unit: BattleUnit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()


func _make_looks() -> void:
	_looks.clear()
	var own := CharacterRoster.load_look()
	var used: Array[String] = [str(own["character"])]
	for seat: int in range(FfaRules.PLAYERS):
		if seat == _my_seat:
			_looks.append(own)
			continue
		var character_id := CharacterRoster.random_character_id()
		for _attempt: int in range(8):
			if character_id not in used:
				break
			character_id = CharacterRoster.random_character_id()
		used.append(character_id)
		_looks.append({"character": character_id, "skin": CharacterRoster.random_skin_id(character_id), "echo": own["echo"]})


func _spawn_units() -> void:
	for seat: int in range(FfaRules.PLAYERS):
		for index: int in range(FfaRules.PIECES_PER_PLAYER):
			_spawn_unit(seat, FfaRules.start_cell(seat, index), index == 2)


func _spawn_rules_pieces() -> void:
	for cell: Vector2i in rules.pieces:
		var piece: Dictionary = rules.pieces[cell]
		_spawn_unit(int(piece["owner"]), cell, bool(piece["master"]))


func _spawn_unit(seat: int, cell: Vector2i, is_master: bool) -> BattleUnit:
	var color: Color = FfaFloor.SEAT_COLORS[seat]
	var unit := BattleUnit.new()
	unit.configure("S%d Figur" % (seat + 1), seat, cell, color.darkened(0.25), color.lightened(0.5))
	unit.is_master = is_master
	unit.rest_yaw = _yaw_toward_center(floor_grid.grid_to_world(cell))
	unit.rotation.y = unit.rest_yaw
	unit.scale = Vector3.ONE * (1.08 if unit.is_master else 1.0)
	units_root.add_child(unit)
	unit.position = floor_grid.grid_to_world(cell)
	floor_grid.set_occupant(cell, unit)
	unit.died.connect(_on_unit_died)
	_dress(unit, _looks[seat], color)
	_units.append(unit)
	return unit


static func _yaw_toward_center(world_position: Vector3) -> float:
	return atan2(-world_position.x, -world_position.z)


## Same dressing as the main match: the Master is the character, the rest are echoes.
func _dress(unit: BattleUnit, look: Dictionary, tint: Color) -> void:
	var character := CharacterRoster.dressed_character(look)
	var echo := str(CharacterRoster.echo_style(str(look.get("echo", "")))["id"])
	var fighter := FighterSprite.new()
	fighter.name = "FighterSprite"
	unit.apply_figure(fighter)
	if unit.is_master:
		fighter.build(character, tint)
	else:
		fighter.build(CharacterRoster.echo_look(echo, character, tint), tint, 0.75 if echo == "echo" else 0.0)
	unit.refresh_projections()


func _seat_name(seat: int) -> String:
	if _online and _is_human[seat] and _names[seat] != "":
		return _names[seat].to_upper() + (" (DU)" if not _spectator and seat == _my_seat else "")
	return ("SPIELER %d" if _is_human[seat] else "BOT %d") % (seat + 1)


## A human who sits at this device. Online only the own seat counts.
func _is_local(seat: int) -> bool:
	return not _spectator and _is_human[seat] and (not _online or seat == _my_seat)


## Bots run on this device; online only the host runs them and relays their turns.
func _runs_bot(seat: int) -> bool:
	return not _spectator and not _is_human[seat] and (not _online or _is_host)


func _begin_turn() -> void:
	if _reconnecting:
		_busy = true
		player_controller.enabled = false
		battle_ui.set_instruction("Verbindung wird wiederhergestellt. Bitte kurz warten.")
		return
	_deselect()
	var seat := rules.current
	_must_pass = rules.legal_moves(seat).is_empty() and not (_effects and FfaEffects.has_any(rules, seat))
	if _is_local(seat) and not _online:
		_view_seat = seat
		if _humans > 1:
			camera.set_seat_view(seat)
	_busy = not _is_local(seat)
	player_controller.enabled = _is_local(seat)
	_refresh_ui()
	var prefix := _notice + " " if _notice != "" else ""
	if _is_local(seat):
		battle_ui.set_instruction(prefix + ("Keine Figur kann ziehen. Tippe auf eine Karte, um sie abzugeben." if _must_pass else "%s: Wähle eine Karte und eine Figur." % _seat_name(seat)))
	elif _is_human[seat]:
		battle_ui.set_instruction(prefix + "%s ist am Zug ..." % _seat_name(seat))
	else:
		battle_ui.set_instruction(prefix + "%s denkt nach ..." % _seat_name(seat))
		if _runs_bot(seat):
			_run_bot()
	_drain_incoming.call_deferred()


func _refresh_ui() -> void:
	SoundBoard.set_danger_mode(_active and _has_core_threat())
	var view := _view_seat
	var own_turn := rules.current == view and _is_local(view) and rules.winner == FfaRules.RUNNING
	battle_ui.update_hands(
		[rules.hands[view], rules.hands[view]], rules.pass_card,
		0 if rules.current == view else -1, _slot if own_turn else -1,
		0, not own_turn, false, rules.current == view,
	)
	battle_ui.hand_titles[0].text = _seat_name(view)
	battle_ui.hand_titles[0].modulate = FfaFloor.SEAT_COLORS[view].lightened(0.3)
	var names: Array[String] = []
	for seat: int in range(FfaRules.PLAYERS):
		names.append(_seat_name(seat))
	_world_hands.show_seats(rules, view, rules.current)
	var giver := "GRID" if rules.pass_giver < 0 else names[rules.pass_giver]
	battle_ui.hand_titles[0].text += "  ·  2 + 1 WEITERGEREICHT"
	battle_ui.hand_titles[1].text = "↻ KARTE  %s → %s → %s" % [giver, names[rules.current], names[rules.next_after(rules.current)]]
	battle_ui.hand_titles[1].modulate = Color("ffc23a")
	var mover := rules.current
	battle_ui.set_header_text("RUNDE %02d  •  %s AM ZUG" % [rules.round_number, _seat_name(mover)], FfaFloor.SEAT_COLORS[mover].lightened(0.35))
	battle_ui.update_selection(_selected)


func _has_core_threat() -> bool:
	for cell: Vector2i in rules.pieces:
		var piece: Dictionary = rules.pieces[cell]
		if bool(piece["master"]) and rules.is_attacked(cell, int(piece["owner"])):
			return true
	return false


func _on_card_selected(team_id: int, slot: int) -> void:
	if not _active or _busy or team_id != 0 or slot < 0 or slot > 2 or rules.winner != FfaRules.RUNNING or not _is_local(rules.current):
		return
	SoundBoard.play("click")
	if _must_pass:
		_send_turn({"type": "pass", "slot": slot})
		rules.pass_turn(slot)
		_after_turn()
		return
	_slot = slot
	_effect_mode = false
	_refresh_targets()
	_refresh_ui()
	_refresh_effect_button()
	battle_ui.set_instruction("Tippe jetzt eine deiner Figuren." if _selected == null else "Tippe auf ein leuchtendes Feld.")


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _active or _busy or rules.winner != FfaRules.RUNNING or not _is_local(rules.current) or _must_pass:
		return
	if _effect_mode and _selected != null and _slot >= 0 and cell in _targets:
		_perform_effect(_selected, _slot, cell)
		return
	var clicked := floor_grid.get_unit_at(cell) as BattleUnit
	if clicked != null and clicked.team_id == rules.current:
		if _selected != null:
			_selected.set_selected(false)
		_selected = clicked
		_selected.set_selected(true)
		_refresh_targets()
		_refresh_ui()
		_refresh_effect_button()
		battle_ui.set_instruction("Wähle jetzt eine Karte." if _slot < 0 else "Tippe auf ein leuchtendes Feld.")
		return
	if _selected != null and _slot >= 0 and cell in _targets:
		_play(_selected, _slot, cell)
	elif _slot < 0:
		battle_ui.set_instruction("Wähle zuerst eine deiner zwei Karten.")
	else:
		battle_ui.set_instruction("Dieses Feld erlaubt die Karte nicht.")


func _on_cancel_requested() -> void:
	if not _active or _busy:
		return
	if _selected != null:
		_deselect()
		_refresh_ui()
	else:
		battle_ui.toggle_menu(true)


func _deselect() -> void:
	if _selected != null:
		_selected.set_selected(false)
	_selected = null
	_slot = -1
	_effect_mode = false
	_targets.clear()
	if floor_grid != null:
		floor_grid.clear_highlights()
	battle_ui.set_effect_button(false)


func _refresh_targets() -> void:
	_targets.clear()
	if _selected == null or _slot < 0:
		floor_grid.clear_highlights()
		return
	if _effect_mode:
		_targets = FfaEffects.targets(rules, _selected.grid_position, _slot)
	else:
		_targets = rules.targets_for(rules.current, _selected.grid_position, _slot)
	floor_grid.show_movement_targets(_targets, _selected.grid_position, rules.current)


## Animates in the fighter's style, then lets the rules apply the move.
## `announce` is false for a turn that came from the room.
func _play(unit: BattleUnit, slot: int, destination: Vector2i, announce: bool = true) -> void:
	_busy = true
	player_controller.enabled = false
	var game := _game_id
	var seat := rules.current
	var origin := unit.grid_position
	if announce:
		_send_turn({"type": "move", "from": origin, "slot": slot, "to": destination})
	var victim := floor_grid.get_unit_at(destination) as BattleUnit
	floor_grid.clear_highlights()
	unit.set_selected(false)
	var style := str(CharacterRoster.character(str(_looks[seat]["character"])).get("style", "brawler"))
	await unit_movement.perform_move(unit, victim, origin, destination, floor_grid, style, FfaFloor.SEAT_COLORS[seat])
	if game != _game_id:
		return
	unit.grid_position = destination
	floor_grid.move_occupant(unit, origin, destination)
	rules.apply_move(origin, slot, destination)
	_after_turn()


func _run_bot() -> void:
	var game := _game_id
	await get_tree().create_timer(bot_delay).timeout
	if game != _game_id or not _active or rules.winner != FfaRules.RUNNING:
		return
	var choice := _bot.choose_move(rules, rules.current)
	if choice.has("pass"):
		_send_turn({"type": "pass", "slot": int(choice["slot"])})
		rules.pass_turn(int(choice["slot"]))
		_after_turn()
		return
	var unit := floor_grid.get_unit_at(choice["from"]) as BattleUnit
	unit.set_selected(true)
	_selected = unit
	_slot = int(choice["slot"])
	_refresh_targets()
	await get_tree().create_timer(bot_delay * 0.5).timeout
	if game == _game_id and _active:
		await _play(unit, _slot, choice["to"])


func _after_turn() -> void:
	_turns_done += 1
	_selected = null
	_slot = -1
	var parts: PackedStringArray = []
	for seat: int in rules.last_events["core_lost"]:
		if rules.alive[seat]:
			parts.append("%s hat den KERN verloren und kämpft mit den Echos weiter." % _seat_name(seat))
	for seat: int in rules.last_events["eliminated"]:
		parts.append("%s %s" % [_seat_name(seat), GridLore.finite_out_line()])
	for revived: Dictionary in rules.last_events["revived"]:
		var seat := int(revived["player"])
		var is_core := bool(revived["master"])
		_spawn_unit(seat, revived["cell"], is_core)
		CombatEffects.pillar(units_root, floor_grid.grid_to_world(revived["cell"]), FfaFloor.SEAT_COLORS[seat])
		parts.append("%s bekommt den KERN zurück." % _seat_name(seat) if is_core else "%s bekommt einen Echo zurück." % _seat_name(seat))
	_sync_tiles()
	_sync_shields()
	if str(rules.last_events["tiles"]) != "":
		parts.append(str(rules.last_events["tiles"]))
	_notice = " ".join(parts)
	if rules.winner != FfaRules.RUNNING:
		_finish()
		return
	if _world_hands != null and rules.pass_giver >= 0:
		await _world_hands.animate_pass(rules.pass_giver, rules.current, rules.pass_card)
	_begin_turn()


## Tiles that collapsed take the pieces on them; holes and warnings show on the floor.
func _sync_tiles() -> void:
	for y: int in range(FfaRules.SIZE):
		for x: int in range(FfaRules.SIZE):
			var cell := Vector2i(x, y)
			floor_grid.set_tile_state(cell, 2 if rules.tiles.collapsed.has(cell) else (1 if rules.tiles.warned.has(cell) else 0))
	for unit: BattleUnit in _units:
		if is_instance_valid(unit) and not unit.is_dead and not rules.pieces.has(unit.grid_position):
			unit.play_death()


func _on_unit_died(unit: BattleUnit) -> void:
	floor_grid.remove_occupant(unit.grid_position, unit)


func _finish() -> void:
	_active = false
	SoundBoard.set_danger_mode(false)
	_busy = true
	player_controller.enabled = false
	_refresh_ui()
	var local_won := not _spectator and rules.winner >= 0 and (rules.winner == _my_seat if _online else _is_human[rules.winner])
	SoundBoard.play("victory" if local_won else "defeat")
	if _online and client != null:
		if _spectator:
			client.disconnect_from_host()
		else:
			client.finish_match()
	if _online and not _spectator:
		await battle_ui.main_menu.account.clear_live_match()
	if rules.winner == FfaRules.DRAW:
		battle_ui.show_result("UNENTSCHIEDEN")
	elif _spectator:
		battle_ui.show_result("ZUSCHAUEN · %s GEWINNT" % _seat_name(rules.winner))
	elif _humans == 1 or _online:
		battle_ui.show_result("SIEG!\n" + GridLore.win_line() if rules.winner == _my_seat else "NIEDERLAGE\n%s gewinnt." % _seat_name(rules.winner))
	else:
		battle_ui.show_result("%s GEWINNT" % _seat_name(rules.winner))
	if rules.winner >= 0:
		for unit: BattleUnit in _units:
			if unit.team_id == rules.winner and not unit.is_dead and unit.rig != null:
				unit.rig.call_deferred("perform_victory", str(_looks[rules.winner].get("character", "")))
				break


# --- card effects ------------------------------------------------------------

func _refresh_effect_button() -> void:
	var can_show := _effects and _active and not _busy and not _must_pass and _slot >= 0 and _is_local(rules.current)
	if not can_show:
		battle_ui.set_effect_button(false)
		return
	battle_ui.set_effect_button(true, "SCHRITT" if _effect_mode else CardEffect.button_text(FfaEffects.kind_of_slot(rules, _slot)))


## The EFFEKT button: switch between the card's step and its effect.
func _on_effect_requested() -> void:
	if not _active or _busy or not _effects or _slot < 0 or not _is_local(rules.current):
		return
	SoundBoard.play("click")
	_effect_mode = not _effect_mode
	_refresh_targets()
	_refresh_effect_button()
	if not _effect_mode:
		battle_ui.set_instruction("Schritt gewählt. Tippe auf ein leuchtendes Feld.")
	elif _selected == null:
		battle_ui.set_instruction("Wähle zuerst die Figur, die den Effekt auslöst.")
	elif _targets.is_empty():
		battle_ui.set_instruction("Kein Ziel für diesen Effekt. Schritt oder andere Figur wählen.")
	else:
		battle_ui.set_instruction(str(CardEffect.HINTS[FfaEffects.kind_of_slot(rules, _slot)]))


## Uses the card's effect on `target` instead of stepping. `announce` is false for turns from the room.
func _perform_effect(unit: BattleUnit, slot: int, target: Vector2i, announce: bool = true) -> void:
	_busy = true
	player_controller.enabled = false
	var game := _game_id
	var seat := rules.current
	var origin := unit.grid_position
	var kind := FfaEffects.kind_of_slot(rules, slot)
	var color: Color = FfaFloor.SEAT_COLORS[seat]
	var other := floor_grid.get_unit_at(target) as BattleUnit
	if announce:
		_send_turn({"type": "effect", "from": origin, "slot": slot, "to": target})
	floor_grid.clear_highlights()
	unit.set_selected(false)
	battle_ui.set_effect_button(false)
	match kind:
		CardEffect.Kind.STRIKE:
			CombatEffects.pillar(units_root, other.global_position, color)
			await other.shatter(unit.global_position, color)
		CardEffect.Kind.PUSH:
			await _slide_unit(other, FfaEffects.push_landing(rules, origin, target))
		CardEffect.Kind.SHIELD:
			CombatEffects.pillar(units_root, unit.global_position, color)
			await get_tree().create_timer(0.3).timeout
		CardEffect.Kind.SWAP:
			await _swap_units(unit, other)
	if game != _game_id:
		return
	rules.apply_effect(origin, slot, target)
	_after_turn()


func _slide_unit(unit: BattleUnit, landing: Vector2i) -> void:
	var from_cell := unit.grid_position
	var tween := unit.create_tween()
	tween.tween_property(unit, "position", floor_grid.grid_to_world(landing), 0.3)
	await tween.finished
	unit.grid_position = landing
	floor_grid.move_occupant(unit, from_cell, landing)


func _swap_units(first: BattleUnit, second: BattleUnit) -> void:
	var first_cell := first.grid_position
	first.grid_position = second.grid_position
	second.grid_position = first_cell
	floor_grid.set_occupant(first.grid_position, first)
	floor_grid.set_occupant(second.grid_position, second)
	var tween := first.create_tween().set_parallel(true)
	tween.tween_property(first, "position", floor_grid.grid_to_world(first.grid_position), 0.3)
	tween.tween_property(second, "position", floor_grid.grid_to_world(second.grid_position), 0.3)
	await tween.finished


## Shield markers follow the rules: a shield ends when its owner's next turn begins.
func _sync_shields() -> void:
	for unit: BattleUnit in _units:
		if is_instance_valid(unit) and not unit.is_dead:
			var shielded := rules.tiles.protected.has(unit.grid_position)
			if unit.shielded != shielded:
				unit.shielded = shielded
				unit.refresh_role_label()


# --- room with friends -------------------------------------------------------

## Opens a room as host; the lobby page shows who joins.
func create_room(settings: Dictionary, max_players: int) -> void:
	var room := _new_client()
	var menu := battle_ui.main_menu
	menu.show_group_lobby(room)
	if room.create_room(max_players, settings, menu.profile_name, menu.avatar_id) != OK:
		menu.toast_requested.emit("Keine Verbindung zum Server.")
		menu._show_home()


func resume_room(session: Dictionary) -> void:
	var room := _new_client()
	var menu := battle_ui.main_menu
	menu.show_group_lobby(room)
	if room.resume_session(session) != OK:
		room.disconnect_from_host()
		menu.toast_requested.emit("Die gespeicherte Finite-Grid-Partie kann nicht verbunden werden.")
		menu._show_home()


func join_room(code: String) -> void:
	var room := _new_client()
	var menu := battle_ui.main_menu
	menu.show_group_lobby(room)
	if room.join_room(code, menu.profile_name, menu.avatar_id) != OK:
		menu.toast_requested.emit("Keine Verbindung zum Server.")
		menu._show_home()


func watch_room(code: String, watch_key: String) -> void:
	var room := _new_client()
	battle_ui.main_menu.close_menu()
	battle_ui.set_instruction("Verbinde mit der Finite-Grid-Partie ...")
	if room.watch_room(code, watch_key) != OK:
		room.disconnect_from_host()
		battle_ui.main_menu.toast_requested.emit("Keine Verbindung zum Server.")
		battle_ui.main_menu._show_home()


func _new_client() -> GroupClient:
	if client != null:
		client.disconnect_from_host()
		client.queue_free()
	var room := GroupClient.new()
	room.name = "GroupClient"
	add_child(room)
	_attach_client(room)
	return room


## Listens to a room; the menu shows the lobby, the match starts when the host says so.
func _attach_client(room_client: GroupClient) -> void:
	client = room_client
	client.started.connect(start_online)
	client.resumed.connect(resume_online)
	client.watch_started.connect(watch_online)
	client.turn_received.connect(_on_turn_received)
	client.emote_received.connect(_on_emote_received)
	client.seat_away.connect(_on_seat_away)
	client.seat_back.connect(_on_seat_back)
	client.seat_left.connect(_on_seat_left)
	client.host_changed.connect(_on_host_changed)
	client.reconnecting.connect(_on_reconnecting)
	client.connection_lost.connect(_on_connection_lost)
	client.rejected.connect(func(_reason: String) -> void: _on_connection_lost())
	client.match_ended.connect(func() -> void:
		_active = false
		player_controller.enabled = false
		battle_ui.show_result("PARTIE BEENDET"))


func watch_online(info: Dictionary) -> void:
	_online = true
	_spectator = true
	_my_seat = 0
	_is_host = false
	var names: Array = info.get("names", [])
	for seat: int in range(FfaRules.PLAYERS):
		_names[seat] = str(names[seat])
	var settings: Dictionary = info.get("settings", {})
	var seats: Array = []
	for seat: Variant in info.get("humans", []):
		seats.append(int(seat))
	var resume_info := info.duplicate()
	resume_info["watching"] = true
	await _begin_game(
		seats, bool(settings.get("tiles", false)), int(info["seed"]),
		info["cards"] as Array, bool(settings.get("effects", false)), resume_info,
	)


func _leave_room() -> void:
	if client != null and _online and _active:
		client.leave()
		if not _spectator:
			battle_ui.main_menu.account.clear_live_match.call_deferred()


func is_active() -> bool:
	return _active


func play_local_emote(emote_id: String) -> void:
	if not _active or _spectator or EmoteWheel.entry(emote_id).is_empty():
		return
	var seat := _my_seat if _online else _view_seat
	_show_emote(seat, emote_id)
	if _online and client != null:
		client.send_emote(emote_id)


func _on_emote_received(seat: int, emote_id: String) -> void:
	if not _active or (not _spectator and seat == _my_seat):
		return
	_show_emote(seat, emote_id)


func _show_emote(seat: int, emote_id: String) -> void:
	if seat < 0 or seat >= FfaRules.PLAYERS or EmoteWheel.entry(emote_id).is_empty():
		return
	var fallback: BattleUnit
	for unit: BattleUnit in _units:
		if unit.team_id != seat or unit.is_dead:
			continue
		if fallback == null:
			fallback = unit
		if unit.is_master:
			EmoteStage.perform(units_root, unit, seat, emote_id)
			return
	if fallback != null:
		EmoteStage.perform(units_root, fallback, seat, emote_id)


## Turns of other seats come in numbered; they run one after another once the board is idle.
func _on_turn_received(turn: Dictionary) -> void:
	if not _online or not _active:
		return
	_incoming.append(turn)
	_drain_incoming()


func _drain_incoming() -> void:
	if not _online or not _active or _animating_remote or _incoming.is_empty() or rules.winner != FfaRules.RUNNING:
		return
	# On our own turn nothing from the others can be next.
	if _is_local(rules.current):
		return
	var turn: Dictionary = _incoming[0]
	if int(turn["seq"]) < _turns_done:
		_incoming.pop_front()
		_drain_incoming()
		return
	if int(turn["seq"]) > _turns_done or int(turn["seat"]) != rules.current:
		return
	_incoming.pop_front()
	_animating_remote = true
	await _apply_remote(turn)
	_animating_remote = false
	_drain_incoming()


func _apply_remote(turn: Dictionary) -> void:
	var slot := int(turn.get("slot", 0))
	if str(turn["type"]) == "pass":
		rules.pass_turn(slot)
		_after_turn()
		return
	var unit := floor_grid.get_unit_at(turn["from"]) as BattleUnit
	var seat := rules.current
	var is_effect := str(turn["type"]) == "effect"
	if unit == null or unit.team_id != seat or slot < 0 or slot > 1 or is_effect and not _effects:
		_out_of_sync()
		return
	var allowed := FfaEffects.targets(rules, unit.grid_position, slot) if is_effect else rules.targets_for(seat, unit.grid_position, slot)
	if not (turn["to"] as Vector2i) in allowed:
		_out_of_sync()
		return
	if is_effect:
		await _perform_effect(unit, slot, turn["to"], false)
	else:
		await _play(unit, slot, turn["to"], false)


func _out_of_sync() -> void:
	_active = false
	_busy = true
	player_controller.enabled = false
	if client != null:
		client.leave()
		if not _spectator:
			battle_ui.main_menu.account.clear_live_match.call_deferred()
	battle_ui.show_result("NICHT SYNCHRON\nDie Partie ist bei jemandem anders verlaufen.")


## Sends a turn of the seat to move; `fields` has type, slot and for moves from and to.
func _send_turn(fields: Dictionary) -> void:
	if not _online or client == null:
		return
	var turn := fields.duplicate()
	turn["seq"] = _turns_done
	turn["seat"] = rules.current
	client.send_turn(turn)


func _replay_turns(history: Array) -> bool:
	for index: int in range(history.size()):
		var turn: Variant = history[index]
		if not turn is Dictionary or int(turn.get("seq", -1)) != index or int(turn.get("seat", -1)) != rules.current:
			return false
		if rules.winner != FfaRules.RUNNING:
			return false
		var slot := int(turn.get("slot", -1))
		if slot < 0 or slot > 1:
			return false
		match str(turn.get("type", "")):
			"pass":
				if not rules.legal_moves(rules.current).is_empty() or (_effects and FfaEffects.has_any(rules, rules.current)):
					return false
				rules.pass_turn(slot)
			"move", "effect":
				var origin_value: Variant = turn.get("from")
				var target_value: Variant = turn.get("to")
				if not origin_value is Vector2i or not target_value is Vector2i:
					return false
				var origin: Vector2i = origin_value
				var target: Vector2i = target_value
				if not rules.pieces.has(origin) or int(rules.pieces[origin]["owner"]) != rules.current:
					return false
				var is_effect := str(turn["type"]) == "effect"
				if is_effect:
					if not _effects or target not in FfaEffects.targets(rules, origin, slot):
						return false
					rules.apply_effect(origin, slot, target)
				else:
					if target not in rules.targets_for(rules.current, origin, slot):
						return false
					rules.apply_move(origin, slot, target)
			_:
				return false
	return true


func _on_seat_away(seat: int, seconds: int) -> void:
	if _active:
		battle_ui.show_toast("%s ist kurz weg – bis zu %d Sekunden Geduld." % [_seat_name(seat), seconds])


func _on_seat_back(seat: int) -> void:
	if _active:
		battle_ui.show_toast("%s ist wieder da." % _seat_name(seat))


## The player is gone for good: a bot plays the figures from now on.
func _on_seat_left(seat: int) -> void:
	if not _active:
		return
	var name_before := _seat_name(seat)
	_is_human[seat] = false
	battle_ui.show_toast("%s hat verlassen. Ein Bot übernimmt." % name_before)
	_refresh_ui()
	if rules.current == seat and not _busy:
		_begin_turn()


func _on_host_changed(seat: int) -> void:
	if not _active or seat != _my_seat:
		return
	_is_host = true
	if _runs_bot(rules.current) and not _animating_remote:
		_begin_turn()


func _on_reconnecting() -> void:
	if not _online or not _active:
		return
	_reconnecting = true
	_busy = true
	player_controller.enabled = false
	_deselect()
	battle_ui.set_instruction("Verbindung unterbrochen. Finite Grid versucht es erneut ...")


func _on_connection_lost() -> void:
	if _online and _active:
		_active = false
		_busy = true
		player_controller.enabled = false
		if not _spectator:
			battle_ui.main_menu.account.clear_live_match.call_deferred()
		battle_ui.show_result("KEINE VERBINDUNG")


func _publish_live_match() -> void:
	var account := battle_ui.main_menu.account
	if account.username().is_empty() or client == null or client.watch_key.is_empty():
		return
	if not await account.publish_live_match("finite_grid", client.code, client.watch_key):
		battle_ui.main_menu.toast_requested.emit("Deine Partie konnte nicht in der Freundesliste angezeigt werden.")
