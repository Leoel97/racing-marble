extends RefCounted
## Aspetto delle biglie: mesh a sfera con shader a strisce.
## Qui crescera' la personalizzazione (materiale, pattern, animazioni).

const RADIUS := 0.5

const SHADER_CODE := """
shader_type spatial;
uniform vec3 color_a : source_color = vec3(0.9, 0.2, 0.2);
uniform vec3 color_b : source_color = vec3(1.0, 1.0, 1.0);
void fragment() {
	// Venature a spirale, come dentro una biglia di vetro.
	float swirl = sin(UV.x * 18.85 + sin(UV.y * 3.1416) * 2.5 + UV.y * 4.0);
	float band = smoothstep(-0.2, 0.2, swirl);
	vec3 base = mix(color_a, color_b, band * 0.85);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = base;
	EMISSION = base * 0.10 + vec3(rim) * 0.22;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
"""

static var _shader: Shader


static func make_mesh(color_a: Color, color_b: Color) -> MeshInstance3D:
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
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	return mi
