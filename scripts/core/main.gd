extends Node3D

const GridManagerScript := preload("res://scripts/grid/grid_manager.gd")
const TurnManagerScript := preload("res://scripts/battle/turn_manager.gd")
const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")
const PlayerControllerScript := preload("res://scripts/controllers/player_controller.gd")
const EnemyControllerScript := preload("res://scripts/controllers/enemy_controller.gd")
const UnitMovementScript := preload("res://scripts/units/unit_movement.gd")
const AttackActionScript := preload("res://scripts/battle/attack_action.gd")
const RangedAttackActionScript := preload("res://scripts/battle/ranged_attack_action.gd")
const HealActionScript := preload("res://scripts/battle/heal_action.gd")
const CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
const BattleUIScript := preload("res://scripts/ui/battle_ui.gd")


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
	var ranged_attack_action: RangedAttackAction = RangedAttackActionScript.new()
	ranged_attack_action.name = "RangedAttackAction"
	ranged_attack_action.camera_controller = camera_controller
	add_child(ranged_attack_action)
	var heal_action: HealAction = HealActionScript.new()
	heal_action.name = "HealAction"
	add_child(heal_action)
	var player_controller: PlayerController = PlayerControllerScript.new()
	player_controller.name = "PlayerController"
	add_child(player_controller)
	player_controller.setup(camera_controller, grid_manager)
	var enemy_controller: EnemyController = EnemyControllerScript.new()
	enemy_controller.name = "EnemyController"
	add_child(enemy_controller)
	enemy_controller.setup(
		grid_manager,
		unit_movement,
		attack_action,
		ranged_attack_action,
		heal_action,
		camera_controller
	)
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
		ranged_attack_action,
		heal_action,
		units
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky_texture := load("res://assets/sky/cloud_layers_2k.hdr") as Texture2D
	if sky_texture != null:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = sky_texture
		panorama.energy_multiplier = 0.72
		var sky := Sky.new()
		sky.sky_material = panorama
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
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
	_build_licensed_environment()


func _build_licensed_environment() -> void:
	var environment_assets := Node3D.new()
	environment_assets.name = "LicensedEnvironmentAssets"
	add_child(environment_assets)
	var placements: Array[Dictionary] = []
	for x: int in range(-6, 7, 2):
		placements.append({"path": "res://assets/environment/dungeon_wall.glb", "position": Vector3(float(x), 0.0, -7.25), "rotation": 0.0, "scale": 1.0})
	for z: int in range(-4, 7, 3):
		placements.append({"path": "res://assets/environment/dungeon_pillar.glb", "position": Vector3(-7.35, 0.0, float(z)), "rotation": 90.0, "scale": 1.0})
	placements.append({"path": "res://assets/environment/dungeon_crate.glb", "position": Vector3(7.1, 0.0, -5.8), "rotation": 22.0, "scale": 1.15})
	placements.append({"path": "res://assets/environment/dungeon_crate.glb", "position": Vector3(7.5, 0.0, -5.3), "rotation": -16.0, "scale": 0.85})
	placements.append({"path": "res://assets/environment/nature_tree.glb", "position": Vector3(7.55, 0.0, 5.8), "rotation": -18.0, "scale": 1.8})
	placements.append({"path": "res://assets/environment/nature_tree.glb", "position": Vector3(-7.65, 0.0, 6.3), "rotation": 26.0, "scale": 1.45})
	placements.append({"path": "res://assets/environment/nature_rock.glb", "position": Vector3(7.45, 0.0, 2.5), "rotation": 38.0, "scale": 1.1})
	placements.append({"path": "res://assets/environment/nature_bush.glb", "position": Vector3(6.9, 0.0, 4.6), "rotation": -12.0, "scale": 1.3})
	for placement: Dictionary in placements:
		var resource_path: String = placement["path"]
		if not ResourceLoader.exists(resource_path):
			continue
		var packed := load(resource_path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			continue
		instance.position = placement["position"]
		instance.rotation_degrees.y = float(placement["rotation"])
		instance.scale = Vector3.ONE * float(placement["scale"])
		environment_assets.add_child(instance)
