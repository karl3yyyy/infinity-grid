class_name FfaRules
extends RefCounted

## Four-player free-for-all on a flat, closed square board. Every player starts
## on one side (0 bottom, 1 left, 2 top, 3 right) and moves toward the opposite
## side. Losing the Master (the core) does not end the game: the player goes on
## with the echoes. Taking a core gives the taker their own core back (or a lost
## echo). A player without any piece is out; the last one left wins. Node-free, so bots and tests use it directly.

const SIZE: int = 9
const PLAYERS: int = 4
const NEUTRAL: int = -1
const PIECES_PER_PLAYER: int = 5
const ROUND_LIMIT: int = 120
const RUNNING: int = -2
const DRAW: int = -1

## cell -> {"owner": int, "master": bool}
var pieces: Dictionary = {}
var hands: Array = []
var pass_card: MovementCard
var alive: Array[bool] = [true, true, true, true]
var current: int = 0
var round_number: int = 1
var winner: int = RUNNING
## Who played the card now waiting in the middle (-1: nobody yet).
var pass_giver: int = -1
var tiles := ChaosRules.new()
## Chaos card effects: a turn may use a card's effect instead of its step.
var card_effects: bool = false
## What the last turn changed, for the screen: eliminated players and tile messages.
var last_events: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Online every client gets the same `card_names` (nine cards) and `rng_seed`, so all play the same game.
func setup(shifting_tiles: bool, rng_seed: int = -1, card_names: Array = [], effects: bool = false) -> void:
	card_effects = effects
	var deck := MovementCard.cards_from_names(card_names) if card_names.size() == PLAYERS * 2 + 1 else FfaDeck.draw(PLAYERS * 2 + 1)
	if rng_seed >= 0:
		_rng.seed = rng_seed
	for player: int in range(PLAYERS):
		hands.append([deck[player * 2], deck[player * 2 + 1]])
	pass_card = deck[PLAYERS * 2]
	tiles.shifting_tiles = shifting_tiles
	for player: int in range(PLAYERS):
		for index: int in range(PIECES_PER_PLAYER):
			pieces[start_cell(player, index)] = {"owner": player, "master": index == 2}


## Five pieces along a side, Master in the middle; corners stay empty.
static func start_cell(player: int, index: int) -> Vector2i:
	var along := 2 + index
	var edge := SIZE - 1
	match player:
		0:
			return Vector2i(along, edge)
		1:
			return Vector2i(0, along)
		2:
			return Vector2i(edge - along, 0)
		_:
			return Vector2i(edge, edge - along)


## Screen-space step of a card offset for a player: (x right, y up) turned
## clockwise once per seat, so every player's "forward" points at the far side.
static func step_for(offset: Vector2i, player: int) -> Vector2i:
	var delta := Vector2i(offset.x, -offset.y)
	for _turn: int in range(player):
		delta = Vector2i(-delta.y, delta.x)
	return delta


static func destinations(card: MovementCard, origin: Vector2i, player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in card.offsets:
		var cell := origin + step_for(offset, player)
		if cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE and cell not in result:
			result.append(cell)
	return result


func cells_of(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in pieces.keys():
		if int(pieces[cell]["owner"]) == player:
			result.append(cell)
	return result


func can_enter(player: int, cell: Vector2i) -> bool:
	if tiles.is_blocked(cell):
		return false
	if not pieces.has(cell):
		return true
	return int(pieces[cell]["owner"]) != player and not tiles.protected.has(cell)


func targets_for(player: int, origin: Vector2i, slot: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if slot < 0 or slot > 2 or not pieces.has(origin):
		return result
	var card: MovementCard = pass_card if slot == 2 else hands[player][slot]
	for cell: Vector2i in destinations(card, origin, player):
		if can_enter(player, cell):
			result.append(cell)
	return result


func legal_moves(player: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for origin: Vector2i in cells_of(player):
		for slot: int in range(3):
			for cell: Vector2i in targets_for(player, origin, slot):
				moves.append({"from": origin, "slot": slot, "to": cell})
	return moves


## True when another living player could capture on `cell` with their hand.
func is_attacked(cell: Vector2i, player: int) -> bool:
	for other: int in range(PLAYERS):
		if other == player or not alive[other]:
			continue
		for origin: Vector2i in cells_of(other):
			for card: MovementCard in hands[other]:
				if cell in destinations(card, origin, other):
					return true
	return false


func apply_move(origin: Vector2i, slot: int, destination: Vector2i) -> void:
	last_events = {"eliminated": [], "revived": [], "core_lost": [], "tiles": "", "captured": pieces.get(destination, {})}
	var piece: Dictionary = pieces[origin]
	var captured: Dictionary = pieces.get(destination, {})
	pieces.erase(origin)
	tiles.protected.erase(destination)
	pieces[destination] = piece
	_move_protection(origin, destination)
	if not captured.is_empty():
		_piece_lost(captured, current)
	_exchange(slot)
	_end_turn()


## Uses the card in `slot` for its effect on `target` (targets: see FfaEffects).
func apply_effect(origin: Vector2i, slot: int, target: Vector2i) -> void:
	last_events = {"eliminated": [], "revived": [], "core_lost": [], "tiles": "", "captured": {}}
	match FfaEffects.kind_of_slot(self, slot):
		CardEffect.Kind.STRIKE:
			var victim: Dictionary = pieces[target]
			pieces.erase(target)
			tiles.protected.erase(target)
			_piece_lost(victim, current)
		CardEffect.Kind.PUSH:
			var landing := FfaEffects.push_landing(self, origin, target)
			pieces[landing] = pieces[target]
			pieces.erase(target)
			_move_protection(target, landing)
		CardEffect.Kind.SHIELD:
			tiles.protected[origin] = current
		CardEffect.Kind.SWAP:
			var mine: Dictionary = pieces[origin]
			pieces[origin] = pieces[target]
			pieces[target] = mine
			var shield_origin: Variant = tiles.protected.get(origin)
			var shield_target: Variant = tiles.protected.get(target)
			tiles.protected.erase(origin)
			tiles.protected.erase(target)
			if shield_origin != null:
				tiles.protected[target] = shield_origin
			if shield_target != null:
				tiles.protected[origin] = shield_target
	_exchange(slot)
	_end_turn()


func pass_turn(slot: int) -> void:
	last_events = {"eliminated": [], "revived": [], "core_lost": [], "tiles": "", "captured": {}}
	_exchange(slot)
	_end_turn()


## The seat that moves after `seat` (clockwise, skipping eliminated players).
func next_after(seat: int) -> int:
	return _next_alive(seat)


func _exchange(slot: int) -> void:
	pass_giver = current
	if slot == 2:
		return
	var used: MovementCard = hands[current][slot]
	hands[current][slot] = pass_card
	pass_card = used


## A shield stays with its piece when it moves.
func _move_protection(from: Vector2i, to: Vector2i) -> void:
	if tiles.protected.has(from):
		tiles.protected[to] = tiles.protected[from]
		tiles.protected.erase(from)


## A piece was taken or fell away (`taker` -1: a collapsing tile). Losing the core
## costs nothing more; taking one rewards the taker; no pieces left means out.
func _piece_lost(piece: Dictionary, taker: int) -> void:
	var owner := int(piece["owner"])
	if owner < 0:
		return
	if bool(piece["master"]):
		last_events["core_lost"].append(owner)
		if taker >= 0 and taker != owner:
			_reward(taker)
	if cells_of(owner).is_empty():
		_eliminate(owner)


func _has_core(player: int) -> bool:
	for cell: Vector2i in cells_of(player):
		if bool(pieces[cell]["master"]):
			return true
	return false


## Taking a core gives the taker their own core back, or else a lost echo, on a
## free cell of their home line.
func _reward(player: int) -> void:
	if not alive[player]:
		return
	var wants_core := not _has_core(player)
	if not wants_core and cells_of(player).size() >= PIECES_PER_PLAYER:
		return
	# The core returns to its own square if that one is free.
	var order: Array[int] = [2, 0, 1, 3, 4]
	for index: int in order:
		var cell := start_cell(player, index)
		if pieces.has(cell) or tiles.is_blocked(cell):
			continue
		pieces[cell] = {"owner": player, "master": wants_core}
		last_events["revived"].append({"player": player, "cell": cell, "master": wants_core})
		return


func _eliminate(player: int) -> void:
	alive[player] = false
	last_events["eliminated"].append(player)


func _alive_count() -> int:
	return alive.count(true)


func _end_turn() -> void:
	_check_winner()
	if winner != RUNNING:
		return
	var previous := current
	current = _next_alive(current)
	if current <= previous:
		round_number += 1
		_shift_tiles()
		_check_winner()
		if winner != RUNNING:
			return
		if not alive[current]:
			current = _next_alive(current)
	# A shield lasts until its owner's next turn begins.
	tiles.expire_protection(current)
	if round_number > ROUND_LIMIT:
		winner = DRAW


func _next_alive(from: int) -> int:
	var next := (from + 1) % PLAYERS
	while not alive[next]:
		next = (next + 1) % PLAYERS
	return next


func _shift_tiles() -> void:
	var shift := tiles.advance_round(round_number, Vector2i(SIZE, SIZE), _rng, pieces)
	var messages: PackedStringArray = []
	for cell: Vector2i in shift["collapsed"]:
		if pieces.has(cell):
			var piece: Dictionary = pieces[cell]
			pieces.erase(cell)
			tiles.protected.erase(cell)
			_piece_lost(piece, -1)
	if not shift["collapsed"].is_empty():
		messages.append("Felder sind weggebrochen.")
	if not shift["warned"].is_empty():
		messages.append("Orange Felder brechen als Nächstes weg!")
	last_events["tiles"] = " ".join(messages)


func _check_winner() -> void:
	var left := _alive_count()
	if left == 1:
		winner = alive.find(true)
	elif left == 0:
		winner = DRAW
