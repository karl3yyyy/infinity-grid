class_name NetworkMatch
extends Node

## Runs a match against another device: owns the MatchClient, replays the
## opponent's turns in order, catches up after a reconnect and keeps the
## player informed. The battle manager stays responsible for the rules.

const MatchClientScript := preload("res://scripts/network/match_client.gd")
## Quick play offers the bot after this long without an opponent.
const QUICK_BOT_OFFER_SECONDS: float = 30.0
## Animations run faster while catching up on several missed turns.
const CATCH_UP_TIME_SCALE: float = 6.0

var battle: GridBattleManager
var ui: GridBattleUI
var client: MatchClient
## Turns from the server not applied yet, each with its "seq".
var _pending_turns: Array[Dictionary] = []
var _applying: bool = false
var _started: bool = false
var _quick_wait: float = -1.0
## Ranked games: no bot offer while waiting, the server rates the result.
var ranked: bool = false
## A friend to invite once the room code is known (challenge from the friends list).
var invite_username: String = ""
## Ranked only; the server's clock replaces the per-move timer of normal games.
var chess_clock: ChessClock


func setup(battle_manager: GridBattleManager, battle_ui: GridBattleUI) -> void:
	battle = battle_manager
	ui = battle_ui
	# Keep the connection alive while the pause menu is open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	client = MatchClientScript.new()
	client.name = "MatchClient"
	add_child(client)
	client.queued.connect(_on_queued)
	client.room_created.connect(func(code: String) -> void:
		if invite_username.is_empty():
			ui.set_instruction("Raum-Code: %s  –  schick ihn deinem Gegner und warte." % code)
		else:
			ui.set_instruction("%s ist eingeladen. Warte, bis die Einladung angenommen wird ..." % invite_username)
			ui.main_menu.account.friends("invite", {"username": invite_username, "code": code}))
	client.matched.connect(func(opponent: Dictionary) -> void:
		if ranked and opponent.has("name"):
			ui.set_instruction("Gegner gefunden: %s  ·  %s %d" % [opponent["name"], opponent.get("rank", ""), int(opponent.get("rating", 0))]))
	chess_clock = ChessClock.new()
	chess_clock.name = "ChessClock"
	add_child(chess_clock)
	chess_clock.ticked.connect(ui.set_chess_clock)
	client.clock_synced.connect(_on_clock_synced)
	client.ranked_result.connect(func(result: Dictionary) -> void:
		chess_clock.stop()
		if battle._spectator_mode:
			battle.end_with_message("PARTIE BEENDET")
		else:
			battle.show_ranked_result(result))
	client.opponent_emote.connect(func(emote_id: String) -> void:
		if battle.network_team >= 0:
			battle.show_emote(1 - battle.network_team, emote_id))
	client.watch_emote.connect(func(team: int, emote_id: String) -> void:
		if battle._spectator_mode:
			battle.show_emote(team, emote_id))
	client.watch_look.connect(func(team: int, look: Dictionary) -> void:
		if battle._spectator_mode and team >= 0 and team < 2:
			battle.apply_team_look(team, look))
	client.match_ended.connect(func() -> void:
		battle.end_with_message("PARTIE BEENDET"))
	client.match_started.connect(_on_match_started)
	client.watch_started.connect(_on_watch_started)
	client.resumed.connect(_on_resumed)
	client.opponent_moved.connect(_on_opponent_moved)
	client.opponent_away.connect(func(seconds: int) -> void:
		if not battle.battle_over:
			ui.set_instruction("Gegner ist kurz weg – wir warten bis zu %d Sekunden ..." % seconds))
	client.opponent_back.connect(func() -> void:
		if not battle.battle_over:
			battle.refresh_turn_instruction())
	client.opponent_left.connect(func() -> void:
		ui.main_menu.account.clear_live_match.call_deferred()
		battle.end_with_message("GEGNER IST WEG"))
	client.opponent_look.connect(func(look: Dictionary) -> void:
		if battle.network_team >= 0:
			battle.apply_team_look(1 - battle.network_team, look))
	client.reconnecting.connect(func() -> void:
		if not battle.battle_over:
			ui.set_instruction("Verbindung weg – verbinde neu ..."))
	client.rejected.connect(_on_rejected)
	client.connection_lost.connect(func() -> void:
		ui.main_menu.account.clear_live_match.call_deferred()
		battle.end_with_message("KEINE VERBINDUNG"))


func start(url: String, connecting_text: String, connected_text: String) -> void:
	client.connected.connect(func() -> void:
		if not _started and not client.is_reconnecting():
			ui.set_instruction(connected_text))
	ui.set_instruction(connecting_text)
	if client.connect_to_host(url) != OK:
		battle.end_with_message("KEINE VERBINDUNG")


func resume(session: Dictionary) -> void:
	ui.set_instruction("Verbinde mit deiner Partie ... Kabel werden gestreichelt.")
	if client.resume_session(session) != OK:
		battle.end_with_message("KEINE VERBINDUNG")


func watch(url: String) -> void:
	ui.set_instruction("Verbinde mit der Partie ...")
	if client.watch(url) != OK:
		battle.end_with_message("KEINE VERBINDUNG")


## The local player made a turn; seq is its number in the match.
func send_local_turn(message: Dictionary) -> void:
	if message["type"] == "pass":
		client.send_pass(int(message["seq"]), int(message["slot"]))
	else:
		client.send_move(int(message["seq"]), message["from"], int(message["slot"]), message["to"])


## The match ended on the board; nothing is left to resume.
func finished() -> void:
	chess_clock.stop()
	client.finish_match()


func _on_clock_synced(left_ms: Array, to_move: int) -> void:
	if battle.battle_over or battle.network_team < 0:
		return
	# Only ranked rooms send a clock, also after a reload where `ranked` was unknown.
	ranked = true
	battle.turn_timer.stop()
	chess_clock.viewer_team = battle.network_team
	chess_clock.sync(left_ms, to_move)


## The player quits (restart, menu); the opponent is told right away.
func leave() -> void:
	chess_clock.stop()
	client.leave()


func _process(delta: float) -> void:
	if _quick_wait < 0.0 or _started:
		return
	_quick_wait -= delta
	if _quick_wait < 0.0:
		ui.set_instruction("Noch kein Gegner da. Das Grid sucht, so schnell es kann. Du kannst warten oder gegen den Bot spielen.")
		ui.show_side_action("GEGEN DEN BOT SPIELEN", battle.switch_to_bot)


func _on_queued() -> void:
	ui.set_instruction("Suche einen Ranked-Gegner ..." if ranked else "Suche einen Gegner ...")
	if _quick_wait < 0.0 and not ranked:
		_quick_wait = QUICK_BOT_OFFER_SECONDS


func _on_match_started(team: int, card_names: Array) -> void:
	if _started:
		return
	_quick_wait = -1.0
	ui.hide_side_action()
	if not battle.begin_network_match(team, card_names):
		battle.end_with_message("FEHLER BEIM START")
		return
	_started = true
	client.send_look(CharacterRoster.load_look())
	# The online server runs a Node Ping first; the PC host lets team 0 start.
	var starter := 0
	if client.ping_required:
		starter = await battle._ping_phase().run_network(client, team)
	await battle.set_starter(starter)
	if not client.watch_key.is_empty():
		var account := ui.main_menu.account
		if not account.username().is_empty():
			var published: bool = await account.publish_live_match("duel", client.code, client.watch_key)
			if not published:
				ui.main_menu.toast_requested.emit("Deine Partie konnte nicht in der Freundesliste angezeigt werden.")


func _on_watch_started(info: Dictionary) -> void:
	if _started or not battle.begin_network_match(-1, info.get("cards", []) as Array):
		battle.end_with_message("PARTIE KANN NICHT GELADEN WERDEN")
		return
	battle._spectator_mode = true
	battle.match_mode = "network"
	battle.bot_opponent_enabled = false
	battle.network_team = -1
	battle.battle_ui.set_opponent_remote(true)
	battle.battle_ui.spectating = true
	_started = true
	var looks: Array = info.get("looks", [])
	for team: int in range(mini(2, looks.size())):
		if looks[team] is Dictionary and not (looks[team] as Dictionary).is_empty():
			battle.apply_team_look(team, looks[team])
	await battle.set_starter(int(info.get("starter", -1)))
	for index: int in range((info.get("moves", []) as Array).size()):
		var turn: Dictionary = (info["moves"] as Array)[index]
		turn["seq"] = index
		_pending_turns.append(turn)
	await play_pending_turns()


func _on_resumed(team: int, card_names: Array, moves: Array) -> void:
	if not _started:
		if not battle.begin_network_match(team, card_names):
			battle.end_with_message("FEHLER BEIM START")
			return
		_started = true
		client.send_look(CharacterRoster.load_look())
		# Back after a reload: the starter is known, or the Node Ping is still open.
		var starter := client.resumed_starter
		if starter < 0:
			starter = await battle._ping_phase().run_network(client, team)
		await battle.set_starter(starter)
	else:
		client.send_look(CharacterRoster.load_look())
	for index: int in range(moves.size()):
		var turn: Dictionary = moves[index]
		turn["seq"] = index
		_pending_turns.append(turn)
	await play_pending_turns()
	if not client.watch_key.is_empty():
		var account := ui.main_menu.account
		if not account.username().is_empty():
			var published: bool = await account.publish_live_match("duel", client.code, client.watch_key)
			if not published:
				ui.main_menu.toast_requested.emit("Deine Partie konnte nicht in der Freundesliste angezeigt werden.")
	if not battle.battle_over:
		battle.refresh_turn_instruction()


func _on_opponent_moved(message: Dictionary) -> void:
	_pending_turns.append(message)
	play_pending_turns()


## Applies waiting turns strictly in order. Turns this device already played
## (own moves, or opponent moves seen before a reconnect) are skipped.
func play_pending_turns() -> void:
	if _applying:
		return
	_applying = true
	while not battle.battle_over:
		var turn := _take_next_turn()
		if turn.is_empty():
			break
		var catching_up := not _pending_turns.is_empty()
		if catching_up:
			Engine.time_scale = CATCH_UP_TIME_SCALE
		var applied: bool = await battle.apply_network_turn(turn)
		Engine.time_scale = 1.0
		if not applied:
			battle.end_with_message("SPIELSTAND WEICHT AB")
			break
	_applying = false


func _take_next_turn() -> Dictionary:
	var played := battle.turns_played
	for index: int in range(_pending_turns.size() - 1, -1, -1):
		# The PC host relays turns without a number; they are always the next one.
		var seq := int(_pending_turns[index].get("seq", played))
		if seq < played:
			_pending_turns.remove_at(index)
	for index: int in range(_pending_turns.size()):
		if int(_pending_turns[index].get("seq", played)) == played:
			var turn: Dictionary = _pending_turns[index]
			_pending_turns.remove_at(index)
			return turn
	return {}


func _on_rejected(reason: String) -> void:
	match reason:
		"not_found":
			battle.end_with_message("RAUM NICHT GEFUNDEN")
		"full":
			battle.end_with_message("RAUM IST VOLL")
		"code_taken":
			battle.end_with_message("BITTE NOCHMAL VERSUCHEN")
		"match_over":
			battle.end_with_message("PARTIE IST VORBEI")
		_:
			battle.end_with_message("VERBINDUNG ABGELEHNT")
