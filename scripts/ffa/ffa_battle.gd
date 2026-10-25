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
var _strip: FfaSeatStrip
var _top_row: Control


func setup(ui: GridBattleUI, camera_controller: CameraController, input: PlayerController, movement: UnitMovement, manager: GridBattleManager) -> void:
	battle_ui = ui
	camera = camera_controller
	player_controller = input
	unit_movement = movement
	battle_manager = manager
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
	_install_strip()
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_requested)
	battle_ui.card_selected.connect(_on_card_selected)


## The top card row of the HUD is swapped for the hands of the other players.
func _install_strip() -> void:
	_top_row = battle_ui.hand_anchors[1][0].get_parent() as Control
	_strip = FfaSeatStrip.new()
	_strip.visible = false
	var box := _top_row.get_parent()
	box.add_child(_strip)
	box.move_child(_strip, _top_row.get_index())


## humans: 0 (bots only, tests), 1, 2 (opposite seats) or 4.
func start(humans: int, shifting_tiles: bool) -> void:
	_game_id += 1
	var game := _game_id
	_humans = humans
	_shifting_tiles = shifting_tiles
	var seats: Array = {0: [], 1: [0], 2: [0, 2], 4: [0, 1, 2, 3]}.get(humans, [0])
	for seat: int in range(FfaRules.PLAYERS):
		_is_human[seat] = seat in seats
	_view_seat = 0
	_active = true
	_busy = true
	battle_ui.main_menu.close_menu()
	battle_manager.remember_ffa(humans, shifting_tiles)
	if _previous_grid == null:
		_previous_grid = player_controller.grid_manager
	player_controller.grid_manager = floor_grid
	rules = FfaRules.new()
	rules.setup(shifting_tiles)
	_bot = BotScript.new()
	_clear_units()
	floor_grid.setup()
	board_root.visible = true
	_top_row.visible = false
	_strip.visible = true
	camera.set_board(FfaRules.SIZE, false)
	camera.set_seat_view(0)
	_make_looks()
	_spawn_units()
	battle_ui.set_opponent_bot(true)
	_refresh_ui()
	battle_ui.set_instruction(GridLore.finite_start_line())
	await battle_ui.play_card_deal()
	if game == _game_id:
		_begin_turn()


func _clear_units() -> void:
	for unit: BattleUnit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()


func _make_looks() -> void:
	_looks.clear()
	var own := CharacterRoster.load_look()
	_looks.append(own)
	var used: Array[String] = [str(own["character"])]
	for seat: int in range(1, FfaRules.PLAYERS):
		var character_id := CharacterRoster.random_character_id()
		for _attempt: int in range(8):
			if character_id not in used:
				break
			character_id = CharacterRoster.random_character_id()
		used.append(character_id)
		_looks.append({"character": character_id, "skin": CharacterRoster.random_skin_id(character_id), "echo": own["echo"]})


func _spawn_units() -> void:
	for seat: int in range(FfaRules.PLAYERS):
		var color: Color = FfaFloor.SEAT_COLORS[seat]
		for index: int in range(5):
			var cell := FfaRules.start_cell(seat, index)
			var unit := BattleUnit.new()
			unit.configure("S%d Figur" % (seat + 1), seat, cell, color.darkened(0.25), color.lightened(0.5))
			unit.is_master = index == 2
			unit.rest_yaw = _yaw_toward_center(floor_grid.grid_to_world(cell))
			unit.rotation.y = unit.rest_yaw
			unit.scale = Vector3.ONE * (1.08 if unit.is_master else 1.0)
			units_root.add_child(unit)
			unit.position = floor_grid.grid_to_world(cell)
			floor_grid.set_occupant(cell, unit)
			unit.died.connect(_on_unit_died)
			_dress(unit, _looks[seat], color)
			_units.append(unit)


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
	return ("SPIELER %d" if _is_human[seat] else "BOT %d") % (seat + 1)


func _begin_turn() -> void:
	_deselect()
	var seat := rules.current
	_must_pass = rules.legal_moves(seat).is_empty()
	if _is_human[seat]:
		_view_seat = seat
		if _humans > 1:
			camera.set_seat_view(seat)
	_busy = not _is_human[seat]
	player_controller.enabled = _is_human[seat]
	_refresh_ui()
	var prefix := _notice + " " if _notice != "" else ""
	if _is_human[seat]:
		battle_ui.set_instruction(prefix + ("Keine Figur kann ziehen. Tippe auf eine Karte, um sie abzugeben." if _must_pass else "%s: Wähle eine Karte und eine Figur." % _seat_name(seat)))
	else:
		battle_ui.set_instruction(prefix + "%s denkt nach ..." % _seat_name(seat))
		_run_bot()


func _refresh_ui() -> void:
	var view := _view_seat
	var own_turn := rules.current == view and _is_human[view] and rules.winner == FfaRules.RUNNING
	battle_ui.update_hands([rules.hands[view], rules.hands[view]], rules.pass_card, 0, _slot if own_turn else -1, 0, not own_turn, false)
	battle_ui.hand_titles[0].text = _seat_name(view)
	battle_ui.hand_titles[0].modulate = FfaFloor.SEAT_COLORS[view].lightened(0.3)
	var names: Array[String] = []
	for seat: int in range(FfaRules.PLAYERS):
		names.append(_seat_name(seat))
	_strip.show_seats(rules, names, view)
	var giver := "GRID" if rules.pass_giver < 0 else names[rules.pass_giver]
	battle_ui.hand_titles[1].text = "↻ KARTE  %s → %s → %s" % [giver, names[rules.current], names[rules.next_after(rules.current)]]
	battle_ui.hand_titles[1].modulate = Color("ffc23a")
	var mover := rules.current
	battle_ui.set_header_text("RUNDE %02d  •  %s AM ZUG" % [rules.round_number, _seat_name(mover)], FfaFloor.SEAT_COLORS[mover].lightened(0.35))
	battle_ui.update_selection(_selected)


func _on_card_selected(team_id: int, slot: int) -> void:
	if not _active or _busy or team_id != 0 or slot < 0 or slot > 1 or rules.winner != FfaRules.RUNNING or not _is_human[rules.current]:
		return
	SoundBoard.play("click")
	if _must_pass:
		rules.pass_turn(slot)
		_after_turn()
		return
	_slot = slot
	_refresh_targets()
	_refresh_ui()
	battle_ui.set_instruction("Tippe jetzt eine deiner Figuren." if _selected == null else "Tippe auf ein leuchtendes Feld.")


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _active or _busy or rules.winner != FfaRules.RUNNING or not _is_human[rules.current] or _must_pass:
		return
	var clicked := floor_grid.get_unit_at(cell) as BattleUnit
	if clicked != null and clicked.team_id == rules.current:
		if _selected != null:
			_selected.set_selected(false)
		_selected = clicked
		_selected.set_selected(true)
		_refresh_targets()
		_refresh_ui()
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
	_targets.clear()
	if floor_grid != null:
		floor_grid.clear_highlights()


func _refresh_targets() -> void:
	_targets.clear()
	if _selected == null or _slot < 0:
		floor_grid.clear_highlights()
		return
	_targets = rules.targets_for(rules.current, _selected.grid_position, _slot)
	floor_grid.show_movement_targets(_targets, _selected.grid_position, rules.current)


## Animates in the fighter's style, then lets the rules apply the move.
func _play(unit: BattleUnit, slot: int, destination: Vector2i) -> void:
	_busy = true
	player_controller.enabled = false
	var game := _game_id
	var seat := rules.current
	var origin := unit.grid_position
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
	_selected = null
	_slot = -1
	var parts: PackedStringArray = []
	for seat: int in rules.last_events["eliminated"]:
		_make_ruins(seat)
		parts.append("%s %s" % [_seat_name(seat), GridLore.finite_out_line()])
	_sync_tiles()
	if str(rules.last_events["tiles"]) != "":
		parts.append(str(rules.last_events["tiles"]))
	_notice = " ".join(parts)
	if rules.winner != FfaRules.RUNNING:
		_finish()
		return
	_begin_turn()


## Pieces of an eliminated player stay as see-through ruins.
func _make_ruins(seat: int) -> void:
	for unit: BattleUnit in _units:
		if is_instance_valid(unit) and not unit.is_dead and unit.team_id == seat:
			unit.team_id = -1
			unit.is_master = false
			unit.role_override = "RUINE"
			unit.refresh_role_label()
			unit._set_projection_transparency(unit.visual_root, 0.55)


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
	_busy = true
	player_controller.enabled = false
	_refresh_ui()
	var local_won := rules.winner >= 0 and _is_human[rules.winner]
	SoundBoard.play("victory" if local_won else "defeat")
	if rules.winner == FfaRules.DRAW:
		battle_ui.show_result("UNENTSCHIEDEN")
	elif _humans == 1:
		battle_ui.show_result("SIEG!\n" + GridLore.win_line() if rules.winner == 0 else "NIEDERLAGE\n%s gewinnt." % _seat_name(rules.winner))
	else:
		battle_ui.show_result("%s GEWINNT" % _seat_name(rules.winner))
