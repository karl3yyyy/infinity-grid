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
var _puff_root: Node3D


## look: "model_scene" (glTF path), optional "weapon_scene", "scale", "smoker" (cigarette).
func build(look: Dictionary) -> void:
	var body := (load(str(look["model_scene"])) as PackedScene).instantiate() as Node3D
	body.name = "Body"
	add_child(body)
	skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	scale = Vector3.ONE * float(look.get("scale", 1.0))
	if look.get("smoker", false):
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
	return _bone_local(_cigarette_mount, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, 0.9), Vector3(-0.045, 0.715, 0.2)))


func _hand_cigarette_pose() -> Transform3D:
	# Pinched in the middle of the paw, in front of it, the glowing end pointing away from the mouth.
	var hand := skeleton.get_bone_global_rest(skeleton.find_bone(_hand_mount.bone_name)).origin
	var finger := skeleton.get_bone_global_rest(skeleton.find_bone(BONE_PREFIX + "LeftHandIndex1")).origin
	var toward_fingers := (finger - hand).normalized()
	return _bone_local(_hand_mount, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), hand + toward_fingers * 0.03 + Vector3(0.0, 0.0, -0.04)))


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


## Still for portraits: mid-puff of the Smoke animation, with wisps drifting
## from the mouth over the bazooka like a cowboy blowing over his gun.
func show_smoke_pose(seconds: float = 2.2) -> void:
	if cigarette == null:
		return
	animation_player.play(&"Smoke")
	# The first frame is still the rest pose; pose it one frame later.
	await (Engine.get_main_loop() as SceneTree).process_frame
	animation_player.seek(seconds, true)
	animation_player.pause()
	cigarette_in_hand(true)
	add_smoke_puffs()


## Called by the Cool animation: the exhale after the drag.
func show_puffs(shown: bool) -> void:
	if _puff_root != null:
		_puff_root.visible = shown


func add_smoke_puffs(shown: bool = true) -> void:
	_puff_root = Node3D.new()
	_puff_root.visible = shown
	_cigarette_mount.add_child(_puff_root)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.92, 0.94, 1.0, 0.3)
	for index: int in range(6):
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.02 + 0.005 * float(index)
		ball.height = ball.radius * 2.0
		ball.radial_segments = 10
		ball.rings = 6
		puff.mesh = ball
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_puff_root.add_child(puff)
		var from := Vector3(0.02 - 0.03 * float(index), 0.76 + 0.045 * float(index), 0.2 + 0.012 * float(index))
		puff.transform = _bone_local(_cigarette_mount, Transform3D(Basis.IDENTITY, from))


## Showcase portrait: no weapon, a fat glowing cigarette in the mouth and the
## "Cool" animation (thumbs up, peace). The weapon only belongs in the arena.
func show_cool_pose() -> void:
	if cigarette == null:
		play(&"Idle")
		return
	if weapon != null:
		weapon.visible = false
	cigarette_in_hand(false)
	var tube := (cigarette as MeshInstance3D).mesh as CylinderMesh
	tube.top_radius = 0.014
	tube.bottom_radius = 0.014
	tube.height = 0.13
	var ember := MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.02
	tip.height = 0.04
	ember.mesh = tip
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ff7a2a")
	ember.material_override = glow
	ember.position = Vector3(0.0, 0.065, 0.0)
	cigarette.add_child(ember)
	play(&"Cool")
	add_smoke_puffs(false)
