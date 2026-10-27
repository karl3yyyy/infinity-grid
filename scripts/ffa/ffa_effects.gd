class_name FfaEffects
extends RefCounted

## Chaos card effects on the four-player board (see CardEffect for the kinds):
## a turn uses a card's step or its effect. Pure geometry, no nodes.

const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NO_CELL := Vector2i(-1, -1)


static func kind_of_slot(rules: FfaRules, slot: int) -> int:
	var card: MovementCard = rules.pass_card if slot == 2 else rules.hands[rules.current][slot]
	return CardEffect.kind_of(card)


## Where a pushed piece lands, or NO_CELL when the push is not possible.
static func push_landing(rules: FfaRules, origin: Vector2i, target: Vector2i) -> Vector2i:
	var landing := target + (target - origin)
	if landing.x < 0 or landing.y < 0 or landing.x >= FfaRules.SIZE or landing.y >= FfaRules.SIZE:
		return NO_CELL
	if rules.pieces.has(landing) or rules.tiles.is_blocked(landing):
		return NO_CELL
	return landing


## Cells the piece on `origin` may aim the effect of the card in `slot` at.
static func targets(rules: FfaRules, origin: Vector2i, slot: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var player := rules.current
	var kind := kind_of_slot(rules, slot)
	match kind:
		CardEffect.Kind.SHIELD:
			if not rules.tiles.protected.has(origin):
				result.append(origin)
		CardEffect.Kind.SWAP:
			for cell: Vector2i in rules.cells_of(player):
				if cell != origin:
					result.append(cell)
		_:
			for direction: Vector2i in DIRECTIONS:
				var cell := origin + direction
				if not rules.pieces.has(cell) or int(rules.pieces[cell]["owner"]) == player or rules.tiles.protected.has(cell):
					continue
				if kind == CardEffect.Kind.PUSH and push_landing(rules, origin, cell) == NO_CELL:
					continue
				result.append(cell)
	return result


## True when the player has any piece and card whose effect has a target.
static func has_any(rules: FfaRules, player: int) -> bool:
	var previous := rules.current
	rules.current = player
	var found := false
	for origin: Vector2i in rules.cells_of(player):
		for slot: int in range(3):
			if not targets(rules, origin, slot).is_empty():
				found = true
				break
		if found:
			break
	rules.current = previous
	return found
