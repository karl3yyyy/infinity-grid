class_name BoneFighterModel
extends FighterModel

## A fighter that is one rigged glTF (Mixamo-style skeleton) instead of the
## dressed human base. It has no animations of its own, so EvlisAnimations
## builds a library of bone movements under the names the game already plays
## (Idle, Jog_Fwd, Pistol_Aim_Neutral, Death01 ...). A weapon scene sits on the
## shoulder and a plain white cigarette on the muzzle; both can move.

const BONE_PREFIX := "mixamorig_"

var weapon: Node3D
var cigarette: Node3D
var _cigarette_mount: BoneAttachment3D
var _hand_mount: BoneAttachment3D


## look: "model_scene" (glTF path), optional "weapon_scene", "scale".
func build(look: Dictionary) -> void:
	var body := (load(str(look["model_scene"])) as PackedScene).instantiate() as Node3D
	body.name = "Body"
	add_child(body)
	skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	scale = Vector3.ONE * float(look.get("scale", 1.0))
	_add_cigarette()
	if look.has("weapon_scene"):
		_add_weapon(look["weapon_scene"] as String, look.get("weapon_pose", {}) as Dictionary)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.root_node = animation_player.get_path_to(body)
	animation_player.add_animation_library("", EvlisAnimations.library(skeleton, body.get_path_to(skeleton), animation_player.get_path_to(self)))
	play(&"Idle")


## The bazooka rests on the right shoulder; `back` turns it round (fired backwards in flight).
func aim_weapon_back(back: bool, seconds: float = 0.2) -> void:
	if weapon == null:
		return
	var tween := weapon.create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(weapon, "rotation:y", PI if back else 0.0, seconds)


## Called by the Idle/Smoke animations: the cigarette travels to the hand and back.
func cigarette_in_hand(in_hand: bool) -> void:
	if cigarette == null:
		return
	cigarette.get_parent().remove_child(cigarette)
	(_hand_mount if in_hand else _cigarette_mount).add_child(cigarette)
	cigarette.transform = _hand_cigarette_pose() if in_hand else _mouth_cigarette_pose()


func _add_cigarette() -> void:
	_cigarette_mount = _mount("Head")
	_hand_mount = _mount("LeftHand")
	cigarette = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.008
	tube.bottom_radius = 0.008
	tube.height = 0.2
	tube.radial_segments = 6
	(cigarette as MeshInstance3D).mesh = tube
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(1, 1, 1)
	paper.roughness = 0.9
	(cigarette as MeshInstance3D).material_override = paper
	_cigarette_mount.add_child(cigarette)
	cigarette.transform = _mouth_cigarette_pose()


func _mouth_cigarette_pose() -> Transform3D:
	return _bone_local(_cigarette_mount, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, -0.2), Vector3(-0.03, 0.34, 0.2)))


func _hand_cigarette_pose() -> Transform3D:
	return _bone_local(_hand_mount, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.1, 0.0)))


## Places a model-space transform (bind pose) in a bone attachment's own space.
func _bone_local(mount: BoneAttachment3D, in_model: Transform3D) -> Transform3D:
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(mount.bone_name))
	return rest.affine_inverse() * in_model


func _add_weapon(path: String, pose: Dictionary) -> void:
	var mount := _mount("Spine2")
	var holder := Node3D.new()
	holder.name = "WeaponHolder"
	mount.add_child(holder)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(mount.bone_name))
	var offset: Vector3 = pose.get("offset", Vector3(-0.19, 0.12, 0.05))
	var turn: Vector3 = pose.get("rotation_degrees", Vector3(-10.0, 90.0, 0.0))
	holder.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(turn * PI / 180.0), rest.origin + offset)
	weapon = Node3D.new()
	weapon.name = "Weapon"
	holder.add_child(weapon)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * float(pose.get("scale", 0.45))
	weapon.add_child(model)


func _mount(bone: String) -> BoneAttachment3D:
	return _bone_attachment(BONE_PREFIX + bone)
