extends Node3D

const GridManagerScript := preload("res://scripts/grid/grid_manager.gd")
const TurnManagerScript := preload("res://scripts/battle/turn_manager.gd")
const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")
const PlayerControllerScript := preload("res://scripts/controllers/player_controller.gd")
const EnemyControllerScript := preload("res://scripts/controllers/enemy_controller.gd")
const UnitMovementScript := preload("res://scripts/units/unit_movement.gd")
const AttackActionScript := preload("res://scripts/battle/attack_action.gd")
const CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
const BattleUIScript := preload("res://scripts/ui/battle_ui.gd")


func _ready() -> void:
	_build_environment()
	var battle_scene := Node3D.new()
	battle_scene.name = "BattleScene"
	add_child(battle_scene)

	var grid_manager: GridManager = GridManagerScript.new()
	grid_manager.name = "GridManager"
	battle_scene.add_child(grid_manager)
	grid_manager.setup()

	var units := Node3D.new()
	units.name = "Units"
	battle_scene.add_child(units)

	var camera_controller: CameraController = CameraControllerScript.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)

	var battle_ui: BattleUI = BattleUIScript.new()
	battle_ui.name = "BattleUI"
	add_child(battle_ui)

	var turn_manager: TurnManager = TurnManagerScript.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	var unit_movement: UnitMovement = UnitMovementScript.new()
	unit_movement.name = "UnitMovement"
	add_child(unit_movement)
	var attack_action: AttackAction = AttackActionScript.new()
	attack_action.name = "AttackAction"
	attack_action.camera_controller = camera_controller
	add_child(attack_action)
	var player_controller: PlayerController = PlayerControllerScript.new()
	player_controller.name = "PlayerController"
	add_child(player_controller)
	player_controller.setup(camera_controller, grid_manager)
	var enemy_controller: EnemyController = EnemyControllerScript.new()
	enemy_controller.name = "EnemyController"
	add_child(enemy_controller)
	enemy_controller.setup(grid_manager, unit_movement, attack_action, camera_controller)
	var battle_manager: BattleManager = BattleManagerScript.new()
	battle_manager.name = "BattleManager"
	add_child(battle_manager)
	battle_manager.setup(
		grid_manager,
		turn_manager,
		battle_ui,
		camera_controller,
		player_controller,
		enemy_controller,
		unit_movement,
		attack_action,
		units
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101c2c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fc4dd")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color("79b8ff")
	fill.light_energy = 0.34
	add_child(fill)

	var base := MeshInstance3D.new()
	base.name = "BattlefieldBase"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(16.0, 0.55, 16.0)
	base.mesh = base_mesh
	base.position.y = -0.39
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color("172730")
	base_material.roughness = 0.94
	base.material_override = base_material
	add_child(base)

