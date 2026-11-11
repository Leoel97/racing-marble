extends RefCounted
## Aspetto delle biglie: mesh a sfera con shader a strisce.
## Qui crescera' la personalizzazione (materiale, pattern, animazioni).

const RADIUS := 0.5

const SHADER_CODE := """
shader_type spatial;
uniform vec3 color_a : source_color = vec3(0.9, 0.2, 0.2);
uniform vec3 color_b : source_color = vec3(1.0, 1.0, 1.0);
uniform float stripes = 4.0;
void fragment() {
	float s = step(0.5, fract(UV.x * stripes));
	ALBEDO = mix(color_a, color_b, s);
	ROUGHNESS = 0.18;
	METALLIC = 0.05;
	SPECULAR = 0.7;
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
	sphere.radial_segments = 20
	sphere.rings = 10
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	return mi
