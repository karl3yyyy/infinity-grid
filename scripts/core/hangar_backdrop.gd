class_name HangarBackdrop
extends Node3D

## The dark industrial hangar (one Tripo model) that encloses the board. Purely visual.

const MODEL_PATH := "res://assets/arena/hangar.glb"
const MODEL_SCALE: float = 36.0
## Measured: the hall's floor lies this far above the model's origin; the walls reach 0.73.
const MODEL_FLOOR_HEIGHT: float = 0.162
const MODEL_WALL_HEIGHT: float = 0.73
## Inner wall face as a fraction of the model's width, measured from its centre.
const INNER_WALL_HALF: float = 0.40
## Below the lowest fly-in start of the platforms, so none of them cuts through the floor.
const FLOOR_Y: float = -16.0
## Multiplied onto the model's texture: darker and greener than the raw Tripo blue.
const TINT := Color(0.42, 0.6, 0.5)


static func is_available() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


func build() -> void:
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	model.name = "Hangar"
	model.scale = Vector3.ONE * MODEL_SCALE
	model.position.y = FLOOR_Y - MODEL_FLOOR_HEIGHT * MODEL_SCALE
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var material := instance.mesh.surface_get_material(0) as BaseMaterial3D
		if material != null:
			var darkened := material.duplicate() as BaseMaterial3D
			darkened.albedo_color = TINT
			instance.material_override = darkened


func wall_half_width() -> float:
	return INNER_WALL_HALF * MODEL_SCALE


func wall_height() -> float:
	return (MODEL_WALL_HEIGHT - MODEL_FLOOR_HEIGHT) * MODEL_SCALE
