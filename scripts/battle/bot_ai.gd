class_name BotAI
extends RefCounted

## Pure-rules opponent search. Works on a compact copy of the match so it never
## touches scene nodes. Board cells: 0 empty, 1 student, 2 master; the team is
## stored separately (0 / 1).

enum Difficulty { EASY, MEDIUM, HARD }

const DIFFICULTY_LABELS: Array[String] = ["LEICHT", "MITTEL", "SCHWER"]
const WIN_SCORE: int = 100000
const STUDENT_VALUE: int = 100
const WIDTH: int = 5
const HEIGHT: int = 5
## Cell where each team's master starts; any enemy piece reaching it wins.
const TEMPLE_CELLS: Array[int] = [22, 2]

var difficulty: int = Difficulty.MEDIUM
var max_think_msec: int = 1400
var _deadline_msec: int = 0
var _timed_out: bool = false
var _cards: Array[MovementCard] = []
## Pre-computed destinations: _moves[card][team][cell] -> PackedInt32Array of cells.
var _moves: Array = []


func _init(new_difficulty: int = Difficulty.MEDIUM) -> void:
	difficulty = new_difficulty


static func label_for(level: int) -> String:
	return DIFFICULTY_LABELS[clampi(level, 0, DIFFICULTY_LABELS.size() - 1)]


## state: {
##   "pieces": PackedInt32Array(25), "teams": PackedInt32Array(25),
##   "hands": [[card_index, card_index], [card_index, card_index]],
##   "pass": card_index, "cards": Array[MovementCard] }
## Returns {"from": Vector2i, "slot": int, "to": Vector2i}, or {"slot": int, "pass": true}
## when no figure can move and a card must be given away instead.
func choose_move(state: Dictionary, team: int) -> Dictionary:
	_prepare_cards(state["cards"])
	var pieces: PackedInt32Array = (state["pieces"] as PackedInt32Array).duplicate()
	var teams: PackedInt32Array = (state["teams"] as PackedInt32Array).duplicate()
	var hands: Array = [(state["hands"][0] as Array).duplicate(), (state["hands"][1] as Array).duplicate()]
	var pass_card: int = int(state["pass"])
	var root_moves := _generate_moves(pieces, teams, hands, team)
	if root_moves.is_empty():
		var pass_move := _search_root(pieces, teams, hands, pass_card, team, _pass_moves(), 2, 1000000)
		return {"slot": pass_move[1], "pass": true}
	root_moves.shuffle()
	var best: Array = root_moves[0]
	match difficulty:
		Difficulty.EASY:
			best = _choose_easy(pieces, teams, hands, pass_card, team, root_moves)
		Difficulty.MEDIUM:
			best = _search_root(pieces, teams, hands, pass_card, team, root_moves, 2, 1000000)
		_:
			best = _search_iterative(pieces, teams, hands, pass_card, team, root_moves, 5)
	return {"from": _to_coord(best[0]), "slot": best[1], "to": _to_coord(best[2])}


## Easy: grabs an undefended master and otherwise plays loosely, often missing threats.
func _choose_easy(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, pass_card: int, team: int, moves: Array) -> Array:
	for move: Array in moves:
		if pieces[move[2]] == 2 and teams[move[2]] != team:
			return move
		if move[0] >= 0 and move[2] == TEMPLE_CELLS[1 - team]:
			return move
	if randf() < 0.45:
		return moves.pick_random()
	return _search_root(pieces, teams, hands, pass_card, team, moves, 1, 1000000)


func _search_iterative(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, pass_card: int, team: int, moves: Array, max_depth: int) -> Array:
	_deadline_msec = Time.get_ticks_msec() + max_think_msec
	var best: Array = _search_root(pieces, teams, hands, pass_card, team, moves, 2, 1000000)
	for depth: int in range(3, max_depth + 1):
		_timed_out = false
		var candidate := _search_root(pieces, teams, hands, pass_card, team, moves, depth, _deadline_msec)
		if _timed_out:
			break
		best = candidate
		# Try the best move first next iteration for better pruning.
		moves.erase(best)
		moves.push_front(best)
	return best


func _search_root(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, pass_card: int, team: int, moves: Array, depth: int, deadline: int) -> Array:
	_deadline_msec = deadline
	_timed_out = false
	var best_score := -WIN_SCORE * 10
	var best_moves: Array = []
	var alpha := -WIN_SCORE * 10
	var beta := WIN_SCORE * 10
	for move: Array in moves:
		var undo := _apply(pieces, teams, hands, team, move, pass_card)
		var score := -_negamax(pieces, teams, hands, int(undo["pass"]), 1 - team, depth - 1, -beta, -alpha, 1)
		_undo(pieces, teams, hands, team, move, undo)
		if _timed_out:
			break
		# Small noise keeps equal positions from always playing the same line.
		var noisy := score * 10 + randi_range(0, 4)
		if noisy > best_score:
			best_score = noisy
			best_moves = [move]
		elif noisy == best_score:
			best_moves.append(move)
		alpha = maxi(alpha, score)
	return best_moves.pick_random() if not best_moves.is_empty() else moves[0]


func _negamax(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, pass_card: int, team: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	if not _master_alive(pieces, teams, team) or _temple_taken(pieces, teams, team):
		return -WIN_SCORE + ply
	if depth <= 0:
		return _evaluate(pieces, teams, hands, team)
	if Time.get_ticks_msec() > _deadline_msec:
		_timed_out = true
		return 0
	var moves := _generate_moves(pieces, teams, hands, team)
	if moves.is_empty():
		moves = _pass_moves()
	_order_moves(pieces, moves)
	var best := -WIN_SCORE * 10
	for move: Array in moves:
		var undo := _apply(pieces, teams, hands, team, move, pass_card)
		var score := -_negamax(pieces, teams, hands, int(undo["pass"]), 1 - team, depth - 1, -beta, -alpha, ply + 1)
		_undo(pieces, teams, hands, team, move, undo)
		if _timed_out:
			return 0
		best = maxi(best, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break
	return best


func _evaluate(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int) -> int:
	var score := 0
	var masters := [-1, -1]
	for cell: int in range(WIDTH * HEIGHT):
		if pieces[cell] == 0:
			continue
		var factor := 1 if teams[cell] == team else -1
		if pieces[cell] == 2:
			masters[teams[cell]] = cell
		else:
			score += factor * STUDENT_VALUE
			# Students are worth a little more once they advance.
			var row := cell / WIDTH
			var progress := (HEIGHT - 1 - row) if teams[cell] == 0 else row
			score += factor * progress * 3
	# Threats: can the side to move capture the enemy master right now?
	var enemy := 1 - team
	if masters[enemy] >= 0 and _attacks(pieces, teams, hands, team, masters[enemy]):
		score += 400
	if masters[team] >= 0 and _attacks(pieces, teams, hands, enemy, masters[team]):
		score -= 250
	score += (_mobility(pieces, teams, hands, team) - _mobility(pieces, teams, hands, enemy)) * 2
	return score


func _attacks(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int, target: int) -> bool:
	for cell: int in range(WIDTH * HEIGHT):
		if pieces[cell] == 0 or teams[cell] != team:
			continue
		for card_index: int in hands[team]:
			if target in (_moves[card_index][team][cell] as PackedInt32Array):
				return true
	return false


func _mobility(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int) -> int:
	var count := 0
	for cell: int in range(WIDTH * HEIGHT):
		if pieces[cell] == 0 or teams[cell] != team:
			continue
		for card_index: int in hands[team]:
			for destination: int in (_moves[card_index][team][cell] as PackedInt32Array):
				if pieces[destination] == 0 or teams[destination] != team:
					count += 1
	return count


func _generate_moves(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int) -> Array:
	var result: Array = []
	for cell: int in range(WIDTH * HEIGHT):
		if pieces[cell] == 0 or teams[cell] != team:
			continue
		for slot: int in range(2):
			var card_index: int = hands[team][slot]
			for destination: int in (_moves[card_index][team][cell] as PackedInt32Array):
				if pieces[destination] != 0 and teams[destination] == team:
					continue
				result.append([cell, slot, destination])
	return result


## Without a legal move a side keeps its figures in place and only gives a card
## away. A pass is encoded as [-1, slot, -1].
func _pass_moves() -> Array:
	return [[-1, 0, -1], [-1, 1, -1]]


func _order_moves(pieces: PackedInt32Array, moves: Array) -> void:
	moves.sort_custom(func(a: Array, b: Array) -> bool: return a[2] >= 0 and b[2] >= 0 and pieces[a[2]] > pieces[b[2]])


func _apply(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int, move: Array, pass_card: int) -> Dictionary:
	var from: int = move[0]
	var to: int = move[2]
	var slot: int = move[1]
	var undo := {
		"captured_piece": pieces[to] if to >= 0 else 0,
		"captured_team": teams[to] if to >= 0 else 0,
		"used_card": hands[team][slot],
		"old_pass": pass_card,
	}
	hands[team][slot] = pass_card
	undo["pass"] = undo["used_card"]
	if from < 0:
		return undo
	pieces[to] = pieces[from]
	teams[to] = teams[from]
	pieces[from] = 0
	teams[from] = 0
	return undo


func _undo(pieces: PackedInt32Array, teams: PackedInt32Array, hands: Array, team: int, move: Array, undo: Dictionary) -> void:
	var from: int = move[0]
	var to: int = move[2]
	hands[team][move[1]] = int(undo["used_card"])
	if from < 0:
		return
	pieces[from] = pieces[to]
	teams[from] = teams[to]
	pieces[to] = int(undo["captured_piece"])
	teams[to] = int(undo["captured_team"])


## An enemy piece stands on this team's KERN starting square: the game is lost.
func _temple_taken(pieces: PackedInt32Array, teams: PackedInt32Array, team: int) -> bool:
	var temple: int = TEMPLE_CELLS[team]
	return pieces[temple] != 0 and teams[temple] != team


func _master_alive(pieces: PackedInt32Array, teams: PackedInt32Array, team: int) -> bool:
	for cell: int in range(WIDTH * HEIGHT):
		if pieces[cell] == 2 and teams[cell] == team:
			return true
	return false


func _prepare_cards(cards: Array) -> void:
	_cards.clear()
	_moves.clear()
	for card_value: Variant in cards:
		var card: MovementCard = card_value
		_cards.append(card)
		var per_team: Array = []
		for team: int in range(2):
			var per_cell: Array = []
			for cell: int in range(WIDTH * HEIGHT):
				var destinations := PackedInt32Array()
				for coordinate: Vector2i in card.destinations(_to_coord(cell), team, WIDTH):
					destinations.append(coordinate.y * WIDTH + coordinate.x)
				per_cell.append(destinations)
			per_team.append(per_cell)
		_moves.append(per_team)


static func _to_coord(cell: int) -> Vector2i:
	return Vector2i(cell % WIDTH, cell / WIDTH)
