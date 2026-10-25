class_name ArenaHalf
extends Node3D

## One player's platform: 5 x 2 cells on a floating steel deck (the board skin).
## Purely visual; the invisible cell markers lie on its floor. One Tripo model
## serves both sides; the opponent's copy has its hue turned to red ("opponent_hue", turns).

## Colour of the cell markers' frames (hover etc.).
const GLOW := Color("d6ffe0")
## One model per board skin. "scale" makes the model's 5 x 2 field cover the 7.0 x 2.8
## cells of one side; "offset" lifts it so its tile floor lies just below the cell markers.
## standard: model 0.98 x 0.17 x 0.39, field 0.822 x 0.318 (measured, centred).
## chip: model 0.977 x 0.077 x 0.451, field 0.814 x 0.30, pads 0.07 high (measured, centred).
const MODELS: Dictionary = {
	"standard": {"path": "res://assets/arena/player_platform.glb", "scale": Vector3(8.516, 8.6, 8.805), "offset": -0.8, "opponent_hue": 0.5},
	"chip": {"path": "res://assets/arena/chip_platform.glb", "scale": Vector3(8.6, 8.6, 9.33), "offset": -0.62, "opponent_hue": 0.4},
}
const FLY_IN_HEIGHT: float = 14.0
## Height of the KERN's crown above the cell plane (the cell frames lie at 0.06).
const TEMPLE_MARKER_HEIGHT: float = 0.04
## Distance between the platform and its wrap-round copies (5 cells), and how dark they are.
const WRAP_WIDTH: float = 7.0
const WRAP_DARKEN: float = 0.45

var _model: Node3D
var _team: int = 0
var _skin_id: String = ""
var _floor_offset: float = 0.0
var _temple_visible: bool = true


## team 0 sits at the high rows (towards the camera), team 1 mirrors it.
func place(team: int, grid_depth: float) -> void:
	_team = team
	position = Vector3(0.0, 0.0, grid_depth * 0.3 * (1.0 if team == 0 else -1.0))
	rotation.y = 0.0 if team == 0 else PI


## The platform itself plus a darker copy on each side, where the board wraps
## round: figures there stand on the same floor.
## The crown on the KERN's start square gives nothing away only while it is hidden (hidden-king chaos).
func set_temple_visible(value: bool) -> void:
	_temple_visible = value
	var marker := _model.get_node_or_null("TempleMarker") as Node3D if _model != null else null
	if marker != null:
		marker.visible = value


func show_skin(skin_id: String, with_wrap_copies: bool = true) -> void:
	var key := skin_id if MODELS.has(skin_id) else "standard"
	if _model != null:
		if key == _skin_id:
			return
		remove_child(_model)
		_model.queue_free()
	var config: Dictionary = MODELS[key]
	_skin_id = key
	_floor_offset = float(config["offset"])
	_model = Node3D.new()
	_model.position = Vector3(0.0, _floor_offset, 0.0)
	add_child(_model)
	var marker := TempleMarker.make(_team, -_floor_offset + TEMPLE_MARKER_HEIGHT)
	marker.name = "TempleMarker"
	marker.visible = _temple_visible
	_model.add_child(marker)
	var source := load(str(config["path"])) as PackedScene
	var sides: Array[int] = [0]
	if with_wrap_copies:
		sides.append_array([-1, 1])
	for side: int in sides:
		var copy := source.instantiate() as Node3D
		copy.scale = config["scale"]
		copy.position = Vector3(float(side) * WRAP_WIDTH, 0.0, 0.0)
		_model.add_child(copy)
		for mesh: Node in copy.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			var material := instance.mesh.surface_get_material(0) as BaseMaterial3D
			if material != null:
				instance.material_override = ArenaPlatformTint.make(material, float(config["opponent_hue"]) if _team == 1 else 0.0, 1.0 if side == 0 else WRAP_DARKEN)


## Match start: the half flies in from below (own side) or above (the opponent's).
func fly_in(from_below: bool, seconds: float) -> Tween:
	var landed := Vector3(0.0, _floor_offset, 0.0)
	_model.position = landed + Vector3(0.0, -FLY_IN_HEIGHT if from_below else FLY_IN_HEIGHT, 0.0)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "position", landed, seconds)
	return tween
