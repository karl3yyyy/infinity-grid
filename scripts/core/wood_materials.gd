class_name WoodMaterials
extends RefCounted

## Materials built from the generated textures in assets/textures
## (see tools/generate_textures.py): weathered wood, carved board squares,
## hammered iron and polished stone for the figurines.

const TEXTURE_DIR := "res://assets/textures/"

static var _textures: Dictionary = {}


static func tex(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path := TEXTURE_DIR + file_name
		_textures[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file_name]


## Tiling surface (table, frame, iron, marble, obsidian) projected in world space.
## `scale` is texture repetitions per metre; wood grain follows world X.
static func surface(kind: String, scale: float = 0.25, roughness: float = 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = tex(kind + "_albedo.jpg")
	material.normal_enabled = tex(kind + "_normal.jpg") != null
	material.normal_texture = tex(kind + "_normal.jpg")
	material.normal_scale = 0.8
	material.roughness = roughness
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 6.0
	material.uv1_scale = Vector3(scale, scale, scale)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## One carved board square (light or dark wood, optionally with a rune ring).
static func tile(light: bool, rune: bool) -> StandardMaterial3D:
	var base := ("tile_light" if light else "tile_dark") + ("_rune" if rune else "")
	var material := StandardMaterial3D.new()
	material.albedo_texture = tex(base + "_albedo.jpg")
	material.normal_enabled = true
	material.normal_texture = tex(base + "_normal.jpg")
	material.normal_scale = 1.0
	material.roughness = 0.55
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func iron(scale: float = 1.2) -> StandardMaterial3D:
	var material := surface("iron", scale, 0.55)
	material.metallic = 0.85
	material.roughness_texture = tex("iron_roughness.jpg")
	return material


static func brass(glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color("b3843a")
	result.metallic = 0.9
	result.roughness = 0.38
	result.normal_enabled = true
	result.normal_texture = tex("iron_normal.jpg")
	result.uv1_triplanar = true
	result.uv1_scale = Vector3(2.0, 2.0, 2.0)
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = Color("8a5a1c")
		result.emission_energy_multiplier = glow
	return result
