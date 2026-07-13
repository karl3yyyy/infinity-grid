class_name ProjectileEffect
extends Node3D

signal impacted

var _mesh: MeshInstance3D
var _trail: GPUParticles3D


func setup(color: Color, arrow_shape: bool) -> void:
	_mesh = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	if arrow_shape:
		var arrow := CylinderMesh.new()
		arrow.top_radius = 0.025
		arrow.bottom_radius = 0.025
		arrow.height = 0.72
		_mesh.mesh = arrow
		_mesh.rotation_degrees.x = 90.0
	else:
		var orb := SphereMesh.new()
		orb.radius = 0.14
		orb.height = 0.28
		_mesh.mesh = orb
	_mesh.material_override = material
	add_child(_mesh)


func fly(from: Vector3, to: Vector3, duration: float = 0.32) -> void:
	global_position = from
	look_at(to, Vector3.UP)
	var midpoint := (from + to) * 0.5 + Vector3.UP * 0.65
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(weight: float) -> void:
		var first := from.lerp(midpoint, weight)
		var second := midpoint.lerp(to, weight)
		global_position = first.lerp(second, weight)
	, 0.0, 1.0, duration)
	await tween.finished
	global_position = to
	impacted.emit()

