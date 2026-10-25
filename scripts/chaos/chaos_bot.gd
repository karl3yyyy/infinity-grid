class_name ChaosBot
extends RefCounted

## One-ply opponent for Hidden King. It does not know which enemy piece is the
## king, so every capture is worth the same; it only protects its own king and
## avoids tiles that are about to collapse.

const CAPTURE_SCORE: float = 100.0
const KING_DANGER: float = 70.0
const PIECE_DANGER: float = 12.0
const WARNED_PENALTY: float = 60.0
const ADVANCE_SCORE: float = 4.0

var rng := RandomNumberGenerator.new()


## own / enemy: Array[Vector2i] of living pieces. hands: the bot's two cards,
## enemy_hand: the other side's two. Returns {"from", "slot", "to"} or {"pass": true, "slot"}.
func choose_move(
	team: int,
	own: Array[Vector2i],
	enemy: Array[Vector2i],
	king_cell: Vector2i,
	hand: Array,
	enemy_hand: Array,
	blocked: Dictionary,
	warned: Dictionary,
	width: int,
	effects: Array = [],
	protected: Dictionary = {}
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for slot: int in range(effects.size()):
		for origin: Vector2i in own:
			var kind := int(effects[slot])
			if kind != CardEffect.Kind.STRIKE and not (kind == CardEffect.Kind.SHIELD and origin == king_cell):
				continue
			var aimed := CardEffect.targets(kind, origin, team, Vector2i(width, width), own, enemy, blocked, protected)
			if aimed.is_empty():
				continue
			var worth := CAPTURE_SCORE * 0.9
			if kind == CardEffect.Kind.SHIELD:
				worth = KING_DANGER if _is_attacked(origin, 1 - team, enemy, enemy_hand, width) else -INF
			worth += rng.randf() * 6.0
			if worth > best_score:
				best_score = worth
				best = {"effect": true, "from": origin, "slot": slot, "to": aimed[0]}
	for slot: int in range(hand.size()):
		var card: MovementCard = hand[slot]
		for origin: Vector2i in own:
			for target: Vector2i in card.destinations(origin, team, width):
				if blocked.has(target) or target in own or (target in enemy and protected.has(target)):
					continue
				var score := _score(team, origin, target, own, enemy, king_cell, enemy_hand, warned, width)
				if score > best_score:
					best_score = score
					best = {"from": origin, "slot": slot, "to": target}
	if best.is_empty():
		return {"pass": true, "slot": rng.randi_range(0, hand.size() - 1)}
	return best


func _score(
	team: int, origin: Vector2i, target: Vector2i, own: Array[Vector2i], enemy: Array[Vector2i],
	king_cell: Vector2i, enemy_hand: Array, warned: Dictionary, width: int
) -> float:
	var score := rng.randf() * 6.0
	if target in enemy:
		score += CAPTURE_SCORE
	if warned.has(target):
		score -= WARNED_PENALTY
	if warned.has(origin):
		score += WARNED_PENALTY * (1.5 if origin == king_cell else 0.8)
	var remaining_enemy: Array[Vector2i] = []
	for cell: Vector2i in enemy:
		if cell != target:
			remaining_enemy.append(cell)
	if _is_attacked(target, 1 - team, remaining_enemy, enemy_hand, width):
		score -= KING_DANGER if origin == king_cell else PIECE_DANGER
	# Rows count from the player's side, so "forward" is toward row 0 for team 0.
	var forward := (origin.y - target.y) if team == 0 else (target.y - origin.y)
	if origin != king_cell:
		score += ADVANCE_SCORE * forward
	return score


func _is_attacked(cell: Vector2i, attacker_team: int, attackers: Array[Vector2i], hand: Array, width: int) -> bool:
	for attacker: Vector2i in attackers:
		for card: MovementCard in hand:
			if cell in card.destinations(attacker, attacker_team, width):
				return true
	return false
