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
		var forward_offset := offset.y if team_id == 1 else -offset.y
		var destination := Vector2i(
			posmod(origin.x + offset.x, grid_width),
			origin.y + forward_offset
		)
		if destination.y >= 0 and destination.y < 5 and destination not in result:
			result.append(destination)
	return result


func move_summary(team_id: int = 0) -> String:
	var labels: PackedStringArray = []
	for offset: Vector2i in offsets:
		var direction := Vector2i(offset.x, -offset.y if team_id == 0 else offset.y)
		var symbol := ""
		if direction.x == 0:
			symbol = "↑" if direction.y < 0 else "↓"
		elif direction.y == 0:
			symbol = "←" if direction.x < 0 else "→"
		elif direction.x < 0:
			symbol = "↖" if direction.y < 0 else "↙"
		else:
			symbol = "↗" if direction.y < 0 else "↘"
		var distance := maxi(absi(direction.x), absi(direction.y))
		labels.append("%s%d" % [symbol, distance] if distance > 1 else symbol)
	return "  ".join(labels)


static func create_deck() -> Array[MovementCard]:
	return [
		MovementCard.new("Crane", [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 1)]),
		MovementCard.new("Wave", [Vector2i(-2, 0), Vector2i(1, -1), Vector2i(1, 1)]),
		MovementCard.new("Comet", [Vector2i(0, -2), Vector2i(1, 0), Vector2i(0, 1)]),
		MovementCard.new("Shell", [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]),
		MovementCard.new("Vortex", [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 2)]),
	]