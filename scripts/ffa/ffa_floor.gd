class_name FfaFloor
extends GridManager

## The four-player board: the normal grid logic on a closed 9x9 field with a
## plain slab for a floor (no arena platforms yet) and no wraparound.

const SEAT_COLORS: Array[Color] = [Color("3a8fe7"), Color("6ee65a"), Color("e75a4a"), Color("ffc23a")]
const SLAB_COLOR := Color("24404c")
const GRID_GLOW := Color("6fc4ff")
const MOVE_GLOW := Color("d7ff3f")

var _seat_tints: Dictionary = {}


func _init() -> void:
	grid_size = Vector2i(FfaRules.SIZE, FfaRules.SIZE)


func setup() -> void:
	for child: Node in get_children():
		child.queue_free()
	cells.clear()
	_seat_tints.clear()
	for player: int in range(FfaRules.PLAYERS):
		for index: int in range(5):
			_seat_tints[FfaRules.start_cell(player, index)] = SEAT_COLORS[player]
	_create_slab()
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var coordinate := Vector2i(x, y)
			var cell := GridCellData.new(coordinate, grid_to_world(coordinate))
			cells[coordinate] = cell
			_create_cell_visual(cell)


func world_to_grid(world_position: Vector3) -> Vector2i:
	var half := float(grid_size.x - 1) * 0.5
	var coordinate := Vector2i(roundi(world_position.x / CELL_SIZE + half), roundi(world_position.z / CELL_SIZE + half))
	return coordinate if is_inside(coordinate) else Vector2i(-1, -1)


func _create_slab() -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	var width := float(grid_size.x) * CELL_SIZE + 0.4
	box.size = Vector3(width, 0.2, width)
	slab.mesh = box
	slab.position = Vector3(0.0, -0.1, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = SLAB_COLOR
	material.metallic = 0.6
	material.roughness = 0.35
	slab.material_override = material
	add_child(slab)


## Plain tiles stay faintly visible (checkerboard, start sides in their colour);
## highlights, warnings and holes use the normal cell colours.
func _update_cell_visual(cell: GridCell) -> void:
	if cell.material == null:
		return
	if cell.highlight == GridCellData.Highlight.MOVE:
		ArenaTileStyle.paint(cell.material, true, MOVE_GLOW, 1.0)
		return
	var plain := cell.highlight in [GridCellData.Highlight.NORMAL, GridCellData.Highlight.OCCUPIED, GridCellData.Highlight.HOVER]
	if not plain:
		super._update_cell_visual(cell)
		return
	var tint: Color = _seat_tints.get(cell.coordinate, GRID_GLOW)
	var opacity := 1.0 if _seat_tints.has(cell.coordinate) else (0.85 if (cell.coordinate.x + cell.coordinate.y) % 2 == 0 else 0.5)
	if cell.highlight == GridCellData.Highlight.HOVER:
		tint = _colors[GridCellData.Highlight.HOVER]
		opacity = 0.6
	ArenaTileStyle.paint(cell.material, true, tint, opacity)
