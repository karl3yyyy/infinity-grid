class_name GridManager
extends Node3D

signal hovered_cell_changed(coordinate: Vector2i)

const GridCellData := preload("res://scripts/grid/grid_cell.gd")
const CELL_SIZE: float = 1.4

var grid_size: Vector2i = Vector2i(10, 10)
var cells: Dictionary = {}
var obstacle_coordinates: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(4, 5), Vector2i(7, 5),
]
var hovered_coordinate: Vector2i = Vector2i(-1, -1)

var _colors: Dictionary = {
	GridCellData.Highlight.NORMAL: Color("35545b"),
	GridCellData.Highlight.HOVER: Color("6bd8d0"),
	GridCellData.Highlight.SELECTED: Color("f8d66d"),
	GridCellData.Highlight.MOVE: Color("54a7e8"),
	GridCellData.Highlight.ATTACK: Color("e95b65"),
	GridCellData.Highlight.OCCUPIED: Color("5e6b80"),
	GridCellData.Highlight.BLOCKED: Color("242c35"),
}


func setup() -> void:
	for child: Node in get_children():
		child.queue_free()
	cells.clear()
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var coordinate := Vector2i(x, y)
			var cell := GridCellData.new(coordinate, grid_to_world(coordinate))
			cells[coordinate] = cell
			_create_cell_visual(cell)
	for coordinate: Vector2i in obstacle_coordinates:
		var cell: GridCell = cells[coordinate]
		cell.walkable = false
		cell.highlight = GridCellData.Highlight.BLOCKED
		_create_obstacle(cell)
		_update_cell_visual(cell)


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
	return Vector2i(
		roundi(world_position.x / CELL_SIZE + half_width),
		roundi(world_position.z / CELL_SIZE + half_height)
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


func show_reachable(coordinates: Array[Vector2i], selected: Vector2i) -> void:
	clear_highlights()
	for coordinate: Vector2i in coordinates:
		if coordinate == selected:
			continue
		var cell: GridCell = cells[coordinate]
		if cell.occupant == null:
			cell.highlight = GridCellData.Highlight.MOVE
			_update_cell_visual(cell)
	if is_inside(selected):
		var selected_cell: GridCell = cells[selected]
		selected_cell.highlight = GridCellData.Highlight.SELECTED
		_update_cell_visual(selected_cell)


func show_attackable(coordinates: Array[Vector2i], selected: Vector2i) -> void:
	clear_highlights()
	for coordinate: Vector2i in coordinates:
		if is_inside(coordinate):
			var cell: GridCell = cells[coordinate]
			cell.highlight = GridCellData.Highlight.ATTACK
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
		if is_inside(neighbor):
			result.append(neighbor)
	return result


func get_reachable(start: Vector2i, movement_range: int, moving_unit: Node = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var costs: Dictionary = {start: 0}
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		result.append(current)
		for neighbor: Vector2i in get_neighbors(current):
			var cell: GridCell = cells[neighbor]
			if not cell.walkable or (cell.occupant != null and cell.occupant != moving_unit):
				continue
			var next_cost: int = int(costs[current]) + cell.movement_cost
			if next_cost > movement_range:
				continue
			if not costs.has(neighbor) or next_cost < int(costs[neighbor]):
				costs[neighbor] = next_cost
				frontier.append(neighbor)
	return result


func find_path(start: Vector2i, goal: Vector2i, moving_unit: Node = null) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not is_inside(start) or not is_inside(goal):
		return empty
	var goal_cell: GridCell = cells[goal]
	if not goal_cell.walkable or (goal_cell.occupant != null and goal_cell.occupant != moving_unit):
		return empty
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if current == goal:
			break
		for neighbor: Vector2i in get_neighbors(current):
			if came_from.has(neighbor):
				continue
			var cell: GridCell = cells[neighbor]
			if not cell.walkable or (cell.occupant != null and cell.occupant != moving_unit):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)
	if not came_from.has(goal):
		return empty
	var path: Array[Vector2i] = []
	var step := goal
	while step != start:
		path.push_front(step)
		step = came_from[step]
	path.push_front(start)
	return path


func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if not is_inside(from) or not is_inside(to) or from == to:
		return false
	var x := from.x
	var y := from.y
	var delta_x := absi(to.x - from.x)
	var delta_y := absi(to.y - from.y)
	var step_x := 1 if from.x < to.x else -1
	var step_y := 1 if from.y < to.y else -1
	var error := delta_x - delta_y
	while true:
		var coordinate := Vector2i(x, y)
		if coordinate != from and coordinate != to:
			var cell: GridCell = cells[coordinate]
			if not cell.walkable or cell.occupant != null:
				return false
		if coordinate == to:
			break
		var doubled_error := error * 2
		if doubled_error > -delta_y:
			error -= delta_y
			x += step_x
		if doubled_error < delta_x:
			error += delta_x
			y += step_y
	return true


func _create_cell_visual(cell: GridCell) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Cell_%d_%d" % [cell.coordinate.x, cell.coordinate.y]
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * 0.94, 0.12, CELL_SIZE * 0.94)
	mesh_instance.mesh = box
	mesh_instance.position = cell.world_position + Vector3(0.0, -0.08, 0.0)
	var material := StandardMaterial3D.new()
	material.roughness = 0.86
	material.metallic = 0.05
	mesh_instance.material_override = material
	add_child(mesh_instance)
	cell.visual = mesh_instance
	cell.material = material
	_update_cell_visual(cell)


func _create_obstacle(cell: GridCell) -> void:
	var obstacle := MeshInstance3D.new()
	obstacle.name = "Obstacle_%d_%d" % [cell.coordinate.x, cell.coordinate.y]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 1.0, 0.72)
	obstacle.mesh = mesh
	obstacle.position = cell.world_position + Vector3(0.0, 0.48, 0.0)
	obstacle.rotation_degrees.y = float((cell.coordinate.x * 37 + cell.coordinate.y * 19) % 35)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("68635c")
	material.roughness = 0.95
	obstacle.material_override = material
	add_child(obstacle)


func _refresh_coordinate(coordinate: Vector2i) -> void:
	if is_inside(coordinate):
		_refresh_cell(cells[coordinate])


func _refresh_cell(cell: GridCell) -> void:
	if not cell.walkable:
		cell.highlight = GridCellData.Highlight.BLOCKED
	elif cell.occupant != null:
		cell.highlight = GridCellData.Highlight.OCCUPIED
	else:
		cell.highlight = GridCellData.Highlight.NORMAL
	if cell.coordinate == hovered_coordinate and cell.highlight == GridCellData.Highlight.NORMAL:
		cell.highlight = GridCellData.Highlight.HOVER
	_update_cell_visual(cell)


func _update_cell_visual(cell: GridCell) -> void:
	if cell.material == null:
		return
	cell.material.albedo_color = _colors[cell.highlight]
	cell.material.emission_enabled = cell.highlight in [
		GridCellData.Highlight.HOVER,
		GridCellData.Highlight.SELECTED,
		GridCellData.Highlight.MOVE,
		GridCellData.Highlight.ATTACK,
	]
	if cell.material.emission_enabled:
		cell.material.emission = _colors[cell.highlight] * 0.36
		cell.material.emission_energy_multiplier = 0.75
