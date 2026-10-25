class_name GridCell
extends RefCounted

enum Highlight {
	NORMAL,
	HOVER,
	SELECTED,
	MOVE,
	ATTACK,
	OCCUPIED,
	WARNING,
	COLLAPSED,
}

var coordinate: Vector2i
var world_position: Vector3
var occupant: Node = null
var highlight: Highlight = Highlight.NORMAL
## Chaos mode: 0 normal, 1 about to collapse, 2 collapsed.
var tile_state: int = 0
var visual: MeshInstance3D = null
var material: StandardMaterial3D = null


func _init(cell_coordinate: Vector2i, cell_world_position: Vector3) -> void:
	coordinate = cell_coordinate
	world_position = cell_world_position

