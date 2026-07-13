class_name HitEffect
extends Node3D


func play(world_position: Vector3) -> void:
	global_position = world_position + Vector3(0.0, 1.0, 0.0)
	for index: int in range(6):
		var spark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.05, 0.52)
		spark.mesh = mesh
		spark.rotation_degrees = Vector3(float(index * 31), float(index * 60), float(index * 47))
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffd36a")
		material.emission_enabled = true
		material.emission = Color("ff8e3c")
		material.emission_energy_multiplier = 3.0
		spark.material_override = material
		add_child(spark)
		var direction := Vector3(cos(float(index) * TAU / 6.0), 0.32, sin(float(index) * TAU / 6.0))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(spark, "position", direction * 0.7, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.24).set_delay(0.06)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	core.mesh = sphere
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color.WHITE
	core_material.emission_enabled = true
	core_material.emission = Color("fff2a8")
	core_material.emission_energy_multiplier = 4.0
	core.material_override = core_material
	add_child(core)
	var core_tween := create_tween()
	core_tween.tween_property(core, "scale", Vector3(2.4, 2.4, 2.4), 0.09)
	core_tween.tween_property(core, "scale", Vector3.ZERO, 0.13)
	core_tween.tween_callback(queue_free)

