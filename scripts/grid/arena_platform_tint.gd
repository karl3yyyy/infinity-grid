class_name ArenaPlatformTint
extends RefCounted

## Re-colours the Tripo platform at runtime: one model serves both sides, the
## opponent's copy has its hue turned (cyan -> red). The bright neon edges also
## glow so the platform reads well in the dark hangar.

const SHADER_CODE := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D rm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float hue_shift = 0.0;
uniform float glow = 1.4;
uniform float darken = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float light_glow = 0.0;

vec3 hue_rotate(vec3 c, float turns) {
	float a = turns * 6.2831853;
	float s = sin(a);
	float k = cos(a);
	vec3 row0 = vec3(0.299 + 0.701 * k + 0.168 * s, 0.587 - 0.587 * k + 0.330 * s, 0.114 - 0.114 * k - 0.497 * s);
	vec3 row1 = vec3(0.299 - 0.299 * k - 0.328 * s, 0.587 + 0.413 * k + 0.035 * s, 0.114 - 0.114 * k + 0.292 * s);
	vec3 row2 = vec3(0.299 - 0.300 * k + 1.250 * s, 0.587 - 0.588 * k - 1.050 * s, 0.114 + 0.886 * k - 0.203 * s);
	return clamp(vec3(dot(row0, c), dot(row1, c), dot(row2, c)), 0.0, 1.0);
}

void fragment() {
	vec3 col = hue_rotate(texture(albedo_tex, UV).rgb, hue_shift);
	vec4 rm = texture(rm_tex, UV);
	ALBEDO = col * darken * tint;
	ROUGHNESS = rm.g;
	METALLIC = rm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	float spread = max(max(col.r, col.g), col.b) - min(min(col.r, col.g), col.b);
	float bright = smoothstep(0.93, 1.0, max(max(col.r, col.g), col.b)) * (1.0 - smoothstep(0.1, 0.25, spread));
	EMISSION = (col * smoothstep(0.35, 0.7, spread) * glow + tint * bright * light_glow) * darken;
}
"""

static var _shader: Shader


## Material for the platform mesh `source` (a StandardMaterial3D from the glTF).
static func make(source: BaseMaterial3D, hue_shift: float, darken: float = 1.0, tint: Color = Color.WHITE, light_glow: float = 0.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("albedo_tex", source.albedo_texture)
	material.set_shader_parameter("rm_tex", source.roughness_texture)
	material.set_shader_parameter("normal_tex", source.normal_texture)
	material.set_shader_parameter("hue_shift", hue_shift)
	material.set_shader_parameter("darken", darken)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("light_glow", light_glow)
	return material
