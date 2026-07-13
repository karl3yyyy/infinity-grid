class_name PlayerUnit
extends "res://scripts/units/unit.gd"


func setup_player(display_name: String, coordinate: Vector2i) -> void:
	configure(display_name, 0, coordinate, Color("287cc1"), Color("9ee7ff"))
	max_hp = 13
	current_hp = max_hp
	attack_power = 6
	defense = 2
	movement_range = 4

