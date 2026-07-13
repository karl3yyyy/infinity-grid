class_name AttackAction
extends Node

signal attack_started(attacker: BattleUnit, target: BattleUnit)
signal damage_applied(attacker: BattleUnit, target: BattleUnit, damage: int)
signal attack_finished(attacker: BattleUnit, target: BattleUnit)

const DamageNumberScene := preload("res://scripts/effects/damage_number.gd")
const HitEffectScene := preload("res://scripts/effects/hit_effect.gd")

var busy: bool = false
var camera_controller: CameraController = null
var slash_audio: AudioStreamPlayer3D
var hit_audio: AudioStreamPlayer3D


func _ready() -> void:
	slash_audio = AudioStreamPlayer3D.new()
	slash_audio.name = "SlashAudio"
	add_child(slash_audio)
	hit_audio = AudioStreamPlayer3D.new()
	hit_audio.name = "HitAudio"
	add_child(hit_audio)


func can_attack(attacker: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	return (
		attacker != null
		and target != null
		and not busy
		and not attacker.is_dead
		and not attacker.has_attacked
		and not target.is_dead
		and attacker.team_id != target.team_id
		and attacker.unit_class_id == UnitClassData.UnitClass.SWORDSMAN
		and grid.manhattan_distance(attacker.grid_position, target.grid_position) >= attacker.attack_min_range
		and grid.manhattan_distance(attacker.grid_position, target.grid_position) <= attacker.attack_range
	)


func calculate_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	return maxi(1, attacker.attack_power - target.defense)


func execute(attacker: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	if not can_attack(attacker, target, grid):
		return false
	busy = true
	attack_started.emit(attacker, target)
	attacker.face_world_position(target.global_position)
	attacker.play_melee_attack()

	var windup := attacker.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup.set_parallel(true)
	windup.tween_property(attacker.sword_arm_pivot, "rotation_degrees:z", 72.0, 0.23)
	windup.tween_property(attacker.sword_arm_pivot, "rotation_degrees:x", -38.0, 0.23)
	windup.tween_property(attacker.torso_pivot, "rotation_degrees:y", -32.0, 0.23)
	windup.tween_property(attacker.visual_root, "position:y", -0.08, 0.23)
	await windup.finished
	if slash_audio.stream != null:
		slash_audio.global_position = attacker.global_position
		slash_audio.play()

	var slash := attacker.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	slash.set_parallel(true)
	slash.tween_property(attacker.sword_arm_pivot, "rotation_degrees:z", -132.0, 0.13)
	slash.tween_property(attacker.sword_arm_pivot, "rotation_degrees:x", 35.0, 0.13)
	slash.tween_property(attacker.torso_pivot, "rotation_degrees:y", 38.0, 0.13)
	await slash.finished

	# This is the single animation hit event. Damage is never applied on button press.
	var damage := calculate_damage(attacker, target)
	target.apply_damage(damage)
	damage_applied.emit(attacker, target, damage)
	_spawn_hit_feedback(target, damage)
	if camera_controller != null:
		camera_controller.shake(0.11, 0.13)
	if hit_audio.stream != null:
		hit_audio.global_position = target.global_position
		hit_audio.play()
	Engine.time_scale = 0.16
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	await target.play_hit_reaction(attacker.global_position)

	var recover := attacker.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recover.set_parallel(true)
	recover.tween_property(attacker.sword_arm_pivot, "rotation", Vector3.ZERO, 0.28)
	recover.tween_property(attacker.torso_pivot, "rotation", Vector3.ZERO, 0.28)
	recover.tween_property(attacker.visual_root, "position", Vector3.ZERO, 0.28)
	await recover.finished
	attacker.has_attacked = true
	attacker.play_idle()
	busy = false
	attack_finished.emit(attacker, target)
	return true


func _spawn_hit_feedback(target: BattleUnit, damage: int) -> void:
	var damage_number := DamageNumberScene.new()
	get_tree().current_scene.add_child(damage_number)
	damage_number.show_damage(damage, target.global_position)
	var hit_effect := HitEffectScene.new()
	get_tree().current_scene.add_child(hit_effect)
	hit_effect.play(target.global_position)
