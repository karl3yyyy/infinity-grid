class_name HealAction
extends Node

signal heal_started(healer: BattleUnit, target: BattleUnit)
signal healing_applied(healer: BattleUnit, target: BattleUnit, amount: int)
signal heal_finished(healer: BattleUnit, target: BattleUnit)

const HealEffectScript := preload("res://scripts/effects/heal_effect.gd")

var busy: bool = false
var healing_applied_on_last_effect: bool = false


func can_heal(healer: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	if healer == null or target == null or grid == null or busy:
		return false
	var distance := grid.manhattan_distance(healer.grid_position, target.grid_position)
	return (
		healer.unit_class_id == UnitClassData.UnitClass.PRIEST
		and not healer.is_dead
		and not healer.has_attacked
		and not target.is_dead
		and healer.team_id == target.team_id
		and target.current_hp < target.max_hp
		and distance >= healer.heal_min_range
		and distance <= healer.heal_range
		and grid.has_line_of_sight(healer.grid_position, target.grid_position)
	)


func execute(healer: BattleUnit, target: BattleUnit, grid: GridManager) -> bool:
	if not can_heal(healer, target, grid):
		return false
	busy = true
	healing_applied_on_last_effect = false
	heal_started.emit(healer, target)
	healer.face_world_position(target.global_position)
	healer.play_heal()
	await get_tree().create_timer(0.16).timeout
	var effect: HealEffect = HealEffectScript.new()
	get_tree().current_scene.add_child(effect)
	var color := Color("9cecff") if healer.team_id == 0 else Color("a485ff")
	await effect.play(target.global_position, color)
	if is_instance_valid(target) and not target.is_dead:
		var restored := target.apply_healing(healer.heal_power)
		healing_applied_on_last_effect = true
		healing_applied.emit(healer, target, restored)
	healer.has_attacked = true
	healer.play_idle()
	busy = false
	heal_finished.emit(healer, target)
	return true
