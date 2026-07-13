class_name UnitClassData
extends Resource

enum UnitClass {
	SWORDSMAN,
	ARCHER,
	PRIEST,
}

enum ActionKind {
	MELEE,
	RANGED,
	HOLY_BOLT,
}

var class_id: UnitClass = UnitClass.SWORDSMAN
var display_name: String = "Swordsman"
var max_hp: int = 14
var attack_power: int = 6
var defense: int = 2
var movement_range: int = 4
var attack_min_range: int = 1
var attack_max_range: int = 1
var heal_min_range: int = 0
var heal_max_range: int = 0
var heal_power: int = 0
var action_kind: ActionKind = ActionKind.MELEE


static func create(unit_class: UnitClass) -> UnitClassData:
	var data := UnitClassData.new()
	data.class_id = unit_class
	match unit_class:
		UnitClass.ARCHER:
			data.display_name = "Archer"
			data.max_hp = 10
			data.attack_power = 5
			data.defense = 1
			data.movement_range = 4
			data.attack_min_range = 2
			data.attack_max_range = 5
			data.action_kind = ActionKind.RANGED
		UnitClass.PRIEST:
			data.display_name = "Priest"
			data.max_hp = 9
			data.attack_power = 3
			data.defense = 1
			data.movement_range = 3
			data.attack_min_range = 2
			data.attack_max_range = 4
			data.heal_min_range = 1
			data.heal_max_range = 4
			data.heal_power = 6
			data.action_kind = ActionKind.HOLY_BOLT
		_:
			pass
	return data


static func class_name_for(unit_class: UnitClass) -> String:
	return create(unit_class).display_name

