class_name FfaBot
extends RefCounted

## One-ply bot for the four-player free-for-all: grabs Masters first, keeps its
## own Master out of reach and drifts toward the nearest living rival.

const MASTER_VALUE: float = 150.0
const STUDENT_VALUE: float = 40.0
const RUIN_VALUE: float = 6.0
const MASTER_DANGER: float = 90.0
const STUDENT_DANGER: float = 22.0
const WARNED_PENALTY: float = 60.0

var rng := RandomNumberGenerator.new()


## Returns {"from", "slot", "to"} or {"pass": true, "slot"} when nothing can move.
func choose_move(rules: FfaRules, player: int) -> Dictionary:
	var moves := rules.legal_moves(player)
	if moves.is_empty():
		return {"pass": true, "slot": rng.randi_range(0, 2)}
	var best: Dictionary = moves[0]
	var best_score := -INF
	for move: Dictionary in moves:
		var score := _score(rules, player, move)
		if score > best_score:
			best_score = score
			best = move
	return best


func _score(rules: FfaRules, player: int, move: Dictionary) -> float:
	var origin: Vector2i = move["from"]
	var target: Vector2i = move["to"]
	var is_master: bool = bool(rules.pieces[origin]["master"])
	var score := rng.randf() * 5.0
	if rules.pieces.has(target):
		var victim: Dictionary = rules.pieces[target]
		if int(victim["owner"]) == FfaRules.NEUTRAL:
			score += RUIN_VALUE
		else:
			score += MASTER_VALUE if bool(victim["master"]) else STUDENT_VALUE
	if rules.is_attacked(target, player):
		score -= MASTER_DANGER if is_master else STUDENT_DANGER
	if rules.tiles.warned.has(target):
		score -= WARNED_PENALTY
	if rules.tiles.warned.has(origin):
		score += WARNED_PENALTY * (1.5 if is_master else 0.8)
	var before := _distance_to_rival(rules, player, origin)
	var after := _distance_to_rival(rules, player, target)
	# Students hunt; the Master only keeps its distance.
	score += float(before - after) * (-1.0 if is_master else 2.0)
	return score


func _distance_to_rival(rules: FfaRules, player: int, cell: Vector2i) -> int:
	var nearest := 99
	for other: Vector2i in rules.pieces.keys():
		var piece: Dictionary = rules.pieces[other]
		if int(piece["owner"]) == player or int(piece["owner"]) == FfaRules.NEUTRAL:
			continue
		nearest = mini(nearest, absi(other.x - cell.x) + absi(other.y - cell.y))
	return nearest
