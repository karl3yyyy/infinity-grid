class_name MovementCard
extends RefCounted

var card_name: String
var offsets: Array[Vector2i]


func _init(new_name: String, new_offsets: Array[Vector2i]) -> void:
	card_name = new_name
	offsets = new_offsets


func destinations(origin: Vector2i, team_id: int, grid_width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in offsets:
		var horizontal_offset := -offset.x if team_id == 1 else offset.x
		var forward_offset := offset.y if team_id == 1 else -offset.y
		var destination := Vector2i(
			posmod(origin.x + horizontal_offset, grid_width),
			origin.y + forward_offset
		)
		if destination.y >= 0 and destination.y < 5 and destination not in result:
			result.append(destination)
	return result


func move_summary(_team_id: int = 0) -> String:
	var labels: PackedStringArray = []
	for offset: Vector2i in offsets:
		labels.append("(%d,%d)" % [offset.x, offset.y])
	return " ".join(labels)


func description() -> String:
	var moves: PackedStringArray = []
	for offset: Vector2i in offsets:
		var parts: PackedStringArray = []
		if offset.x != 0:
			parts.append("%d Feld%s nach %s" % [
				absi(offset.x), "" if absi(offset.x) == 1 else "er",
				"rechts" if offset.x > 0 else "links",
			])
		if offset.y != 0:
			parts.append("%d Feld%s nach %s" % [
				absi(offset.y), "" if absi(offset.y) == 1 else "er",
				"vorne" if offset.y > 0 else "hinten",
			])
		moves.append(" und ".join(parts))
	return "Von deiner Figur aus: %s. Links und rechts geht das Brett nahtlos weiter." % ", ".join(moves)


func has_long_forward_move() -> bool:
	for offset: Vector2i in offsets:
		if offset.y == 2 and absi(offset.x) <= 1:
			return true
	return false


## Grid cell (column, row) on a 5x5 card diagram, seen from the side whose
## forward direction points up on screen. Mirrored cards are rotated by 180°.
func diagram_cell(offset: Vector2i, rotated: bool) -> Vector2i:
	if rotated:
		return Vector2i(2 - offset.x, 2 + offset.y)
	return Vector2i(2 + offset.x, 2 - offset.y)


## Full card pool. A match draws five of these at random.
## Offsets use x = right and y = forward from the owning player's view.
static func create_deck() -> Array[MovementCard]:
	return [
		MovementCard.new("Crane", [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 1)]),
		MovementCard.new("Wave", [Vector2i(-2, 0), Vector2i(1, -1), Vector2i(1, 1)]),
		MovementCard.new("Comet", [Vector2i(0, -2), Vector2i(1, 0), Vector2i(0, 1)]),
		MovementCard.new("Shell", [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]),
		MovementCard.new("Vortex", [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 2)]),
		MovementCard.new("Nova", [Vector2i(0, 2), Vector2i(0, -1)]),
		MovementCard.new("Tide", [Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0)]),
		MovementCard.new("Orbit", [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]),
		MovementCard.new("Rift", [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(-1, -1), Vector2i(1, -1)]),
		MovementCard.new("Halo", [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(1, 0)]),
		MovementCard.new("Ember", [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, -1)]),
		MovementCard.new("Drift", [Vector2i(-2, 0), Vector2i(-1, 1), Vector2i(1, -1)]),
		MovementCard.new("Zephyr", [Vector2i(2, 0), Vector2i(1, 1), Vector2i(-1, -1)]),
		MovementCard.new("Eclipse", [Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(1, -1)]),
		MovementCard.new("Prism", [Vector2i(1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, -1)]),
		MovementCard.new("Pulse", [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]),
		MovementCard.new("Echo", [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]),
		MovementCard.new("Serpent", [Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, 0)]),
		MovementCard.new("Viper", [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 0)]),
		MovementCard.new("Lance", [Vector2i(0, 2), Vector2i(-1, 0), Vector2i(1, 0)]),
		MovementCard.new("Spark", [Vector2i(-1, 1), Vector2i(1, 1)]),
		MovementCard.new("Anchor", [Vector2i(0, 1), Vector2i(0, -2)]),
		MovementCard.new("Glide", [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]),
		MovementCard.new("Knight", [Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, -1)]),
		MovementCard.new("Mirage", [Vector2i(-2, 1), Vector2i(2, -1), Vector2i(0, 1)]),
		MovementCard.new("Bastion", [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]),
		MovementCard.new("Gale", [Vector2i(2, 1), Vector2i(-2, -1), Vector2i(0, 1)]),
		MovementCard.new("Spire", [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, -1)]),
		MovementCard.new("Phantom", [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 1), Vector2i(1, 1)]),
		MovementCard.new("Flare", [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]),
		MovementCard.new("Chaos", [Vector2i(-2, 2), Vector2i(2, 2), Vector2i(-2, -2), Vector2i(2, -2)]),
		MovementCard.new("Pinwheel", [Vector2i(-1, 2), Vector2i(2, 1), Vector2i(1, -2), Vector2i(-2, -1)]),
		MovementCard.new("Quasar", [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(0, -2)]),
		MovementCard.new("Jester", [Vector2i(-2, 2), Vector2i(2, 2), Vector2i(0, -2)]),
		MovementCard.new("Hydra", [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, -1)]),
		MovementCard.new("Nebula", [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]),
	]


## Rebuilds cards dealt elsewhere (by the Wi-Fi host) from their names.
static func cards_from_names(names: Array) -> Array[MovementCard]:
	var by_name: Dictionary = {}
	for card: MovementCard in create_deck():
		by_name[card.card_name] = card
	var result: Array[MovementCard] = []
	for card_name: Variant in names:
		if by_name.has(str(card_name)):
			result.append(by_name[str(card_name)])
	return result


## Draws a random set of distinct cards for one match.
static func draw_match_cards(count: int = 5) -> Array[MovementCard]:
	var deck := create_deck()
	deck.shuffle()
	var drawn: Array[MovementCard] = []
	var has_long_forward_card := false
	for card: MovementCard in deck:
		if count <= 0 or drawn.size() >= count:
			break
		if card.has_long_forward_move():
			if has_long_forward_card:
				continue
			has_long_forward_card = true
		drawn.append(card)
	return drawn


## Technology class of every card; display only, the moves are unchanged.
const CATEGORIES: Dictionary = {
	"Crane": "VECTOR", "Comet": "VECTOR", "Shell": "VECTOR", "Ember": "VECTOR", "Pulse": "VECTOR",
	"Wave": "WAVE", "Tide": "WAVE", "Drift": "WAVE", "Zephyr": "WAVE", "Serpent": "WAVE", "Viper": "WAVE",
	"Orbit": "FIELD", "Halo": "FIELD", "Eclipse": "FIELD", "Prism": "FIELD", "Echo": "FIELD",
	"Vortex": "OVERCLOCK", "Nova": "OVERCLOCK", "Rift": "OVERCLOCK",
	"Lance": "OVERCLOCK", "Knight": "OVERCLOCK", "Phantom": "OVERCLOCK",
	"Spark": "VECTOR", "Anchor": "VECTOR", "Spire": "VECTOR",
	"Glide": "WAVE", "Mirage": "WAVE", "Gale": "WAVE",
	"Bastion": "FIELD", "Flare": "FIELD", "Nebula": "FIELD",
	"Chaos": "OVERCLOCK", "Pinwheel": "OVERCLOCK", "Quasar": "OVERCLOCK", "Jester": "WAVE", "Hydra": "OVERCLOCK",
}
const CATEGORY_COLORS: Dictionary = {
	"VECTOR": Color("7fe3ff"),
	"WAVE": Color("b6ff6e"),
	"FIELD": Color("e0a0ff"),
	"OVERCLOCK": Color("ff7a5c"),
}


func category() -> String:
	return str(CATEGORIES.get(card_name, "VECTOR"))


func category_color() -> Color:
	return CATEGORY_COLORS[category()]
