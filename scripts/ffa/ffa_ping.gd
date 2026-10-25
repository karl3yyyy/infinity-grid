class_name FfaPing
extends PingPhase

## Node Ping for up to four players before a Finite Grid match: every human taps
## a secret spot (bots get a random one), a signal flashes up, the closest seat
## chooses to start or to move last. Several exact ties in front mean another
## round. Online the server rolls the signal. Headless runs (tests) skip the screen.

var silent: bool = DisplayServer.get_name() == "headless"


## Same device: the humans tap one after another. Returns the seat that starts.
func run_seats(humans: Array) -> int:
	_begin_ping()
	var winner := -1
	var picks: Array = []
	while winner < 0:
		picks.clear()
		for seat: int in range(FfaRules.PLAYERS):
			if seat in humans:
				var intro := (GridLore.rival_line() + "\n") if humans.size() == 1 else ""
				picks.append(await _pick("%sSPIELER %d: tippe geheim irgendwohin. Wer näher am Signal liegt, entscheidet, wer beginnt." % [intro, seat + 1]))
			else:
				picks.append(_random_spot())
		var signal_spot := _random_spot()
		winner = closest_seat(picks, signal_spot)
		await _show_result(picks, signal_spot, winner)
	var starter := winner
	if winner in humans:
		starter = await _ask_start(winner, "SPIELER %d war näher" % (winner + 1))
	elif not silent:
		overlay.set_text("BOT %d war näher und beginnt." % (winner + 1))
		await get_tree().create_timer(0.8).timeout
	await _end_ping()
	return starter


## Online: our pick goes to the room, which rolls the signal. Returns the starting seat.
func run_online(client: GroupClient, seat: int) -> int:
	_begin_ping()
	while true:
		var pick := await _pick("Tippe geheim irgendwohin. Wer näher am Signal liegt, entscheidet, wer beginnt.")
		if not silent:
			overlay.mark(pick, FfaFloor.SEAT_COLORS[seat], str(seat + 1))
			overlay.set_text("Warte auf die anderen ...")
		client.send_node_ping(pick)
		var result: Dictionary = await client.ping_result
		var picks: Array = []
		for value: Variant in result.get("picks", []):
			picks.append(Vector2(float(value[0]), float(value[1])))
		var signal_values: Array = result.get("signal", [0, 0])
		var winner := int(result.get("winner", -1))
		await _show_result(picks, Vector2(float(signal_values[0]), float(signal_values[1])), winner)
		if winner < 0:
			continue
		if winner == seat:
			client.send_choose(await _ask_start(winner, "Du warst näher"))
		elif not silent:
			overlay.set_text("SPIELER %d war näher und wählt, wer beginnt ..." % (winner + 1))
		break
	var chosen: int = await client.starter_chosen
	await _end_ping()
	return chosen


## The seat with the closest pick, or -1 when the best distance is shared.
static func closest_seat(picks: Array, signal_spot: Vector2) -> int:
	var best := INF
	var winner := -1
	var shared := false
	for seat: int in range(picks.size()):
		var spot_distance := distance(picks[seat], signal_spot)
		if spot_distance < best:
			best = spot_distance
			winner = seat
			shared = false
		elif spot_distance == best:
			shared = true
	return -1 if shared else winner


func _begin_ping() -> void:
	if silent:
		return
	_begin()


func _end_ping() -> void:
	battle.pinging = false
	if silent:
		queue_free()
		return
	await _end()


func _pick(text: String) -> Vector2:
	if silent:
		await get_tree().process_frame
		return _random_spot()
	if not overlay.is_open():
		await overlay.open()
	return await overlay.ask_pick(text)


func _show_result(picks: Array, signal_spot: Vector2, winner: int) -> void:
	if silent:
		return
	var colors: Array[Color] = []
	var labels: Array[String] = []
	for seat: int in range(picks.size()):
		colors.append(FfaFloor.SEAT_COLORS[seat])
		labels.append(str(seat + 1))
	await overlay.reveal(picks, signal_spot, colors, labels)
	if winner < 0:
		SoundBoard.play("glitch")
		SoundBoard.say("collision")
		overlay.set_text(GridLore.collision_line())
	else:
		overlay.set_text("SPIELER %d war näher am Signal." % (winner + 1))
	await get_tree().create_timer(1.0).timeout


## The closest player starts, or moves last (the next seat then starts).
func _ask_start(winner: int, who: String) -> int:
	if silent:
		return winner
	var index := await overlay.ask_choice("%s – wer beginnt?" % who, "ICH BEGINNE", "ICH BIN ZULETZT", CHOICE_SECONDS)
	return winner if index == 0 else (winner + 1) % FfaRules.PLAYERS
