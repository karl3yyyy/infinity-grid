class_name ArenaHalf
extends Node3D

## One player's platform: 5 x 2 cells on a floating steel deck (the board skin).
## Purely visual; the invisible cell markers lie on its floor. One Tripo model
## serves both sides; the opponent's copy is turned from cyan to red.

const MODEL_PATH := "res://assets/arena/player_platform.glb"
## Colour of the cell markers' frames (hover etc.).
const GLOW := Color("d6ffe0")
## Measured: the model is 0.98 x 0.17 x 0.39 and its 5 x 2 tile field is 0.822 x 0.318, centred;
## scaled so that field covers the 7.0 x 2.8 cells of one side.
const MODEL_SCALE := Vector3(8.516, 8.6, 8.805)
## Lifts the model so its tile floor lies just below the cell markers.
const FLOOR_OFFSET: float = -0.8
const FLY_IN_HEIGHT: float = 14.0
## Distance between the platform and its wrap-round copies (5 cells), and how dark they are.
const WRAP_WIDTH: float = 7.0
const WRAP_DARKEN: float = 0.45
## Hue turn of the opponent's copy (cyan -> red).
const OPPONENT_HUE: float = 0.5

var _model: Node3D
var _team: int = 0


## team 0 sits at the high rows (towards the camera), team 1 mirrors it.
func place(team: int, grid_depth: float) -> void:
	_team = team
	position = Vector3(0.0, 0.0, grid_depth * 0.3 * (1.0 if team == 0 else -1.0))
	rotation.y = 0.0 if team == 0 else PI


## The platform itself plus a darker copy on each side, where the board wraps
## round: figures there stand on the same floor.
func show_skin(_skin_id: String) -> void:
	if _model != null:
		return
	_model = Node3D.new()
	_model.position = Vector3(0.0, FLOOR_OFFSET, 0.0)
	add_child(_model)
	var source := load(MODEL_PATH) as PackedScene
	for side: int in [0, -1, 1]:
		var copy := source.instantiate() as Node3D
		copy.scale = MODEL_SCALE
		copy.position = Vector3(float(side) * WRAP_WIDTH, 0.0, 0.0)
		_model.add_child(copy)
		for mesh: Node in copy.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			var material := instance.mesh.surface_get_material(0) as BaseMaterial3D
			if material != null:
				instance.material_override = ArenaPlatformTint.make(material, OPPONENT_HUE if _team == 1 else 0.0, 1.0 if side == 0 else WRAP_DARKEN)


## Match start: the half flies in from below (own side) or above (the opponent's).
func fly_in(from_below: bool, seconds: float) -> Tween:
	var landed := Vector3(0.0, FLOOR_OFFSET, 0.0)
	_model.position = landed + Vector3(0.0, -FLY_IN_HEIGHT if from_below else FLY_IN_HEIGHT, 0.0)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "position", landed, seconds)
	return tween
