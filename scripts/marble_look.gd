extends RefCounted
## Aspetto delle biglie: una sfera con uno shader che disegna motivo e materiale.
## La configurazione e' un dizionario: { material, pattern, color_a, color_b }.

const RADIUS := 0.5

const PATTERN_INDEX := {"spirale": 0, "strisce": 1, "tinta": 2, "pois": 3, "onde": 4, "scacchi": 5, "occhio": 6, "stelle": 7}

# [ruvidita', metallo, riflesso, luce propria, bordo luminoso, effetto, tinta, forza tinta]
const MATERIAL_PARAMS := {
	"vetro": [0.08, 0.0, 0.9, 0.10, 0.22, 0, Color(1, 1, 1), 0.0],
	"gomma": [0.85, 0.0, 0.2, 0.0, 0.0, 0, Color(1, 1, 1), 0.0],
	"metallo": [0.32, 0.9, 0.6, 0.0, 0.05, 0, Color(1, 1, 1), 0.0],
	"perla": [0.22, 0.3, 1.0, 0.14, 0.55, 0, Color(1.0, 0.96, 0.98), 0.55],
	"cromo": [0.05, 1.0, 1.0, 0.0, 0.10, 0, Color(0.92, 0.94, 0.97), 0.7],
	"oro": [0.2, 1.0, 1.0, 0.03, 0.10, 0, Color(1.0, 0.76, 0.22), 0.78],
	"galassia": [0.25, 0.2, 0.8, 0.05, 0.35, 1, Color(1, 1, 1), 0.0],
	"lava": [0.7, 0.0, 0.3, 0.0, 0.0, 2, Color(1, 1, 1), 0.0],
}

const SHADER_CODE := """
shader_type spatial;
uniform vec3 color_a : source_color = vec3(0.9, 0.2, 0.2);
uniform vec3 color_b : source_color = vec3(1.0, 1.0, 1.0);
uniform int pattern = 0;
uniform int effect = 0;
uniform float rough = 0.08;
uniform float metal = 0.0;
uniform float spec = 0.9;
uniform float glow = 0.1;
uniform float rim_amount = 0.22;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float tint_mix = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pattern_mask(vec2 uv) {
	if (pattern == 1) {
		return step(0.5, fract(uv.y * 6.0));
	}
	if (pattern == 2) {
		return 0.0;
	}
	if (pattern == 3) {
		vec2 g = fract(uv * vec2(12.0, 6.0)) - 0.5;
		return 1.0 - smoothstep(0.26, 0.31, length(g));
	}
	if (pattern == 4) {
		return smoothstep(-0.2, 0.2, sin(uv.y * 26.0 + sin(uv.x * 31.4) * 1.4));
	}
	if (pattern == 5) {
		return mod(floor(uv.x * 12.0) + floor(uv.y * 6.0), 2.0);
	}
	if (pattern == 6) {
		float d = abs(fract(uv.x * 2.0 + sin(uv.y * 3.1416) * 0.15) - 0.5);
		return 1.0 - smoothstep(0.05, 0.11, d);
	}
	if (pattern == 7) {
		vec2 g = fract(uv * vec2(8.0, 4.0)) - 0.5;
		float a = atan(g.y, g.x);
		return 1.0 - smoothstep(0.0, 0.03, length(g) - (0.2 + 0.11 * cos(a * 5.0)));
	}
	float swirl = sin(uv.x * 18.85 + sin(uv.y * 3.1416) * 2.5 + uv.y * 4.0);
	return smoothstep(-0.2, 0.2, swirl) * 0.85;
}

void fragment() {
	float m = pattern_mask(UV);
	vec3 base = mix(color_a, color_b, m);
	base = mix(base, tint * (0.62 + 0.38 * m), tint_mix);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 emi = base * glow + vec3(rim) * rim_amount;
	if (effect == 1) {
		float h = hash(floor(UV * vec2(90.0, 45.0)));
		float twinkle = step(0.965, h) * (0.5 + 0.5 * sin(TIME * 3.0 + h * 40.0));
		base = base * (0.25 + 0.35 * m);
		emi += vec3(twinkle) * 1.6 + base * 0.3;
	}
	if (effect == 2) {
		float flow = sin(UV.x * 20.0 + TIME * 1.5 + sin(UV.y * 12.0 - TIME) * 2.0);
		float hot = smoothstep(0.2, 0.9, flow);
		emi += mix(vec3(1.0, 0.25, 0.0), vec3(1.0, 0.85, 0.2), hot) * (0.5 + hot * 1.3) * (0.4 + 0.6 * m);
		base *= 0.5;
	}
	ALBEDO = base;
	EMISSION = emi;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
}
"""

static var _shader: Shader


static func make_mesh(config: Dictionary) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 28
	sphere.rings = 14
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	apply(mi, config)
	return mi


static func apply(mi: MeshInstance3D, config: Dictionary) -> void:
	var mat: ShaderMaterial = mi.material_override
	var material_id: String = str(config.get("material", "vetro"))
	var pattern_id: String = str(config.get("pattern", "spirale"))
	var p: Array = MATERIAL_PARAMS.get(material_id, MATERIAL_PARAMS["vetro"])
	mat.set_shader_parameter("color_a", Color(str(config.get("color_a", "e63946"))))
	mat.set_shader_parameter("color_b", Color(str(config.get("color_b", "ffffff"))))
	mat.set_shader_parameter("pattern", int(PATTERN_INDEX.get(pattern_id, 0)))
	mat.set_shader_parameter("rough", p[0])
	mat.set_shader_parameter("metal", p[1])
	mat.set_shader_parameter("spec", p[2])
	mat.set_shader_parameter("glow", p[3])
	mat.set_shader_parameter("rim_amount", p[4])
	mat.set_shader_parameter("effect", p[5])
	mat.set_shader_parameter("tint", p[6])
	mat.set_shader_parameter("tint_mix", p[7])
