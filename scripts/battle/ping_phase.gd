class_name PingPhase
extends Node

## "Node Ping" before every match: both players secretly tap a square, then a
## signal flashes up on a random square. Whoever tapped closer (the board wraps
## left/right) chooses who moves first; equal distance is a "Signal
## Collision" and both tap again. Online the server rolls the signal.

signal _picked(cell: Vector2i)
signal _chosen(starter: int)

## Without an answer the winner simply starts.
const CHOICE_SECONDS: float = 8.0

var battle: OnitamaBattleManager
var ui: OnitamaUI
var grid: GridManager
var controller: PlayerController
var _waiting_pick: bool = false
var _marks: Array[Node3D] = []


func setup(battle_manager: OnitamaBattleManager, battle_ui: OnitamaUI, grid_manager: GridManager, input: PlayerController) -> void:
	battle = battle_manager
	ui = battle_ui
	grid = grid_manager
	controller = input
	controller.cell_clicked.connect(_on_cell_clicked)


## Distance used for the ping, with the left/right wraparound.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dx := absi(a.x - b.x)
	var wrapped := mini(dx, 5 - dx)
	return wrapped * wrapped + (a.y - b.y) * (a.y - b.y)


## 0 or 1 for the closer pick, -1 for a collision.
static func winner_of(picks: Array, signal_cell: Vector2i) -> int:
	var a := distance(picks[0], signal_cell)
	var b := distance(picks[1], signal_cell)
	return -1 if a == b else (0 if a < b else 1)


## Bot and same-device matches; returns the team that starts.
func run_local(against_bot: bool) -> int:
	_begin()
	var winner := -1
	while winner < 0:
		var first := await _ask_pick("NODE PING – tippe geheim ein Feld. Wer näher am Signal liegt, entscheidet, wer beginnt." if against_bot else "NODE PING – SPIELER 1: tippe geheim ein Feld.")
		var second := Vector2i(randi_range(0, 4), randi_range(0, 4)) if against_bot else await _ask_pick("SPIELER 2: tippe geheim ein Feld. Spieler 1 schaut weg!")
		var signal_cell := Vector2i(randi_range(0, 4), randi_range(0, 4))
		winner = winner_of([first, second], signal_cell)
		await _reveal([first, second], signal_cell, winner, 0 if against_bot else -1)
	var starter := 1
	if against_bot and winner == 1:
		ui.set_instruction("Der Bot war näher und beginnt.")
		await get_tree().create_timer(1.4).timeout
	else:
		var who := "Du warst näher" if against_bot else "Spieler %d war näher" % (winner + 1)
		starter = await _ask_choice(winner, who, not against_bot)
	_end()
	return starter


## Online: picks go to the server, which rolls the signal; returns the starter.
func run_network(client: MatchClient, team: int) -> int:
	_begin()
	while true:
		var pick := await _ask_pick("NODE PING – tippe geheim ein Feld. Wer näher am Signal liegt, entscheidet, wer beginnt.")
		_mark(pick, OnitamaUI.TEAM_COLORS[team])
		client.send_node_ping(pick)
		ui.set_instruction("Warte auf das Signal ...")
		var result: Dictionary = await client.ping_result
		var picks: Array = []
		for value: Variant in result.get("picks", []):
			picks.append(Vector2i(int(value[0]), int(value[1])))
		var signal_values: Array = result.get("signal", [0, 0])
		var winner := int(result.get("winner", -1))
		await _reveal(picks, Vector2i(int(signal_values[0]), int(signal_values[1])), winner, team)
		if winner < 0:
			continue
		if winner == team:
			var starter := await _ask_choice(team, "Du warst näher", false)
			client.send_choose(starter)
		else:
			ui.set_instruction("Der Gegner war näher und wählt, wer beginnt ...")
		break
	var chosen: int = await client.starter_chosen
	_end()
	return chosen


func _begin() -> void:
	SoundBoard.play("boot")
	SoundBoard.say("ping")
	battle.pinging = true
	battle.input_locked = false
	controller.enabled = true


func _end() -> void:
	_clear_marks()
	ui.hide_side_action()
	queue_free()


func _ask_pick(text: String) -> Vector2i:
	ui.set_instruction(text)
	controller.enabled = true
	_waiting_pick = true
	return await _picked


func _on_cell_clicked(cell: Vector2i) -> void:
	if _waiting_pick and grid.is_inside(cell):
		_waiting_pick = false
		SoundBoard.play("select")
		_picked.emit(cell)


## Shows both picks and the signal; viewer is the team on this device (-1: both).
func _reveal(picks: Array, signal_cell: Vector2i, winner: int, viewer: int) -> void:
	controller.enabled = false
	_clear_marks()
	for team: int in range(2):
		_mark(picks[team], OnitamaUI.TEAM_COLORS[team])
	await get_tree().create_timer(0.6).timeout
	SoundBoard.play("signal")
	var at := grid.grid_to_world(signal_cell)
	CombatEffects.lightning(grid, at + Vector3(0.0, 6.0, 0.0), at, Color("e8ffe0"))
	CombatEffects.burst(grid, at, Color("6ee65a"), 1.1)
	CombatEffects.pillar(grid, at, Color("6ee65a"))
	if winner < 0:
		SoundBoard.play("glitch")
		SoundBoard.say("collision")
		ui.set_instruction("SIGNAL COLLISION! Beide gleich weit weg – nochmal.")
	elif viewer >= 0:
		ui.set_instruction("Du warst näher am Signal." if winner == viewer else "Der Gegner war näher am Signal.")
	else:
		ui.set_instruction("Spieler %d war näher am Signal." % (winner + 1))
	await get_tree().create_timer(1.8).timeout
	_clear_marks()


func _ask_choice(winner: int, who: String, same_device: bool) -> int:
	var me := "SPIELER %d BEGINNT" % (winner + 1) if same_device else "ICH BEGINNE"
	var other := "SPIELER %d BEGINNT" % (2 - winner) if same_device else "GEGNER BEGINNT"
	ui.set_instruction("%s – wer beginnt?" % who)
	ui.show_choice(me, func() -> void: _chosen.emit(winner), other, func() -> void: _chosen.emit(1 - winner))
	get_tree().create_timer(CHOICE_SECONDS).timeout.connect(func() -> void: _chosen.emit(winner))
	var starter: int = await _chosen
	ui.hide_side_action()
	return starter


func _mark(cell: Vector2i, color: Color) -> void:
	_marks.append(CombatEffects.magic_circle(grid, grid.grid_to_world(cell), color))


func _clear_marks() -> void:
	for mark: Node3D in _marks:
		if is_instance_valid(mark):
			CombatEffects.dismiss(mark)
	_marks.clear()
