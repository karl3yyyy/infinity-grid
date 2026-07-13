class_name EnemyUnit
extends "res://scripts/units/unit.gd"


func setup_enemy(
	display_name: String,
	coordinate: Vector2i,
	unit_class: int = UnitClassData.UnitClass.SWORDSMAN
) -> void:
	configure(display_name, 1, coordinate, Color("9b3f56"), Color("caa6ff"), unit_class)
