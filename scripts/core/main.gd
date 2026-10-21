extends Node3D

const GridManagerScript := preload("res://scripts/grid/grid_manager.gd")
const BattleManagerScript := preload("res://scripts/battle/onitama_battle_manager.gd")
const PlayerControllerScript := preload("res://scripts/controllers/player_controller.gd")
const UnitMovementScript := preload("res://scripts/units/unit_movement.gd")
const CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
const BattleUIScript := preload("res://scripts/ui/onitama_ui.gd")
const ArenaEnvironmentScript := preload("res://scripts/core/arena_environment.gd")


func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.addEventListener('contextmenu', function(event) { event.preventDefault(); });")
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

	var battle_ui: OnitamaUI = BattleUIScript.new()
	battle_ui.name = "BattleUI"
	add_child(battle_ui)

	var unit_movement: UnitMovement = UnitMovementScript.new()
	unit_movement.name = "UnitMovement"
	add_child(unit_movement)
	var player_controller: PlayerController = PlayerControllerScript.new()
	player_controller.name = "PlayerController"
	add_child(player_controller)
	player_controller.setup(camera_controller, grid_manager)
	var battle_manager: OnitamaBattleManager = BattleManagerScript.new()
	battle_manager.name = "BattleManager"
	add_child(battle_manager)
	battle_manager.setup(
		grid_manager,
		camera_controller,
		battle_ui,
		player_controller,
		unit_movement,
		units
	)


func _build_environment() -> void:
	var arena: ArenaEnvironment = ArenaEnvironmentScript.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()
