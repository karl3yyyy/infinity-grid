class_name PingPhase
extends Node

## "Node Ping" before every match: both players secretly tap a square on a
## full-screen panel (PingOverlay, apart from the board), then a signal flashes
## up on a random square. Whoever tapped closer (the field wraps left/right)
## chooses who moves first; equal distance is a "Signal Collision" and both
## tap again. Online the server rolls the signal.

## Without an answer the winner simply starts.
const CHOICE_SECONDS: float = 5.0

var battle: OnitamaBattleManager
var controller: PlayerController
var overlay: PingOverlay


func setup(battle_manager: OnitamaBattleManager, input: PlayerController) -> void:
	battle = battle_manager
	controller = input
	overlay = PingOverlay.new()
	add_child(overlay)


## Squared distance between two spots (0..1 across the free square).
static func distance(a: Vector2, b: Vector2) -> float:
	return a.distance_squared_to(b)


## 0 or 1 for the closer pick, -1 for a collision (exactly equal).
static func winner_of(picks: Array, signal_spot: Vector2) -> int:
	var a := distance(picks[0], signal_spot)
	var b := distance(picks[1], signal_spot)
	return -1 if a == b else (0 if a < b else 1)


## Bot and same-device matches; returns the team that starts.
func run_local(against_bot: bool) -> int:
	_begin()
	await overlay.open()
	var winner := -1
	while winner < 0:
		var first := await overlay.ask_pick(GridLore.rival_line() + "\nTippe geheim irgendwohin. Wer näher am Signal liegt, entscheidet, wer beginnt." if against_bot else "SPIELER 1: tippe geheim irgendwohin.")
		var second: Vector2 = _random_spot() if against_bot else await overlay.ask_pick("SPIELER 2: tippe geheim irgendwohin. Spieler 1 schaut weg!")
		var signal_spot := _random_spot()
		winner = winner_of([first, second], signal_spot)
		await _reveal([first, second], signal_spot, winner, 0 if against_bot else -1)
	var starter := 1
	if against_bot and winner == 1:
		overlay.set_text("Der Bot war näher und beginnt.")
		await get_tree().create_timer(0.8).timeout
	else:
		var who := "Du warst näher" if against_bot else "Spieler %d war näher" % (winner + 1)
		starter = await _ask_choice(winner, who, not against_bot)
	await _end()
	return starter


## Online: picks go to the server, which rolls the signal; returns the starter.
func run_network(client: MatchClient, team: int) -> int:
	_begin()
	await overlay.open()
	while true:
		var pick := await overlay.ask_pick("Tippe geheim irgendwohin. Wer näher am Signal liegt, entscheidet, wer beginnt.")
		overlay.mark(pick, OnitamaUI.TEAM_COLORS[team], str(team + 1))
		client.send_node_ping(pick)
		overlay.set_text("Warte auf das Signal ...")
		var result: Dictionary = await client.ping_result
		var picks: Array = []
		for value: Variant in result.get("picks", []):
			picks.append(Vector2(float(value[0]), float(value[1])))
		var signal_values: Array = result.get("signal", [0, 0])
		var winner := int(result.get("winner", -1))
		await _reveal(picks, Vector2(float(signal_values[0]), float(signal_values[1])), winner, team)
		if winner < 0:
			continue
		MatchStats.add("pings")
		if winner == team:
			MatchStats.add("ping_wins")
			var starter := await _ask_choice(team, "Du warst näher", false)
			client.send_choose(starter)
		else:
			overlay.set_text("Der Gegner war näher und wählt, wer beginnt ...")
		break
	var chosen: int = await client.starter_chosen
	await _end()
	return chosen


func _begin() -> void:
	SoundBoard.play("boot")
	SoundBoard.say("ping")
	battle.pinging = true
	battle.input_locked = false
	controller.enabled = false


func _end() -> void:
	await overlay.close()
	queue_free()


## Shows both picks and the signal; viewer is the team on this device (-1: both).
func _reveal(picks: Array, signal_spot: Vector2, winner: int, viewer: int) -> void:
	await overlay.reveal(picks, signal_spot)
	if winner < 0:
		SoundBoard.play("glitch")
		SoundBoard.say("collision")
		overlay.set_text(GridLore.collision_line())
	elif viewer >= 0:
		overlay.set_text("Du warst näher am Signal." if winner == viewer else "Der Gegner war näher am Signal.")
	else:
		overlay.set_text("Spieler %d war näher am Signal." % (winner + 1))
	await get_tree().create_timer(1.0).timeout


func _ask_choice(winner: int, who: String, same_device: bool) -> int:
	var me := "SPIELER %d BEGINNT" % (winner + 1) if same_device else "ICH BEGINNE"
	var other := "SPIELER %d BEGINNT" % (2 - winner) if same_device else "GEGNER BEGINNT"
	var index := await overlay.ask_choice("%s – wer beginnt?" % who, me, other, CHOICE_SECONDS)
	return winner if index == 0 else 1 - winner


func _random_spot() -> Vector2:
	return Vector2(randf(), randf())
