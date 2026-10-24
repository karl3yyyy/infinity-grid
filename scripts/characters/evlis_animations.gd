class_name EvlisAnimations
extends RefCounted

## Hand-made bone animations for Evlis, named like the human animations the
## game already plays. Spine, hips, neck and legs take Euler keys on top of the
## rest pose: x = roll, y = twist, z = pitch (negative: forward / folded
## forward, positive: back). Arms and forearms take a direction in model space
## (x: his left, y: up, z: forward); the bone is turned so it points that way.

const PREFIX := "mixamorig_"
const BONES: Dictionary = {
	"Hips": "Hips", "Spine": "Spine", "Spine1": "Spine1", "Spine2": "Spine2", "Neck": "Neck", "Head": "Head",
	"LArm": "LeftArm", "RArm": "RightArm", "LFore": "LeftForeArm", "RFore": "RightForeArm",
	"LUp": "LeftUpLeg", "RUp": "RightUpLeg", "LLeg": "LeftLeg", "RLeg": "RightLeg",
}
const DIRECTION_BONES: Array[String] = ["LArm", "RArm", "LFore", "RFore"]
## Arms relaxed at the sides, elbows a little forward.
const STANCE_DIRECTIONS: Dictionary = {
	"LArm": Vector3(0.18, -1.0, 0.05), "RArm": Vector3(-0.18, -1.0, 0.05),
	"LFore": Vector3(0.1, -0.9, 0.35), "RFore": Vector3(-0.1, -0.9, 0.35),
}

var _skeleton: Skeleton3D
var _path: NodePath
var _cache: Dictionary = {}


static func library(skeleton: Skeleton3D, skeleton_path: NodePath, _model_path: NodePath) -> AnimationLibrary:
	var maker := EvlisAnimations.new()
	maker._skeleton = skeleton
	maker._path = skeleton_path
	var lib := AnimationLibrary.new()
	var all := maker.definitions()
	for animation_name: StringName in all:
		lib.add_animation(animation_name, all[animation_name])
	return lib


func definitions() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var smoke := _smoke_keys(14.0)
	_cache[&"Idle"] = _make(20.0, true, _merge(_breath(20.0), smoke["bones"]), _breath_hips(20.0), smoke["methods"])
	var emote := _smoke_keys(0.0)
	_cache[&"Smoke"] = _make(4.5, false, emote["bones"], [], emote["methods"])
	_cache[&"Jog_Fwd"] = _make(0.64, true, _walk(), [[0.0, 0.0], [0.16, 0.035], [0.32, 0.0], [0.48, 0.035], [0.64, 0.0]])
	_cache[&"Pistol_Aim_Neutral"] = _make(1.0, true, _aim(0.0))
	_cache[&"Pistol_Shoot"] = _make(0.5, false, _aim(1.0))
	_cache[&"Spell_Simple_Enter"] = _cache[&"Pistol_Aim_Neutral"]
	_cache[&"Spell_Simple_Shoot"] = _cache[&"Pistol_Shoot"]
	_cache[&"Punch_Enter"] = _cache[&"Pistol_Aim_Neutral"]
	_cache[&"Punch_Jab"] = _cache[&"Pistol_Shoot"]
	_cache[&"Punch_Cross"] = _cache[&"Pistol_Shoot"]
	_cache[&"Jump"] = _make(1.0, false, _jump(), [[0.0, 0.0], [0.15, -0.08], [0.4, 0.1], [0.8, 0.0], [1.0, 0.0]])
	_cache[&"Hit_Chest"] = _make(0.5, false, _hit(), [[0.0, 0.0], [0.1, -0.03], [0.5, 0.0]])
	_cache[&"Death01"] = _make(1.2, false, _death(), [[0.0, 0.0], [0.5, -0.15], [1.0, -0.4], [1.2, -0.4]])
	_cache[&"Dance"] = _make(1.2, true, _dance(), [[0.0, 0.0], [0.3, 0.05], [0.6, 0.0], [0.9, 0.05], [1.2, 0.0]])
	_cache[&"Twerk"] = _make(0.5, true, _twerk(), [[0.0, -0.2], [0.5, -0.2]])
	_cache[&"Idle_Talking"] = _make(0.8, true, _laugh(), [[0.0, 0.0], [0.2, 0.02], [0.4, 0.0], [0.6, 0.02], [0.8, 0.0]])
	_cache[&"Laugh"] = _cache[&"Idle_Talking"]
	_cache[&"Cheer"] = _make(1.0, true, _cheer(), [[0.0, 0.0], [0.25, 0.05], [0.5, 0.0], [0.75, 0.05], [1.0, 0.0]])
	_cache[&"Sitting_Enter"] = _make(0.6, false, _sit(), [[0.0, 0.0], [0.6, -0.3]])
	_cache[&"Sitting_Idle"] = _make(2.0, true, _sit(), [[0.0, -0.3], [2.0, -0.3]])
	_cache[&"Sitting_Exit"] = _make(0.6, false, _sit(), [[0.0, -0.3], [0.6, 0.0]])
	return _cache


func _breath(length: float) -> Dictionary:
	var keys: Array = []
	var chest: Array = []
	var head: Array = []
	var t := 0.0
	while t < 12.0:
		keys.append([t, Vector3.ZERO])
		chest.append([t, Vector3.ZERO])
		head.append([t, Vector3.ZERO])
		keys.append([t + 1.2, Vector3(0.0, 0.0, 0.025)])
		chest.append([t + 1.2, Vector3(0.0, 0.0, 0.035)])
		head.append([t + 1.2, Vector3(0.0, 0.03, -0.02)])
		t += 2.4
	for track: Array in [keys, chest, head]:
		track.append([length, Vector3.ZERO])
	return {"Spine1": keys, "Spine2": chest, "Head": head}


func _breath_hips(length: float) -> Array:
	var keys: Array = []
	var t := 0.0
	while t < length - 0.01:
		keys.append([t, 0.0])
		keys.append([t + 1.2, 0.006])
		t += 2.4
	keys.append([length, 0.0])
	return keys


## The cigarette pull: left hand to the mouth, takes the cigarette, puff, back.
func _smoke_keys(start: float) -> Dictionary:
	var rest_arm: Vector3 = STANCE_DIRECTIONS["LArm"]
	var rest_fore: Vector3 = STANCE_DIRECTIONS["LFore"]
	var up_arm := Vector3(0.35, -0.3, 0.9)
	var up_fore := Vector3(0.05, 1.0, 0.3)
	var bones := {
		"LArm": [[start, rest_arm], [start + 0.7, up_arm], [start + 2.6, up_arm], [start + 3.4, rest_arm]],
		"LFore": [[start, rest_fore], [start + 0.7, up_fore], [start + 1.7, up_fore], [start + 2.2, Vector3(0.4, 0.5, 0.7)], [start + 2.9, up_fore], [start + 3.4, rest_fore]],
		"Head": [[start, Vector3.ZERO], [start + 0.7, Vector3(0, 0, 0.1)], [start + 2.2, Vector3(0, 0, 0.35)], [start + 3.0, Vector3(0, 0, 0.1)], [start + 3.5, Vector3.ZERO]],
		"Spine2": [[start, Vector3.ZERO], [start + 2.2, Vector3(0, 0, 0.12)], [start + 3.4, Vector3.ZERO]],
	}
	var methods := [[start + 0.8, "cigarette_in_hand", [true]], [start + 2.5, "cigarette_in_hand", [false]]]
	return {"bones": bones, "methods": methods}


func _walk() -> Dictionary:
	var swing_a := Vector3(0.18, -1.0, 0.55)
	var swing_b := Vector3(0.18, -1.0, -0.4)
	var swing_c := Vector3(-0.18, -1.0, -0.4)
	var swing_d := Vector3(-0.18, -1.0, 0.55)
	return {
		"LUp": [[0.0, Vector3(0, 0, -0.6)], [0.32, Vector3(0, 0, 0.6)], [0.64, Vector3(0, 0, -0.6)]],
		"RUp": [[0.0, Vector3(0, 0, 0.6)], [0.32, Vector3(0, 0, -0.6)], [0.64, Vector3(0, 0, 0.6)]],
		"LLeg": [[0.0, Vector3.ZERO], [0.16, Vector3(0, 0, 0.8)], [0.32, Vector3.ZERO], [0.64, Vector3.ZERO]],
		"RLeg": [[0.0, Vector3.ZERO], [0.32, Vector3.ZERO], [0.48, Vector3(0, 0, 0.8)], [0.64, Vector3.ZERO]],
		"Spine1": [[0.0, Vector3(0, 0, -0.12)], [0.64, Vector3(0, 0, -0.12)]],
		"Hips": [[0.0, Vector3(0, 0.12, 0)], [0.32, Vector3(0, -0.12, 0)], [0.64, Vector3(0, 0.12, 0)]],
		"LArm": [[0.0, swing_b], [0.32, swing_a], [0.64, swing_b]],
		"RArm": [[0.0, swing_d], [0.32, swing_c], [0.64, swing_d]],
	}


## Bazooka on the right shoulder: right hand holds it, left hand steadies. `kick` adds recoil.
func _aim(kick: float) -> Dictionary:
	var t_end := 1.0 if kick == 0.0 else 0.5
	var right_arm := Vector3(-0.3, -0.6, 0.75)
	var right_fore := Vector3(-0.1, 0.55, 0.8)
	var left_arm := Vector3(0.3, -0.55, 0.8)
	var left_fore := Vector3(0.0, 0.15, 1.0)
	return {
		"RArm": [[0.0, right_arm], [t_end, right_arm]],
		"RFore": [[0.0, right_fore], [t_end, right_fore]],
		"LArm": [[0.0, left_arm], [t_end, left_arm]],
		"LFore": [[0.0, left_fore], [t_end, left_fore]],
		"Spine1": [[0.0, Vector3(0, 0.2, 0)], [t_end * 0.2, Vector3(0, 0.2, kick * 0.2)], [t_end, Vector3(0, 0.2, 0)]],
		"Head": [[0.0, Vector3(0, -0.2, 0)], [t_end, Vector3(0, -0.2, 0)]],
	}


func _jump() -> Dictionary:
	var up_l := Vector3(0.5, 0.8, 0.2)
	var up_r := Vector3(-0.5, 0.8, 0.2)
	return {
		"LUp": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 0.5)], [0.5, Vector3(0, 0, -0.5)], [1.0, Vector3.ZERO]],
		"RUp": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 0.5)], [0.5, Vector3(0, 0, -0.7)], [1.0, Vector3.ZERO]],
		"LLeg": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 0.9)], [0.5, Vector3(0, 0, 0.5)], [1.0, Vector3.ZERO]],
		"RLeg": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 0.9)], [0.5, Vector3(0, 0, 0.5)], [1.0, Vector3.ZERO]],
		"Spine1": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0, -0.2)], [1.0, Vector3.ZERO]],
		"LArm": [[0.0, STANCE_DIRECTIONS["LArm"]], [0.3, up_l], [1.0, STANCE_DIRECTIONS["LArm"]]],
		"RArm": [[0.0, STANCE_DIRECTIONS["RArm"]], [0.3, up_r], [1.0, STANCE_DIRECTIONS["RArm"]]],
	}


func _hit() -> Dictionary:
	return {
		"Spine1": [[0.0, Vector3.ZERO], [0.1, Vector3(0, 0, 0.35)], [0.5, Vector3.ZERO]],
		"Head": [[0.0, Vector3.ZERO], [0.1, Vector3(0, 0, 0.4)], [0.5, Vector3.ZERO]],
		"LArm": [[0.0, STANCE_DIRECTIONS["LArm"]], [0.1, Vector3(0.7, -0.5, -0.3)], [0.5, STANCE_DIRECTIONS["LArm"]]],
		"RArm": [[0.0, STANCE_DIRECTIONS["RArm"]], [0.1, Vector3(-0.7, -0.5, -0.3)], [0.5, STANCE_DIRECTIONS["RArm"]]],
	}


func _death() -> Dictionary:
	var out_l := Vector3(0.95, -0.3, 0.0)
	var out_r := Vector3(-0.95, -0.3, 0.0)
	return {
		"Hips": [[0.0, Vector3.ZERO], [1.0, Vector3(0, 0, 1.45)], [1.2, Vector3(0, 0, 1.45)]],
		"Head": [[0.0, Vector3.ZERO], [1.0, Vector3(0, 0, 0.3)], [1.2, Vector3(0, 0, 0.3)]],
		"LArm": [[0.0, STANCE_DIRECTIONS["LArm"]], [1.0, out_l], [1.2, out_l]],
		"RArm": [[0.0, STANCE_DIRECTIONS["RArm"]], [1.0, out_r], [1.2, out_r]],
		"LLeg": [[0.0, Vector3.ZERO], [1.0, Vector3(0, 0, 0.6)], [1.2, Vector3(0, 0, 0.6)]],
		"RLeg": [[0.0, Vector3.ZERO], [1.0, Vector3(0, 0, 0.3)], [1.2, Vector3(0, 0, 0.3)]],
	}


func _dance() -> Dictionary:
	var l_up := Vector3(0.6, 0.8, 0.2)
	var l_out := Vector3(0.9, -0.2, 0.3)
	var r_up := Vector3(-0.6, 0.8, 0.2)
	var r_out := Vector3(-0.9, -0.2, 0.3)
	return {
		"Hips": [[0.0, Vector3(0.15, 0.3, 0)], [0.6, Vector3(-0.15, -0.3, 0)], [1.2, Vector3(0.15, 0.3, 0)]],
		"LArm": [[0.0, l_up], [0.6, l_out], [1.2, l_up]],
		"RArm": [[0.0, r_out], [0.6, r_up], [1.2, r_out]],
		"Head": [[0.0, Vector3(0.1, 0, 0)], [0.6, Vector3(-0.1, 0, 0)], [1.2, Vector3(0.1, 0, 0)]],
		"LUp": [[0.0, Vector3(0, 0, -0.3)], [0.6, Vector3(0, 0, 0.1)], [1.2, Vector3(0, 0, -0.3)]],
		"RUp": [[0.0, Vector3(0, 0, 0.1)], [0.6, Vector3(0, 0, -0.3)], [1.2, Vector3(0, 0, 0.1)]],
	}


## Bent over with hands on the knees, rear out, hips shaking.
func _twerk() -> Dictionary:
	var hands_l := Vector3(0.25, -0.9, 0.45)
	var hands_r := Vector3(-0.25, -0.9, 0.45)
	var hip := func(sign: float, pitch: float) -> Vector3: return Vector3(0.18 * sign, 0.3 * sign, pitch)
	return {
		"Hips": [[0.0, hip.call(1.0, -0.5)], [0.125, hip.call(-1.0, -0.65)], [0.25, hip.call(1.0, -0.5)], [0.375, hip.call(-1.0, -0.65)], [0.5, hip.call(1.0, -0.5)]],
		"Spine": [[0.0, Vector3(0, 0, 0.25)], [0.5, Vector3(0, 0, 0.25)]],
		"Head": [[0.0, Vector3(0, 0, 0.45)], [0.5, Vector3(0, 0, 0.45)]],
		"LUp": [[0.0, Vector3(0, 0, 0.95)], [0.5, Vector3(0, 0, 0.95)]],
		"RUp": [[0.0, Vector3(0, 0, 0.95)], [0.5, Vector3(0, 0, 0.95)]],
		"LLeg": [[0.0, Vector3(0, 0, 1.1)], [0.5, Vector3(0, 0, 1.1)]],
		"RLeg": [[0.0, Vector3(0, 0, 1.1)], [0.5, Vector3(0, 0, 1.1)]],
		"LArm": [[0.0, hands_l], [0.5, hands_l]],
		"RArm": [[0.0, hands_r], [0.5, hands_r]],
	}


func _laugh() -> Dictionary:
	var belly_l := Vector3(0.3, -0.8, 0.45)
	var belly_r := Vector3(-0.3, -0.8, 0.45)
	var fore_l := Vector3(-0.3, -0.2, 0.9)
	var fore_r := Vector3(0.3, -0.2, 0.9)
	return {
		"Spine2": [[0.0, Vector3(0, 0, 0.12)], [0.2, Vector3(0, 0, 0.2)], [0.4, Vector3(0, 0, 0.12)], [0.6, Vector3(0, 0, 0.2)], [0.8, Vector3(0, 0, 0.12)]],
		"Head": [[0.0, Vector3(0, 0, 0.25)], [0.4, Vector3(0, 0, 0.35)], [0.8, Vector3(0, 0, 0.25)]],
		"LArm": [[0.0, belly_l], [0.8, belly_l]],
		"RArm": [[0.0, belly_r], [0.8, belly_r]],
		"LFore": [[0.0, fore_l], [0.8, fore_l]],
		"RFore": [[0.0, fore_r], [0.8, fore_r]],
	}


func _cheer() -> Dictionary:
	var a_l := Vector3(0.4, 1.0, 0.1)
	var b_l := Vector3(0.6, 0.9, 0.1)
	var a_r := Vector3(-0.4, 1.0, 0.1)
	var b_r := Vector3(-0.6, 0.9, 0.1)
	return {
		"LArm": [[0.0, a_l], [0.5, b_l], [1.0, a_l]],
		"RArm": [[0.0, b_r], [0.5, a_r], [1.0, b_r]],
		"LFore": [[0.0, a_l], [1.0, a_l]],
		"RFore": [[0.0, a_r], [1.0, a_r]],
		"Spine2": [[0.0, Vector3(0, 0, 0.1)], [1.0, Vector3(0, 0, 0.1)]],
	}


func _sit() -> Dictionary:
	return {
		"LUp": [[0.0, Vector3(0, 0, -1.4)], [0.6, Vector3(0, 0, -1.4)]],
		"RUp": [[0.0, Vector3(0, 0, -1.4)], [0.6, Vector3(0, 0, -1.4)]],
		"LLeg": [[0.0, Vector3(0, 0, 1.4)], [0.6, Vector3(0, 0, 1.4)]],
		"RLeg": [[0.0, Vector3(0, 0, 1.4)], [0.6, Vector3(0, 0, 1.4)]],
		"LArm": [[0.0, Vector3(0.2, -0.9, 0.3)], [0.6, Vector3(0.2, -0.9, 0.3)]],
		"RArm": [[0.0, Vector3(-0.2, -0.9, 0.3)], [0.6, Vector3(-0.2, -0.9, 0.3)]],
	}


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for bone: String in b:
		var combined: Array = (out.get(bone, []) as Array).duplicate()
		combined.append_array(b[bone])
		combined.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		out[bone] = combined
	return out


func _make(length: float, loop: bool, keys: Dictionary, hips_y: Array = [], methods: Array = []) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for short: String in BONES:
		var bone := _skeleton.find_bone(PREFIX + str(BONES[short]))
		if bone < 0:
			continue
		var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var directional := short in DIRECTION_BONES
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [_path, PREFIX + str(BONES[short])]))
		var fallback: Vector3 = STANCE_DIRECTIONS[short] if directional else Vector3.ZERO
		var frames: Array = keys.get(short, [[0.0, fallback]])
		for frame: Array in frames:
			var value := frame[1] as Vector3
			var rotation := _toward(bone, value) if directional else rest * Quaternion.from_euler(value)
			animation.rotation_track_insert_key(track, float(frame[0]), rotation)
	if not hips_y.is_empty():
		var hips := _skeleton.find_bone(PREFIX + "Hips")
		var origin := _skeleton.get_bone_rest(hips).origin
		var track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [_path, PREFIX + "Hips"]))
		for frame: Array in hips_y:
			animation.position_track_insert_key(track, float(frame[0]), origin + Vector3(0.0, float(frame[1]), 0.0))
	for call: Array in methods:
		var track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(track, NodePath(".."))
		animation.track_insert_key(track, float(call[0]), {"method": StringName(call[1]), "args": call[2]})
	return animation


## Local rotation that makes `bone` (pointing at its first child in the rest
## pose) point along `direction` in model space, with its parent at rest.
func _toward(bone: int, direction: Vector3) -> Quaternion:
	var rest_global := _skeleton.get_bone_global_rest(bone)
	var child := _skeleton.get_bone_children(bone)[0]
	var along := (_skeleton.get_bone_global_rest(child).origin - rest_global.origin).normalized()
	var turned := Basis(Quaternion(along, direction.normalized())) * rest_global.basis
	var parent := _skeleton.get_bone_parent(bone)
	var parent_basis := _skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	return (parent_basis.inverse() * turned).get_rotation_quaternion()
