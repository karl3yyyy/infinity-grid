class_name ClothBuilder
extends RefCounted

## Skinned cloth meshes generated around the humanoid skeleton at its rest
## (T-) pose: a long open coat whose skirt follows the legs, and long hair that
## hangs from the head down the back. Being skinned, they bend with every
## animation instead of floating as rigid props.

const SEGMENTS := 26


## Long coat from the collar to the shins with sleeves to the wrists.
static func coat(skeleton: Skeleton3D, color: Color) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neck := _rest(skeleton, "Neck")
	var chest := _rest(skeleton, "UpperChest")
	var spine := _rest(skeleton, "Spine")
	var hips := _rest(skeleton, "Hips")
	var knee := _rest(skeleton, "LeftLowerLeg")
	var arm := _rest(skeleton, "LeftUpperArm")
	var hem_y := knee.y - 0.2
	# y, half width, half depth, centre z, half angle of the front opening.
	var rings: Array[Array] = [
		[neck.y + 0.06, 0.12, 0.115, neck.z + 0.01, 0.75],
		[neck.y - 0.03, 0.115, 0.105, neck.z + 0.02, 0.55],
		[arm.y + 0.03, arm.x * 0.92, 0.15, chest.z, 0.42],
		[chest.y, arm.x * 0.86, 0.16, chest.z, 0.26],
		[spine.y, arm.x * 0.84, 0.145, spine.z, 0.2],
		[hips.y, arm.x * 1.0, 0.165, hips.z, 0.24],
		[lerpf(hips.y, hem_y, 0.5), arm.x * 1.18, 0.2, hips.z, 0.4],
		[hem_y, arm.x * 1.32, 0.24, hips.z - 0.01, 0.55],
	]
	var columns := SEGMENTS + 1
	for ring: Array in rings:
		var y: float = ring[0]
		var half_width: float = ring[1]
		var half_depth: float = ring[2]
		var gap: float = ring[4]
		for column: int in range(columns):
			# Angle 0 is the front (+Z); the opening is left out around it.
			var angle := lerpf(gap, TAU - gap, float(column) / float(SEGMENTS))
			var point := Vector3(sin(angle) * half_width, y, float(ring[3]) + cos(angle) * half_depth)
			var normal := Vector3(sin(angle) / half_width, 0.0, cos(angle) / half_depth).normalized()
			_vertex(tool, point, normal, _torso_weights(skeleton, point, hips.y, hem_y, half_width))
	_strip(tool, 0, rings.size(), columns)
	var offset := rings.size() * columns
	for side: String in ["Left", "Right"]:
		offset += _sleeve(tool, skeleton, side, offset)
	var mesh := MeshInstance3D.new()
	mesh.name = "Coat"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.metallic = 0.15
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	_bind(skeleton, mesh)
	return mesh


## Long hair falling from the back of the head over the shoulder blades.
static func long_hair(skeleton: Skeleton3D, color: Color) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := _rest(skeleton, "Head")
	var neck := _rest(skeleton, "Neck")
	var chest := _rest(skeleton, "UpperChest")
	var head_bone := skeleton.find_bone("Head")
	var chest_bone := skeleton.find_bone("UpperChest")
	# y, half width, half depth, centre z, covered arc around the back.
	var rings: Array[Array] = [
		[head.y + 0.16, 0.1, 0.1, head.z - 0.01, 1.2],
		[head.y + 0.06, 0.118, 0.118, head.z - 0.01, 1.35],
		[neck.y, 0.12, 0.12, neck.z - 0.01, 1.2],
		[neck.y - 0.12, 0.15, 0.13, chest.z - 0.01, 0.95],
		[chest.y - 0.02, 0.14, 0.14, chest.z, 0.8],
		[chest.y - 0.14, 0.11, 0.13, chest.z - 0.01, 0.55],
	]
	var columns := 15
	for ring: Array in rings:
		var y: float = ring[0]
		var arc: float = ring[4]
		# Hair below the neck rides with the chest, above it with the head.
		var to_head := clampf((y - (neck.y - 0.1)) / 0.14, 0.0, 1.0)
		for column: int in range(columns):
			var angle := PI + lerpf(-arc, arc, float(column) / float(columns - 1))
			var point := Vector3(sin(angle) * float(ring[1]), y, float(ring[3]) + cos(angle) * float(ring[2]))
			var normal := Vector3(sin(angle), 0.0, cos(angle))
			_vertex(tool, point, normal, {head_bone: to_head, chest_bone: 1.0 - to_head})
	_strip(tool, 0, rings.size(), columns)
	var mesh := MeshInstance3D.new()
	mesh.name = "LongHair"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	_bind(skeleton, mesh)
	return mesh


static func _sleeve(tool: SurfaceTool, skeleton: Skeleton3D, side: String, offset: int) -> int:
	var shoulder := _rest(skeleton, side + "UpperArm")
	var elbow := _rest(skeleton, side + "LowerArm")
	var wrist := _rest(skeleton, side + "Hand")
	var upper := skeleton.find_bone(side + "UpperArm")
	var lower := skeleton.find_bone(side + "LowerArm")
	var columns := 11
	var stations: Array[float] = [-0.06, 0.0, 0.45, 1.0, 1.5, 1.9]
	for station: float in stations:
		# 0 = shoulder, 1 = elbow, 2 = wrist; slightly negative starts inside the coat.
		var center := shoulder.lerp(elbow, station) if station <= 1.0 else elbow.lerp(wrist, station - 1.0)
		var radius := lerpf(0.085, 0.058, clampf(station / 1.9, 0.0, 1.0))
		var to_lower := clampf((station - 0.85) / 0.3, 0.0, 1.0)
		for column: int in range(columns):
			# The right arm points along -X, so its rings run the other way round.
			var angle := TAU * float(column) / float(columns - 1) * (1.0 if side == "Left" else -1.0)
			var normal := Vector3(0.0, sin(angle), cos(angle))
			_vertex(tool, center + normal * radius, normal, {upper: 1.0 - to_lower, lower: to_lower})
	_strip(tool, offset, stations.size(), columns)
	return stations.size() * columns


## Above the hips the coat moves with the spine; the skirt below is pulled more
## and more by the leg on its side, the back seam half by each.
static func _torso_weights(skeleton: Skeleton3D, point: Vector3, hips_y: float, hem_y: float, half_width: float) -> Dictionary:
	var weights := {}
	if point.y >= hips_y:
		for bone_name: String in ["UpperChest", "Chest", "Spine", "Hips"]:
			weights[skeleton.find_bone(bone_name)] = 0.0
		var rest_y := {"UpperChest": _rest(skeleton, "UpperChest").y, "Chest": _rest(skeleton, "Chest").y, "Spine": _rest(skeleton, "Spine").y, "Hips": hips_y}
		var nearest := "Hips"
		for bone_name: String in rest_y:
			if point.y >= float(rest_y[bone_name]):
				nearest = bone_name
				break
		weights[skeleton.find_bone(nearest)] = 1.0
		return weights
	var down := clampf((hips_y - point.y) / maxf(hips_y - hem_y, 0.01), 0.0, 1.0) * 0.85
	var left := clampf(0.5 + point.x / (half_width * 1.2), 0.0, 1.0)
	weights[skeleton.find_bone("Hips")] = 1.0 - down
	weights[skeleton.find_bone("LeftUpperLeg")] = down * left
	weights[skeleton.find_bone("RightUpperLeg")] = down * (1.0 - left)
	return weights


static func _vertex(tool: SurfaceTool, point: Vector3, normal: Vector3, weights: Dictionary) -> void:
	var bones := PackedInt32Array([0, 0, 0, 0])
	var values := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var index := 0
	for bone: int in weights:
		if index >= 4 or bone < 0:
			continue
		bones[index] = bone
		values[index] = float(weights[bone])
		index += 1
	tool.set_bones(bones)
	tool.set_weights(values)
	tool.set_normal(normal)
	tool.add_vertex(point)


## Quads between consecutive rows of `columns` vertices.
static func _strip(tool: SurfaceTool, offset: int, rows: int, columns: int) -> void:
	for row: int in range(rows - 1):
		for column: int in range(columns - 1):
			var a := offset + row * columns + column
			var b := a + columns
			# Wound so the outside is the front face (Godot flips normals on back faces).
			for index: int in [a, a + 1, b, a + 1, b + 1, b]:
				tool.add_index(index)


static func _rest(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


static func _bind(skeleton: Skeleton3D, mesh: MeshInstance3D) -> void:
	skeleton.add_child(mesh)
	mesh.skin = skeleton.create_skin_from_rest_transforms()
	mesh.skeleton = mesh.get_path_to(skeleton)
