class_name RangedAttackAction
extends Node

signal attack_started(attacker: BattleUnit, target: BattleUnit)
signal damage_applied(attacker: BattleUnit, target: BattleUnit, damage: int)
signal attack_finished(attacker: BattleUnit, target: BattleUnit)

const ProjectileEffectScript := preload("res://scripts/effects/projectile_effect.gd")
const DamageNumberScript := preload("res://scripts/effects/damage_number.gd")
const HitEffectScript := preload("res://scripts/effects/hit_effect.gd")

var busy: bool = false
var damage_applied_on_last_impact: bool = false
var camera_controller: CameraController


func can_attack(attacker: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	if attacker == null or target == null or grid == null or busy:
		return false
	var distance := grid.manhattan_distance(attacker.grid_position, target.grid_position)
	return (
		not attacker.is_dead
		and not attacker.has_attacked
		and not target.is_dead
		and attacker.team_id != target.team_id
		and distance >= attacker.attack_min_range
		and distance <= attacker.attack_range
		and grid.has_line_of_sight(attacker.grid_position, target.grid_position)
	)


func calculate_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	return maxi(1, attacker.attack_power - target.defense)


func execute(attacker: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	if not can_attack(attacker, target, grid):
		return false
	busy = true
	damage_applied_on_last_impact = false
	attack_started.emit(attacker, target)
	attacker.face_world_position(target.global_position)
	if attacker.unit_class_id == UnitClassData.UnitClass.ARCHER:
		attacker.play_ranged_attack()
	else:
		attacker.play_cast()
	await get_tree().create_timer(0.18).timeout
	var projectile: ProjectileEffect = ProjectileEffectScript.new()
	get_tree().current_scene.add_child(projectile)
	var is_arrow := attacker.unit_class_id == UnitClassData.UnitClass.ARCHER
	var color := Color("e9d7a2") if is_arrow else (Color("84d9ff") if attacker.team_id == 0 else Color("9e6bff"))
	projectile.setup(color, is_arrow)
	var origin := attacker.global_position + Vector3(0.0, 1.25, 0.0)
	var impact := target.global_position + Vector3(0.0, 1.0, 0.0)
	await projectile.fly(origin, impact)
	if is_instance_valid(target) and not target.is_dead:
		var damage := calculate_damage(attacker, target)
		target.apply_damage(damage)
		damage_applied_on_last_impact = true
		damage_applied.emit(attacker, target, damage)
		_spawn_hit_feedback(target, damage)
		if camera_controller != null:
			camera_controller.shake(0.07, 0.1)
		await target.play_hit_reaction(attacker.global_position)
	projectile.queue_free()
	attacker.has_attacked = true
	attacker.play_idle()
	busy = false
	attack_finished.emit(attacker, target)
	return true


func _spawn_hit_feedback(target: BattleUnit, damage: int) -> void:
	var damage_number := DamageNumberScript.new()
	get_tree().current_scene.add_child(damage_number)
	damage_number.show_damage(damage, target.global_position)
	var hit_effect := HitEffectScript.new()
	get_tree().current_scene.add_child(hit_effect)
	hit_effect.play(target.global_position)
