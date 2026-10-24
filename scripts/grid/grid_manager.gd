class_name GridManager
extends Node3D

signal hovered_cell_changed(coordinate: Vector2i)
## The arena halves fly in when a match starts; units and cell frames wait for it.
signal intro_started
signal intro_finished

const GridCellData := preload("res://scripts/grid/grid_cell.gd")
const CELL_SIZE: float = 1.4
## Height of the cell frames above the arena floor.
const MARKER_HEIGHT: float = 0.06
const INTRO_SECONDS: float = 1.4

var grid_size: Vector2i = Vector2i(5, 5)
var cells: Dictionary = {}
## Panel borders of the neutral middle row and of unskinned halves.
const NEUTRAL_GLOW := Color("3f8fd8")
var _arena_halves: Array[ArenaHalf] = []
## Board skin per player half: {"tint", "glow"} (see CharacterRoster.BOARD_SKINS).
var _side_skins: Array[Dictionary] = [
	{"id": "standard", "tint": Color.WHITE, "glow": NEUTRAL_GLOW},
	{"id": "standard", "tint": Color.WHITE, "glow": NEUTRAL_GLOW},
]
var hovered_coordinate: Vector2i = Vector2i(-1, -1)
var wrap_projection_count: int = 0
var _wrap_materials: Dictionary = {}

var _colors: Dictionary = {
	GridCellData.Highlight.NORMAL: Color("35545b"),
	GridCellData.Highlight.HOVER: Color("ffe2b0"),
	GridCellData.Highlight.SELECTED: Color("7ff3ff"),
	GridCellData.Highlight.MOVE: Color("3fb8ff"),
	GridCellData.Highlight.ATTACK: Color("ff4a3d"),
	GridCellData.Highlight.OCCUPIED: Color("f0e6dc"),
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
	_create_arena_halves()
	if get_parent() is Node3D and not get_parent().visibility_changed.is_connected(_on_board_visibility_changed):
		get_parent().visibility_changed.connect(_on_board_visibility_changed)


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
	var mesh_instance := _create_tile_node(cell.coordinate, cell.world_position, 1.0)
	mesh_instance.name = "Cell_%d_%d" % [cell.coordinate.x, cell.coordinate.y]
	cell.visual = mesh_instance
	cell.material = mesh_instance.material_override as StandardMaterial3D
	_update_cell_visual(cell)


## A cell marker: a flat frame just above the arena floor. Its material is the
## one that gets tinted for highlights.
func _create_tile_node(_coordinate: Vector2i, at: Vector3, opacity: float) -> MeshInstance3D:
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL_SIZE * 0.97, CELL_SIZE * 0.97)
	top.mesh = plane
	top.position = at + Vector3(0.0, MARKER_HEIGHT, 0.0)
	top.material_override = ArenaTileStyle.make_material()
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)
	return top


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
	var projection := _create_tile_node(coordinate, source_cell.world_position + Vector3(horizontal_offset, 0.0, 0.0), opacity)
	projection.name = "WrapCell_%d_%d_%d" % [coordinate.x, coordinate.y, roundi(horizontal_offset)]
	var material := projection.material_override as StandardMaterial3D
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
	# The arena model is the skin; a cell only shows a frame that fills for highlights.
	# Occupied cells stay plain so the model underneath shows; only play highlights light up.
	var normal_tile := cell.highlight in [GridCellData.Highlight.NORMAL, GridCellData.Highlight.OCCUPIED]
	var color: Color = ArenaHalf.GLOW if normal_tile else _colors[cell.highlight]
	var hover := cell.highlight == GridCellData.Highlight.HOVER
	if hover:
		ArenaTileStyle.paint_hover(cell.material, Color.WHITE, 1.0)
	else:
		ArenaTileStyle.paint(cell.material, not normal_tile, color, 1.0)
	for projection_value: Variant in _wrap_materials.get(cell.coordinate, []):
		var projection: Dictionary = projection_value
		if hover:
			ArenaTileStyle.paint_hover(projection["material"], Color.WHITE, float(projection["opacity"]))
		else:
			ArenaTileStyle.paint(projection["material"], not normal_tile, color, float(projection["opacity"]))


## The arena halves in the skins the two players chose.
func set_side_skin(team: int, skin: Dictionary) -> void:
	_side_skins[team] = {"id": str(skin.get("id", "standard")), "tint": skin.get("tint", Color.WHITE), "glow": skin.get("glow", NEUTRAL_GLOW)}
	if team < _arena_halves.size():
		_arena_halves[team].show_skin(str(skin.get("id", "standard")))


func _create_arena_halves() -> void:
	_arena_halves.clear()
	for team: int in range(2):
		var half := ArenaHalf.new()
		half.name = "ArenaHalf%d" % team
		add_child(half)
		half.place(team, float(grid_size.y) * CELL_SIZE)
		half.show_skin(str(_side_skins[team]["id"]))
		_arena_halves.append(half)
	var bridge := ArenaBridge.new()
	bridge.name = "ArenaBridge"
	add_child(bridge)
	bridge.build()


func _on_board_visibility_changed() -> void:
	if get_parent() is Node3D and (get_parent() as Node3D).visible:
		hold_arena()


## The board is shown but empty until play_intro(): no platforms, markers or
## figures while the Node Ping runs.
func hold_arena() -> void:
	if _arena_halves.is_empty() or not is_inside_tree():
		return
	intro_started.emit()
	for half: ArenaHalf in _arena_halves:
		half.visible = false
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as Node3D).visible = false


## Own half (team 0) flies up from below, the opponent's down from above; they
## meet in the middle and form the 5 x 5 board.
func play_intro() -> void:
	if _arena_halves.is_empty() or not is_inside_tree():
		intro_finished.emit()
		return
	var last: Tween
	for team: int in range(_arena_halves.size()):
		_arena_halves[team].visible = true
		last = _arena_halves[team].fly_in(team == 0, INTRO_SECONDS)
	await last.finished
	for child: Node in get_children():
		if child is MeshInstance3D and is_instance_valid(child):
			(child as Node3D).visible = true
	intro_finished.emit()
