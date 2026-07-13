class_name DamageNumber
extends Label3D


func show_damage(amount: int, world_position: Vector3) -> void:
	text = "-%d" % amount
	global_position = world_position + Vector3(0.0, 2.1, 0.0)
	font_size = 54
	outline_size = 10
	modulate = Color("fff06a")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector3(0.0, 1.0, 0.0), 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.82).set_delay(0.18)
	tween.chain().tween_callback(queue_free)

