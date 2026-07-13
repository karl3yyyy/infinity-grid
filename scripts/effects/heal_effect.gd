class_name HealEffect
extends Node3D

signal effect_peak


func play(at: Vector3, color: Color) -> void:
	global_position = at + Vector3.UP * 0.45
	var rings: Array[MeshInstance3D] = []
	for index: int in range(3):
		var instance := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.23 + float(index) * 0.07
		ring.outer_radius = ring.inner_radius + 0.035
		instance.mesh = ring
		instance.position.y = float(index) * 0.22
		instance.scale = Vector3.ONE * 0.2
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.6
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		instance.material_override = material
		add_child(instance)
		rings.append(instance)
	var tween := create_tween().set_parallel(true)
	for ring_instance: MeshInstance3D in rings:
		tween.tween_property(ring_instance, "scale", Vector3.ONE, 0.28)
		tween.tween_property(ring_instance, "position:y", ring_instance.position.y + 0.38, 0.28)
	await tween.finished
	effect_peak.emit()
	var fade := create_tween().set_parallel(true)
	for ring_instance: MeshInstance3D in rings:
		fade.tween_property(ring_instance, "scale", Vector3.ONE * 1.35, 0.22)
	await fade.finished
	queue_free()

