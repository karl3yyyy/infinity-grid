class_name GridManager
extends Node3D

signal hovered_cell_changed(coordinate: Vector2i)

const GridCellData := preload("res://scripts/grid/grid_cell.gd")
const CELL_SIZE: float = 1.4

var grid_size: Vector2i = Vector2i(5, 5)
var cells: Dictionary = {}
var hovered_coordinate: Vector2i = Vector2i(-1, -1)
var wrap_projection_count: int = 0
var _wrap_materials: Dictionary = {}

var _colors: Dictionary = {
	GridCellData.Highlight.NORMAL: Color("35545b"),
	GridCellData.Highlight.HOVER: Color("6a7fb0"),
	GridCellData.Highlight.SELECTED: Color("ffcf5a"),
	GridCellData.Highlight.MOVE: Color("3fb8ff"),
	GridCellData.Highlight.ATTACK: Color("ff4a3d"),
	GridCellData.Highlight.OCCUPIED: Color("4a4562"),
}


func setup() -> void:
	for child: Node in get_children():
		child.queue_free()
	cells.clear()
	_wrap_materials.clear()
	wrap_projection_count = 0
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var coordinate := Vector2i(x, y)
			var cell := GridCellData.new(coordinate, grid_to_world(coordinate))
			cells[coordinate] = cell
			_create_cell_visual(cell)
	_create_wrap_projections()
	_create_wrap_seams()


func grid_to_world(coordinate: Vector2i) -> Vector3:
	var half_width := float(grid_size.x - 1) * 0.5
	var half_height := float(grid_size.y - 1) * 0.5
	return Vector3(
		(float(coordinate.x) - half_width) * CELL_SIZE,
		0.0,
		(float(coordinate.y) - half_height) * CELL_SIZE
	)


func world_to_grid(world_position: Vector3) -> Vector2i:
	var half_width := float(grid_size.x - 1) * 0.5
	var half_height := float(grid_size.y - 1) * 0.5
	var raw_column := roundi(world_position.x / CELL_SIZE + half_width)
	var row := roundi(world_position.z / CELL_SIZE + half_height)
	if raw_column < -2 or raw_column >= grid_size.x + 2:
		return Vector2i(-1, row)
	return Vector2i(
		posmod(raw_column, grid_size.x),
		row
	)


func is_inside(coordinate: Vector2i) -> bool:
	return coordinate.x >= 0 and coordinate.y >= 0 and coordinate.x < grid_size.x and coordinate.y < grid_size.y


func set_hover(coordinate: Vector2i) -> void:
	if coordinate == hovered_coordinate:
		return
	if is_inside(hovered_coordinate):
		_refresh_coordinate(hovered_coordinate)
	hovered_coordinate = coordinate
	if is_inside(coordinate):
		var cell: GridCell = cells[coordinate]
		if cell.highlight == GridCellData.Highlight.NORMAL:
			cell.highlight = GridCellData.Highlight.HOVER
			_update_cell_visual(cell)
	hovered_cell_changed.emit(coordinate)


func clear_highlights() -> void:
	for cell_value: Variant in cells.values():
		var cell: GridCell = cell_value
		_refresh_cell(cell)


func show_movement_targets(coordinates: Array[Vector2i], selected: Vector2i, moving_team: int) -> void:
	clear_highlights()
	for coordinate: Vector2i in coordinates:
		var cell: GridCell = cells[coordinate]
		var occupant := cell.occupant as BattleUnit
		cell.highlight = GridCellData.Highlight.ATTACK if occupant != null and occupant.team_id != moving_team else GridCellData.Highlight.MOVE
		_update_cell_visual(cell)
	if is_inside(selected):
		var selected_cell: GridCell = cells[selected]
		selected_cell.highlight = GridCellData.Highlight.SELECTED
		_update_cell_visual(selected_cell)


func set_occupant(coordinate: Vector2i, unit: Node) -> void:
	if not is_inside(coordinate):
		return
	var cell: GridCell = cells[coordinate]
	cell.occupant = unit
	_refresh_cell(cell)


func move_occupant(unit: Node, from: Vector2i, to: Vector2i) -> void:
	if is_inside(from):
		var from_cell: GridCell = cells[from]
		if from_cell.occupant == unit:
			from_cell.occupant = null
			_refresh_cell(from_cell)
	set_occupant(to, unit)


func remove_occupant(coordinate: Vector2i, unit: Node) -> void:
	if not is_inside(coordinate):
		return
	var cell: GridCell = cells[coordinate]
	if cell.occupant == unit:
		cell.occupant = null
		_refresh_cell(cell)


func get_unit_at(coordinate: Vector2i) -> Node:
	if not is_inside(coordinate):
		return null
	var cell: GridCell = cells[coordinate]
	return cell.occupant


func get_neighbors(coordinate: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := coordinate + offset
		if offset.x != 0:
			neighbor.x = posmod(neighbor.x, grid_size.x)
		if is_inside(neighbor) and neighbor not in result:
			result.append(neighbor)
	return result


func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	var horizontal_distance := absi(a.x - b.x)
	return mini(horizontal_distance, grid_size.x - horizontal_distance) + absi(a.y - b.y)


func _create_cell_visual(cell: GridCell) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Cell_%d_%d" % [cell.coordinate.x, cell.coordinate.y]
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * 0.94, 0.12, CELL_SIZE * 0.94)
	mesh_instance.mesh = box
	mesh_instance.position = cell.world_position + Vector3(0.0, -0.08, 0.0)
	var material := StandardMaterial3D.new()
	material.roughness = 0.62
	material.metallic = 0.12
	mesh_instance.material_override = material
	add_child(mesh_instance)
	cell.visual = mesh_instance
	cell.material = material
	_update_cell_visual(cell)


func _create_wrap_projections() -> void:
	var repeated_width := float(grid_size.x) * CELL_SIZE
	for y: int in range(grid_size.y):
		for depth: int in range(2):
			var left_column := grid_size.x - 1 - depth
			var right_column := depth
			_create_wrap_tile(Vector2i(left_column, y), -repeated_width, 0.46 - float(depth) * 0.17)
			_create_wrap_tile(Vector2i(right_column, y), repeated_width, 0.46 - float(depth) * 0.17)


func _create_wrap_tile(coordinate: Vector2i, horizontal_offset: float, opacity: float) -> void:
	var source_cell: GridCell = cells[coordinate]
	var projection := MeshInstance3D.new()
	projection.name = "WrapCell_%d_%d_%d" % [coordinate.x, coordinate.y, roundi(horizontal_offset)]
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * 0.94, 0.12, CELL_SIZE * 0.94)
	projection.mesh = box
	projection.position = source_cell.world_position + Vector3(horizontal_offset, -0.08, 0.0)
	var material := StandardMaterial3D.new()
	material.roughness = 0.86
	material.metallic = 0.05
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	projection.material_override = material
	add_child(projection)
	if not _wrap_materials.has(coordinate):
		_wrap_materials[coordinate] = []
	(_wrap_materials[coordinate] as Array).append({"material": material, "opacity": opacity})
	wrap_projection_count += 1
	_update_cell_visual(source_cell)


## Glowing portal curtains mark where the board wraps around.
func _create_wrap_seams() -> void:
	var half_width := float(grid_size.x - 1) * 0.5 * CELL_SIZE + CELL_SIZE * 0.5
	var depth := float(grid_size.y) * CELL_SIZE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(0.55, 0.9, 1.0, 0.95), Color(0.35, 0.6, 1.0, 0.55), Color(0.5, 0.3, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	for side: int in [-1, 1]:
		var curtain := MeshInstance3D.new()
		curtain.name = "WrapPortal_%d" % side
		var quad := QuadMesh.new()
		quad.size = Vector2(depth, 0.9)
		curtain.mesh = quad
		curtain.position = Vector3(float(side) * half_width, 0.42, 0.0)
		curtain.rotation_degrees.y = 90.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = texture
		material.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
		curtain.material_override = material
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(curtain)
		var seam := MeshInstance3D.new()
		seam.name = "WrapSeam_%d" % side
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.06, depth)
		seam.mesh = mesh
		seam.position = Vector3(float(side) * half_width, 0.0, 0.0)
		var seam_material := StandardMaterial3D.new()
		seam_material.albedo_color = Color("9fe4ff")
		seam_material.emission_enabled = true
		seam_material.emission = Color("4cc7ff")
		seam_material.emission_energy_multiplier = 1.4
		seam.material_override = seam_material
		add_child(seam)


func _refresh_coordinate(coordinate: Vector2i) -> void:
	if is_inside(coordinate):
		_refresh_cell(cells[coordinate])


func _refresh_cell(cell: GridCell) -> void:
	if cell.occupant != null:
		cell.highlight = GridCellData.Highlight.OCCUPIED
	else:
		cell.highlight = GridCellData.Highlight.NORMAL
	if cell.coordinate == hovered_coordinate and cell.highlight == GridCellData.Highlight.NORMAL:
		cell.highlight = GridCellData.Highlight.HOVER
	_update_cell_visual(cell)


func _update_cell_visual(cell: GridCell) -> void:
	if cell.material == null:
		return
	var is_light_square := (cell.coordinate.x + cell.coordinate.y) % 2 == 0
	var stone_color := Color("4d4b5c") if is_light_square else Color("33323f")
	var tile_color: Color = stone_color if cell.highlight == GridCellData.Highlight.NORMAL else _colors[cell.highlight]
	var is_emissive := cell.highlight in [
		GridCellData.Highlight.HOVER,
		GridCellData.Highlight.SELECTED,
		GridCellData.Highlight.MOVE,
		GridCellData.Highlight.ATTACK,
	]
	_apply_cell_material(cell.material, tile_color, 1.0, is_emissive)
	for projection_value: Variant in _wrap_materials.get(cell.coordinate, []):
		var projection: Dictionary = projection_value
		_apply_cell_material(projection["material"], tile_color, float(projection["opacity"]), is_emissive)


func _apply_cell_material(material: StandardMaterial3D, color: Color, opacity: float, is_emissive: bool) -> void:
	var faded_color := color
	faded_color.a = opacity
	material.albedo_color = faded_color
	material.emission_enabled = is_emissive
	if is_emissive:
		material.emission = color
		material.emission_energy_multiplier = 0.45
