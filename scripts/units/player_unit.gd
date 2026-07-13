class_name PlayerUnit
extends "res://scripts/units/unit.gd"


func setup_player(
	display_name: String,
	coordinate: Vector2i,
	unit_class: int = UnitClassData.UnitClass.SWORDSMAN
) -> void:
	configure(display_name, 0, coordinate, Color("287cc1"), Color("9ee7ff"), unit_class)
