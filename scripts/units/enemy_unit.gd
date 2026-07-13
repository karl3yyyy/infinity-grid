class_name EnemyUnit
extends "res://scripts/units/unit.gd"


func setup_enemy(display_name: String, coordinate: Vector2i) -> void:
	configure(display_name, 1, coordinate, Color("b53b49"), Color("ffbd78"))
	max_hp = 10
	current_hp = max_hp
	attack_power = 5
	defense = 1
	movement_range = 3

