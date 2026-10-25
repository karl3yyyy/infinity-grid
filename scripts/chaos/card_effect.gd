class_name CardEffect
extends RefCounted

## Chaos "Kartenfähigkeiten": every movement card also carries the effect of its
## category. A turn uses either the card's step or its effect, never both; the
## card is exchanged either way. Node-free so the bot and tests can use it.

enum Kind { STRIKE, PUSH, SHIELD, SWAP }

const BY_CATEGORY: Dictionary = {
	"VECTOR": Kind.STRIKE,
	"WAVE": Kind.PUSH,
	"FIELD": Kind.SHIELD,
	"OVERCLOCK": Kind.SWAP,
}

const TITLES: Dictionary = {
	Kind.STRIKE: "NAHSCHLAG",
	Kind.PUSH: "STOSS",
	Kind.SHIELD: "SCHILD",
	Kind.SWAP: "TAUSCH",
}

const HINTS: Dictionary = {
	Kind.STRIKE: "Tippe auf eine angrenzende gegnerische Figur: sie wird zerstört, deine bleibt stehen.",
	Kind.PUSH: "Tippe auf eine angrenzende gegnerische Figur: sie wird ein Feld weggeschoben.",
	Kind.SHIELD: "Tippe auf deine gewählte Figur: Sie kann bis zu deinem nächsten Zug nicht geschlagen werden.",
	Kind.SWAP: "Tippe auf eine eigene Figur: Beide tauschen die Plätze.",
}

const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func kind_of(card: MovementCard) -> int:
	return int(BY_CATEGORY[card.category()])


static func button_text(kind: int) -> String:
	return "EFFEKT: " + str(TITLES[kind])


## Cell next to `origin` in `direction`: wraps horizontally, closed at top and bottom.
static func neighbour(origin: Vector2i, direction: Vector2i, board: Vector2i) -> Vector2i:
	var cell := Vector2i(posmod(origin.x + direction.x, board.x), origin.y + direction.y)
	return cell if cell.y >= 0 and cell.y < board.y else Vector2i(-1, -1)


## Where a pushed piece lands, or (-1, -1) when the push is not possible.
static func push_landing(origin: Vector2i, target: Vector2i, board: Vector2i, occupied: Array[Vector2i], blocked: Dictionary) -> Vector2i:
	for direction: Vector2i in DIRECTIONS:
		if neighbour(origin, direction, board) != target:
			continue
		var landing := neighbour(target, direction, board)
		if landing.x < 0 or landing in occupied or blocked.has(landing):
			return Vector2i(-1, -1)
		return landing
	return Vector2i(-1, -1)


## Cells the piece on `origin` may aim the effect at.
## `protected` maps cell -> team whose piece cannot be hit or pushed.
static func targets(
	kind: int, origin: Vector2i, team: int, board: Vector2i,
	own: Array[Vector2i], enemy: Array[Vector2i], blocked: Dictionary, protected: Dictionary
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match kind:
		Kind.SHIELD:
			if not protected.has(origin):
				result.append(origin)
		Kind.SWAP:
			for cell: Vector2i in own:
				if cell != origin:
					result.append(cell)
		_:
			var occupied: Array[Vector2i] = []
			occupied.append_array(own)
			occupied.append_array(enemy)
			for direction: Vector2i in DIRECTIONS:
				var cell := neighbour(origin, direction, board)
				if cell not in enemy or protected.has(cell):
					continue
				if kind == Kind.PUSH and push_landing(origin, cell, board, occupied, blocked).x < 0:
					continue
				result.append(cell)
	return result
