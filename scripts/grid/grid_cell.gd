class_name GridCell
extends RefCounted

enum Highlight {
	NORMAL,
	HOVER,
	SELECTED,
	MOVE,
	ATTACK,
	OCCUPIED,
}

var coordinate: Vector2i
var world_position: Vector3
var occupant: Node = null
var highlight: Highlight = Highlight.NORMAL
var visual: MeshInstance3D = null
var material: StandardMaterial3D = null


func _init(cell_coordinate: Vector2i, cell_world_position: Vector3) -> void:
	coordinate = cell_coordinate
	world_position = cell_world_position

