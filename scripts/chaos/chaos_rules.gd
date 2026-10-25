class_name ChaosRules
extends RefCounted

## Chaos mode state without any scene nodes: where each side's secret king
## stands and which tiles are warned or collapsed.

const FIRST_SHIFT_ROUND: int = 2
const WARNED_PER_ROUND: int = 2
const MAX_COLLAPSED: int = 6
const COLLAPSE_ROUNDS: int = 3

var shifting_tiles: bool = false
## Cell of each team's king, -1 / -1 until chosen.
var king_cells: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, -1)]
## coordinate -> rounds until it collapses.
var warned: Dictionary = {}
## coordinate -> rounds until it returns.
var collapsed: Dictionary = {}


func set_king(team: int, cell: Vector2i) -> void:
	king_cells[team] = cell


func is_king_at(team: int, cell: Vector2i) -> bool:
	return king_cells[team] == cell


## Keeps the king cell in step with its piece; the captured cell needs no update.
func piece_moved(team: int, from: Vector2i, to: Vector2i) -> void:
	if king_cells[team] == from:
		king_cells[team] = to


func is_blocked(cell: Vector2i) -> bool:
	return collapsed.has(cell)


## Called once per full round. Returns {"collapsed": [], "restored": [], "warned": []}.
## `board_size` is the grid; `rng` keeps tests deterministic.
func advance_round(round_number: int, board_size: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var result := {"collapsed": [] as Array[Vector2i], "restored": [] as Array[Vector2i], "warned": [] as Array[Vector2i]}
	if not shifting_tiles or round_number < FIRST_SHIFT_ROUND:
		return result
	for cell: Vector2i in warned.keys():
		warned[cell] = int(warned[cell]) - 1
		if int(warned[cell]) <= 0:
			warned.erase(cell)
			collapsed[cell] = COLLAPSE_ROUNDS
			result["collapsed"].append(cell)
	for cell: Vector2i in collapsed.keys():
		if cell in result["collapsed"]:
			continue
		collapsed[cell] = int(collapsed[cell]) - 1
		if int(collapsed[cell]) <= 0:
			collapsed.erase(cell)
			result["restored"].append(cell)
	var candidates: Array[Vector2i] = []
	for y: int in range(board_size.y):
		for x: int in range(board_size.x):
			var cell := Vector2i(x, y)
			if not collapsed.has(cell) and not warned.has(cell):
				candidates.append(cell)
	var room := mini(WARNED_PER_ROUND, MAX_COLLAPSED - collapsed.size() - warned.size())
	for _i: int in range(maxi(room, 0)):
		if candidates.is_empty():
			break
		var pick := candidates[rng.randi_range(0, candidates.size() - 1)]
		candidates.erase(pick)
		warned[pick] = 1
		result["warned"].append(pick)
	return result


## Part of the position key so a changing board never counts as a repetition.
func state_key() -> String:
	var parts: PackedStringArray = []
	for cell: Vector2i in warned.keys():
		parts.append("w%d,%d" % [cell.x, cell.y])
	for cell: Vector2i in collapsed.keys():
		parts.append("c%d,%d" % [cell.x, cell.y])
	parts.sort()
	return ",".join(parts)
