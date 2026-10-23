class_name HeadScaleModifier
extends SkeletonModifier3D

## Enlarges the head after the animation has posed the skeleton, for the
## baby's and the kid's proportions. Everything attached to the head follows.

var head_scale: float = 1.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head >= 0:
		skeleton.set_bone_pose_scale(head, Vector3.ONE * head_scale)
