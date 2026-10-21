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
	]


## Draws a random set of distinct cards for one match.
static func draw_match_cards(count: int = 5) -> Array[MovementCard]:
	var deck := create_deck()
	deck.shuffle()
	var drawn: Array[MovementCard] = []
	for index: int in range(mini(count, deck.size())):
		drawn.append(deck[index])
	return drawn
