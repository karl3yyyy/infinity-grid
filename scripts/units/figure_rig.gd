class_name FigureRig
extends Node

## Animates a voxel figure's body parts (see VoxelFigure): idle breathing, a
## walk cycle, and poses for casting, punching and aiming that blend in and
## out. The edge projections of the unit copy every part's transform.

const PART_NAMES: Array[String] = ["Body", "Torso", "Head", "ArmL", "ArmR", "LegL", "LegR"]

## Pose name -> {part name: rotation in radians}.
const POSES: Dictionary = {
	"cast": {"ArmR": Vector3(-2.9, 0.0, 0.25), "ArmL": Vector3(-0.4, 0.0, -0.35), "Head": Vector3(-0.25, 0.0, 0.0), "Torso": Vector3(-0.08, 0.0, 0.0)},
	"channel": {"ArmR": Vector3(-1.55, 0.0, 0.15), "ArmL": Vector3(-1.55, 0.0, -0.15), "Torso": Vector3(0.1, 0.0, 0.0)},
	"wind_up": {"ArmR": Vector3(0.9, 0.0, 0.2), "Torso": Vector3(0.0, -0.45, 0.0), "ArmL": Vector3(-0.6, 0.0, -0.2)},
	"punch": {"ArmR": Vector3(-1.6, 0.0, 0.0), "Torso": Vector3(0.12, 0.4, 0.0), "ArmL": Vector3(0.5, 0.0, -0.2)},
	"aim": {"ArmR": Vector3(-1.57, 0.0, 0.0), "ArmL": Vector3(-1.35, 0.0, -0.45), "Head": Vector3(0.05, 0.12, 0.0), "Torso": Vector3(0.0, -0.2, 0.0)},
	"cheer": {"ArmR": Vector3(-2.8, 0.0, 0.3), "ArmL": Vector3(-2.8, 0.0, -0.3)},
}

var walking: bool = false
var _parts: Dictionary = {}
var _rest_positions: Dictionary = {}
var _mirrors: Array[Dictionary] = []
var _pose: Dictionary = {}
var _pose_weight: float = 0.0
var _time: float = 0.0
var _tween: Tween


## figure: the root returned by VoxelFigure.
func bind(figure: Node3D) -> void:
	_parts = _collect(figure)
	_rest_positions.clear()
	for part_name: String in _parts:
		_rest_positions[part_name] = (_parts[part_name] as Node3D).position
	_time = randf() * 10.0


## Copies of the figure (edge projections) that follow every movement.
func set_mirrors(figures: Array[Node3D]) -> void:
	_mirrors.clear()
	for figure: Node3D in figures:
		_mirrors.append(_collect(figure))


## Blends into a pose over `duration` seconds and waits until it is reached.
func pose(pose_name: String, duration: float = 0.2) -> void:
	if _pose_weight > 0.0 and _pose != POSES.get(pose_name, {}):
		# Switch directly between poses: keep the weight, swap the target.
		_pose = POSES.get(pose_name, {})
		await get_tree().create_timer(duration).timeout
		return
	_pose = POSES.get(pose_name, {})
	await _blend_to(1.0, duration)


func release(duration: float = 0.25) -> void:
	await _blend_to(0.0, duration)


func _blend_to(weight: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_pose_weight", weight, duration)
	await _tween.finished


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	_time += delta * (2.4 if walking else 1.0)
	var swing := sin(_time * 5.2) if walking else 0.0
	var base: Dictionary = {
		"Body": Vector3.ZERO,
		"Torso": Vector3(0.0, sin(_time * 0.9) * 0.05, 0.0),
		"Head": Vector3(sin(_time * 0.7) * 0.04, sin(_time * 0.45) * 0.18, 0.0),
		"ArmL": Vector3(swing * 0.75, 0.0, -0.06 - sin(_time * 1.6) * 0.03),
		"ArmR": Vector3(-swing * 0.75, 0.0, 0.06 + sin(_time * 1.6) * 0.03),
		"LegL": Vector3(-swing * 0.65, 0.0, 0.0),
		"LegR": Vector3(swing * 0.65, 0.0, 0.0),
	}
	var bob := absf(sin(_time * 5.2)) * 0.05 if walking else sin(_time * 1.6) * 0.012
	for part_name: String in _parts:
		var rotation: Vector3 = base.get(part_name, Vector3.ZERO)
		if _pose.has(part_name):
			rotation = rotation.lerp(_pose[part_name], _pose_weight)
		var node := _parts[part_name] as Node3D
		node.rotation = rotation
		if part_name == "Body":
			node.position = _rest_positions[part_name] + Vector3(0.0, bob, 0.0)
	for mirror: Dictionary in _mirrors:
		for part_name: String in mirror:
			var source := _parts.get(part_name) as Node3D
			var target := mirror[part_name] as Node3D
			if source != null and is_instance_valid(target):
				target.transform = source.transform


func _collect(figure: Node3D) -> Dictionary:
	var found: Dictionary = {}
	var body := figure.get_node_or_null("Body") as Node3D
	if body == null:
		return found
	found["Body"] = body
	for child: Node in body.get_children():
		if child is Node3D and str(child.name) in PART_NAMES:
			found[str(child.name)] = child
	return found
