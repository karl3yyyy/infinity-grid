extends Node3D

const GridManagerScript := preload("res://scripts/grid/grid_manager.gd")
const BattleManagerScript := preload("res://scripts/battle/grid_battle_manager.gd")
const PlayerControllerScript := preload("res://scripts/controllers/player_controller.gd")
const UnitMovementScript := preload("res://scripts/units/unit_movement.gd")
const CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
const BattleUIScript := preload("res://scripts/ui/grid_battle_ui.gd")
const CyberEnvironmentScript := preload("res://scripts/core/cyber_environment.gd")


func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.addEventListener('contextmenu', function(event) { event.preventDefault(); });")
		# The installed web app keeps serving its cached version until every tab
		# is closed; switch to a newly published one as soon as it is there.
		JavaScriptBridge.pwa_update_available.connect(_apply_web_update)
		if JavaScriptBridge.pwa_needs_update():
			_apply_web_update.call_deferred()
		# Browsers only look for a new version now and then; ask right away and
		# every few minutes so a published update shows up quickly.
		_check_for_web_update()
		var timer := Timer.new()
		timer.wait_time = 180.0
		timer.autostart = true
		timer.timeout.connect(_check_for_web_update)
		add_child(timer)
	var sound := SoundBoard.new()
	sound.name = "SoundBoard"
	add_child(sound)
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

	var battle_ui: GridBattleUI = BattleUIScript.new()
	battle_ui.name = "BattleUI"
	add_child(battle_ui)

	var card_stage := CardStage.new()
	card_stage.name = "CardStage"
	camera_controller.add_child(card_stage)
	battle_ui.attach_card_stage(card_stage)

	var unit_movement: UnitMovement = UnitMovementScript.new()
	unit_movement.name = "UnitMovement"
	add_child(unit_movement)
	var player_controller: PlayerController = PlayerControllerScript.new()
	player_controller.name = "PlayerController"
	add_child(player_controller)
	player_controller.setup(camera_controller, grid_manager)
	player_controller.pointer_blocker = card_stage.is_over_card
	var battle_manager: GridBattleManager = BattleManagerScript.new()
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
	battle_ui.ffa_requested.connect(func(humans: int, shifting_tiles: bool) -> void: _open_ffa(battle_ui, humans, shifting_tiles))


## The four-player mode is a flat 2D screen above everything; closing it
## returns to the main menu.
func _open_ffa(battle_ui: GridBattleUI, humans: int, shifting_tiles: bool) -> void:
	var layer := CanvasLayer.new()
	layer.name = "FfaLayer"
	layer.layer = 80
	add_child(layer)
	var screen := FfaScreen.new()
	layer.add_child(screen)
	screen.closed.connect(func() -> void:
		layer.queue_free()
		battle_ui.main_menu.open_menu(false))
	screen.start(humans, shifting_tiles)


func _check_for_web_update() -> void:
	JavaScriptBridge.eval("if ('serviceWorker' in navigator) { navigator.serviceWorker.getRegistration().then(function (r) { if (r) { r.update(); } }); }")


## Reloads into the new version, but never in the middle of a match.
func _apply_web_update() -> void:
	var battle := get_node_or_null("BattleManager") as GridBattleManager
	# The board is only shown once a match was started from the menu.
	var in_match: bool = battle != null and battle.grid_manager.get_parent().visible and not battle.battle_over
	if in_match:
		# Try again once the match is over and the result screen is shown.
		get_tree().create_timer(30.0).timeout.connect(_apply_web_update)
		return
	JavaScriptBridge.pwa_update()


func _build_environment() -> void:
	var arena: CyberEnvironment = CyberEnvironmentScript.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()
