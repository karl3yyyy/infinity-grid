class_name ArenaBridge
extends MeshInstance3D

## The neutral middle platform: one row of 5 cells that belongs to neither
## player. One Tripo model; its look (skin) is a colouring of that model. Every
## rank will get its own skin; until the models exist, a normal game picks one
## of these looks at random.

const MODEL_PATH := "res://assets/arena/middle_platform.glb"
## Measured: the model is 0.98 x 0.19 x 0.26 and its row of 5 tiles is 0.95 x 0.206, centred;
## scaled so that row covers the 7.0 x 1.4 cells of the middle row.
const MODEL_SCALE := Vector3(7.368, 6.5, 6.796)
const TOP_OFFSET: float = -1.28
## Darker copies on both sides, where the board wraps round.
const WRAP_WIDTH: float = 7.0
const WRAP_DARKEN: float = 0.45

## id, tint of the steel, strength of the tinted lights (white = unchanged).
const STYLES: Array[Dictionary] = [
	{"id": "normal", "name": "NORMAL", "tint": Color(1.0, 1.0, 1.0), "lights": 0.0},
	{"id": "bit_runner", "name": "BIT-RUNNER", "tint": Color(1.0, 0.78, 0.55), "lights": 1.0},
	{"id": "data_net_rogue", "name": "DATA-NET ROGUE", "tint": Color(0.6, 1.0, 0.65), "lights": 1.3},
	{"id": "system_cipher", "name": "SYSTEM CIPHER", "tint": Color(0.65, 0.85, 1.0), "lights": 1.3},
	{"id": "core_master", "name": "CORE MASTER", "tint": Color(0.88, 0.62, 1.0), "lights": 1.6},
	{"id": "root_sovereign", "name": "ROOT SOVEREIGN", "tint": Color(1.0, 0.86, 0.5), "lights": 1.6},
]

var style_id: String = "normal"


## `style`: id of one of STYLES, or "" for a random look.
func build(style: String = "") -> void:
	var chosen: Dictionary = STYLES.pick_random()
	if not style.is_empty():
		for entry: Dictionary in STYLES:
			if entry["id"] == style:
				chosen = entry
	style_id = str(chosen["id"])
	var source := load(MODEL_PATH) as PackedScene
	for side: int in [0, -1, 1]:
		var body := source.instantiate() as Node3D
		body.scale = MODEL_SCALE
		body.position = Vector3(float(side) * WRAP_WIDTH, TOP_OFFSET, 0.0)
		add_child(body)
		for mesh: Node in body.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			var material := instance.mesh.surface_get_material(0) as BaseMaterial3D
			if material != null:
				instance.material_override = ArenaPlatformTint.make(material, 0.0, 1.0 if side == 0 else WRAP_DARKEN, chosen["tint"] as Color, float(chosen["lights"]))
