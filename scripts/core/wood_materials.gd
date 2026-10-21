class_name WoodMaterials
extends RefCounted

## Procedural wood: stretched noise gives long grain without shipping textures.

static var _cache: Dictionary = {}


## kind: "walnut" (dark), "maple" (light), "oak" (frame), "table" (old dark wood)
static func texture(kind: String) -> NoiseTexture2D:
	if _cache.has(kind):
		return _cache[kind]
	var palette: Dictionary = {
		"walnut": [Color("2e1a10"), Color("4a2c1a"), Color("5c3820")],
		"maple": [Color("6e4a2a"), Color("8f6640"), Color("a77c52")],
		"oak": [Color("5a3418"), Color("7e4c24"), Color("9a6230")],
		"table": [Color("1f120b"), Color("33200f"), Color("432a16")],
	}
	var colors: Array = palette.get(kind, palette["oak"])
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = kind.hash() & 0xffff
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 18.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.42, 0.55, 0.7, 1.0])
	ramp.colors = PackedColorArray([colors[0], colors[1], colors[2], colors[1], colors[0], colors[1]])
	var grain := NoiseTexture2D.new()
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	grain.noise = noise
	grain.color_ramp = ramp
	_cache[kind] = grain
	return grain


## A material whose grain runs along world X (or Z when along_z).
static func material(kind: String, along_z: bool = false, roughness: float = 0.55) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_texture = texture(kind)
	result.roughness = roughness
	result.metallic = 0.0
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	# Low frequency along the grain, high across it.
	result.uv1_scale = Vector3(1.4, 0.6, 0.12) if along_z else Vector3(0.12, 0.6, 1.4)
	result.uv1_triplanar_sharpness = 4.0
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result


static func brass(glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color("c8913c")
	result.metallic = 0.9
	result.roughness = 0.32
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = Color("8a5a1c")
		result.emission_energy_multiplier = glow
	return result
