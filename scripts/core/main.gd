extends Node3D

const GridManagerScript := preload("res://scripts/grid/grid_manager.gd")
const TurnManagerScript := preload("res://scripts/battle/turn_manager.gd")
const BattleManagerScript := preload("res://scripts/battle/onitama_battle_manager.gd")
const PlayerControllerScript := preload("res://scripts/controllers/player_controller.gd")
const UnitMovementScript := preload("res://scripts/units/unit_movement.gd")
const CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
const BattleUIScript := preload("res://scripts/ui/onitama_ui.gd")


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

	var turn_manager: TurnManager = TurnManagerScript.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
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
		turn_manager,
		battle_ui,
		player_controller,
		unit_movement,
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
	base_mesh.size = Vector3(11.2, 0.55, 11.2)
	base.mesh = base_mesh
	base.position.y = -0.39
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color("486b38")
	base_material.roughness = 0.94
	base.material_override = base_material
	add_child(base)
	var meadow := MeshInstance3D.new()
	meadow.name = "MeadowGround"
	var meadow_mesh := PlaneMesh.new()
	meadow_mesh.size = Vector2(80.0, 80.0)
	meadow.mesh = meadow_mesh
	meadow.position.y = -0.72
	var meadow_material := StandardMaterial3D.new()
	meadow_material.albedo_color = Color("66834a")
	meadow_material.roughness = 1.0
	meadow.material_override = meadow_material
	add_child(meadow)
	_build_licensed_environment()


func _build_licensed_environment() -> void:
	var environment_assets := Node3D.new()
	environment_assets.name = "LicensedEnvironmentAssets"
	add_child(environment_assets)
	var placements: Array[Dictionary] = [
		{"path": "res://assets/environment/nature_tree.glb", "position": Vector3(-5.0, 0.0, -4.4), "rotation": -18.0, "scale": 1.25},
		{"path": "res://assets/environment/nature_tree.glb", "position": Vector3(5.0, 0.0, 4.4), "rotation": 26.0, "scale": 1.2},
		{"path": "res://assets/environment/nature_bush.glb", "position": Vector3(4.3, 0.0, -4.5), "rotation": -12.0, "scale": 0.85},
		{"path": "res://assets/environment/nature_bush.glb", "position": Vector3(-4.3, 0.0, 4.5), "rotation": 18.0, "scale": 0.9},
		{"path": "res://assets/environment/nature_rock.glb", "position": Vector3(5.0, 0.0, -4.5), "rotation": 38.0, "scale": 0.8},
		{"path": "res://assets/environment/nature_rock.glb", "position": Vector3(-5.0, 0.0, 4.5), "rotation": -24.0, "scale": 0.75},
	]
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
