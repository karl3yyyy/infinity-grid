class_name FfaDeck
extends RefCounted

## The cards of Finite Grid. A card may move at most two squares in total (a
## step like (1, 2) is too much). The nearest enemy Master is six squares away
## (counting along the grid) from the nearest enemy piece, so two turns can
## never reach it, and a turn plus one effect step cannot either.

const MAX_REACH: int = 2


static func is_safe(card: MovementCard) -> bool:
	for offset: Vector2i in card.offsets:
		if absi(offset.x) + absi(offset.y) > MAX_REACH:
			return false
	return true


static func safe_cards() -> Array[MovementCard]:
	var cards: Array[MovementCard] = []
	for card: MovementCard in MovementCard.create_deck():
		if is_safe(card):
			cards.append(card)
	return cards


static func draw(count: int) -> Array[MovementCard]:
	var cards := safe_cards()
	cards.shuffle()
	return cards.slice(0, count)
