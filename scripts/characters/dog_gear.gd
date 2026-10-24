class_name DogGear
extends RefCounted

## Procedural parts for Evlis, the white Maltese: dog head (muzzle, nose,
## floppy ears, fluffy topknot), tail, bazooka and a long hand-rolled
## cigarette with a glowing tip. Built from boxes and cylinders on the same
## skeleton as every other fighter, positioned in the bind pose.

const FUR := Color("f6f2ea")
const FUR_SHADE := Color("e4ddd0")


static func add_head(model: FighterModel) -> void:
	var head := model._head_attachment()
	var fur := model._flat(FUR)
	var shade := model._flat(FUR_SHADE)
	var black := model._flat(Color("0a0a0c"), 0.0, 0.2)
	# Muzzle with a black nose, a lighter chin and a small tongue-grin line.
	model._box(head, Vector3(0.13, 0.09, 0.16), model._head_point(Vector3(0.0, 0.04, 0.14)), fur)
	model._box(head, Vector3(0.1, 0.04, 0.13), model._head_point(Vector3(0.0, -0.015, 0.14)), shade)
	model._box(head, Vector3(0.06, 0.05, 0.04), model._head_point(Vector3(0.0, 0.075, 0.23)), black)
	# Floppy ears hanging down both sides of the head.
	for side: float in [-1.0, 1.0]:
		var ear := model._box(head, Vector3(0.06, 0.22, 0.13), model._head_point(Vector3(side * 0.115, 0.07, -0.01)), fur)
		ear.rotation_degrees.z = -side * 10.0
		model._box(head, Vector3(0.045, 0.1, 0.11), model._head_point(Vector3(side * 0.125, -0.05, -0.005)), shade)
	# Shaggy cheeks and a wild fringe over the eyes, like a Maltese with a bad day.
	for side: float in [-1.0, 1.0]:
		model._box(head, Vector3(0.05, 0.1, 0.09), model._head_point(Vector3(side * 0.085, 0.0, 0.06)), shade)
		var tuft_side := model._box(head, Vector3(0.05, 0.07, 0.06), model._head_point(Vector3(side * 0.07, 0.17, 0.09)), fur)
		tuft_side.rotation_degrees.z = -side * 20.0
	model._box(head, Vector3(0.16, 0.05, 0.05), model._head_point(Vector3(0.0, 0.15, 0.1)), fur)
	# Fluffy topknot between the ears.
	var tuft := model._box(head, Vector3(0.07, 0.09, 0.08), model._head_point(Vector3(0.0, 0.22, 0.03)), fur)
	tuft.rotation_degrees.x = -12.0
	model._box(head, Vector3(0.05, 0.06, 0.06), model._head_point(Vector3(0.0, 0.28, 0.02)), shade)


static func add_tail(model: FighterModel) -> void:
	var hips := model._bone_attachment("Hips")
	var rest := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("Hips"))
	var fur := model._flat(FUR)
	for index: int in range(3):
		var offset := Vector3(0.0, 0.05 + index * 0.06, -0.13 - index * 0.04)
		var puff := model._box(hips, Vector3(0.09, 0.09, 0.1), rest.affine_inverse() * (rest.origin + offset), fur)
		puff.rotation_degrees.x = 25.0


## Long tube over the right hand; muzzle and rear opening are darker.
static func add_bazooka(model: FighterModel) -> void:
	var bone := model.skeleton.find_bone("RightHand")
	var elbow := model.skeleton.find_bone("RightLowerArm")
	var hand_rest := model.skeleton.get_bone_global_rest(bone)
	var outward := (hand_rest.origin - model.skeleton.get_bone_global_rest(elbow).origin).normalized()
	var attachment := model._bone_attachment("RightHand")
	var olive := model._flat(Color("55603a"), 0.0, 0.3)
	var dark := model._flat(Color("1a1d12"), 0.0, 0.5)
	var warm := model._flat(Color("ff8a3c"), 2.5)
	var tube_start := hand_rest.origin - outward * 0.35
	var tube_end := hand_rest.origin + outward * 0.55
	_tube(model, attachment, hand_rest, tube_start, tube_end, 0.075, olive)
	_tube(model, attachment, hand_rest, tube_end - outward * 0.05, tube_end + outward * 0.05, 0.09, dark)
	_tube(model, attachment, hand_rest, tube_start - outward * 0.04, tube_start + outward * 0.04, 0.095, dark)
	# Sight on top and a glowing warning stripe.
	var up := Vector3.UP * 0.085
	_tube(model, attachment, hand_rest, hand_rest.origin + up - outward * 0.1, hand_rest.origin + up + outward * 0.15, 0.015, dark)
	_tube(model, attachment, hand_rest, tube_end - outward * 0.2, tube_end - outward * 0.17, 0.081, warm)


## Thin white roll sticking out of the muzzle's corner, glowing at the tip.
static func add_cigarette(model: FighterModel) -> void:
	var head := model._head_attachment()
	var paper := model._flat(Color("f3efe2"))
	var ember := model._flat(Color("ff5a1c"), 4.0)
	var start := model._head_point(Vector3(-0.025, 0.01, 0.17))
	var end := model._head_point(Vector3(-0.08, -0.06, 0.4))
	var roll := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.009
	cylinder.bottom_radius = 0.009
	cylinder.height = start.distance_to(end)
	cylinder.radial_segments = 6
	roll.mesh = cylinder
	roll.material_override = paper
	head.add_child(roll)
	var direction := (end - start).normalized()
	roll.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), (start + end) * 0.5)
	roll.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	var tip := model._box(head, Vector3(0.026, 0.026, 0.026), end, ember)
	var smoke := CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 1.6
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.initial_velocity_min = 0.12
	smoke.initial_velocity_max = 0.2
	smoke.scale_amount_min = 0.03
	smoke.scale_amount_max = 0.06
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	smoke.mesh = puff
	smoke.material_override = model._flat(Color(0.85, 0.85, 0.85, 0.6))
	smoke.position = end
	tip.add_child(smoke)
	smoke.position = Vector3.ZERO


## A cylinder between two model-space points, mounted on a bone attachment.
static func _tube(_model: FighterModel, attachment: Node3D, bone_rest: Transform3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var piece := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	piece.mesh = cylinder
	piece.material_override = material
	attachment.add_child(piece)
	var direction := (b - a).normalized()
	var up := Vector3.FORWARD if absf(direction.y) > 0.9 else Vector3.UP
	var in_model := Transform3D(Basis.looking_at(direction, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	piece.transform = bone_rest.affine_inverse() * in_model
