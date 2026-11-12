extends Node3D
## Pista: una linea centrale campionata, da cui nascono mesh, collisioni,
## ostacoli, checkpoint e arredamento della cameretta.

const Props := preload("res://scripts/props.gd")

const SUB := 24          # campioni per tratto tra due punti di controllo
const THICK := 0.5       # spessore della pista

# Punti di controllo: [posizione, larghezza]. Si scende lungo -Z.
const CONTROL := [
	[Vector3(0, 40, 0), 8.0],
	[Vector3(0, 37.5, -25), 8.0],
	[Vector3(6, 35, -55), 7.0],
	[Vector3(10, 30, -85), 6.0],
	[Vector3(2, 27.5, -115), 6.0],
	[Vector3(-8, 25.5, -145), 7.0],
	[Vector3(-10, 21, -175), 5.5],
	[Vector3(-2, 17, -205), 5.5],
	[Vector3(6, 15, -235), 6.0],
	[Vector3(4, 13, -265), 5.0],
	[Vector3(-4, 9.5, -295), 5.5],
	[Vector3(-6, 7, -325), 6.0],
	[Vector3(0, 5.5, -355), 7.0],
	[Vector3(0, 4, -385), 8.0],
	[Vector3(0, 2.8, -415), 8.0],
	[Vector3(0, 1.8, -445), 8.0],
]

# Ostacoli: [distanza lungo la pista, posizione laterale da -1 a 1, tipo]
const OBSTACLES := [
	[70.0, -0.9, "brick"], [70.0, 0.9, "cubes"],
	[105.0, 0.0, "rings"],
	[135.0, 0.6, "duck"], [150.0, -0.6, "car"],
	[185.0, 0.2, "dice"], [200.0, -0.5, "pencil"],
	[230.0, 0.5, "pins"], [250.0, -0.2, "cubes"],
	[280.0, 0.5, "brick"], [295.0, -0.5, "duck"],
	[325.0, 0.0, "car"], [345.0, 0.9, "rings"], [345.0, -0.9, "pins"],
	[375.0, -0.3, "dice"], [390.0, 0.4, "cubes"],
]

const CHECKPOINT_EVERY := 100.0

const PALETTE := [
	Color(0.90, 0.22, 0.27), Color(1.00, 0.82, 0.25), Color(0.16, 0.62, 0.56),
	Color(0.27, 0.48, 0.80), Color(0.96, 0.52, 0.20), Color(0.60, 0.40, 0.80),
]

var pts := PackedVector3Array()
var dirs := PackedVector3Array()
var rights := PackedVector3Array()
var widths := PackedFloat32Array()
var dist := PackedFloat32Array()
var total: float = 0.0
var start_s: float = 5.0
var finish_s: float = 0.0
var checkpoints: Array[float] = []
var obstacle_list := PackedVector2Array()   # (distanza, spostamento laterale in metri)


func _ready() -> void:
	_build_samples()
	_build_track_mesh()
	_build_obstacles()
	_build_gates()


# ---------------------------------------------------------------- campioni

func _build_samples() -> void:
	var count: int = CONTROL.size()
	for i in range(count - 1):
		var p0: Vector3 = CONTROL[maxi(i - 1, 0)][0]
		var p1: Vector3 = CONTROL[i][0]
		var p2: Vector3 = CONTROL[i + 1][0]
		var p3: Vector3 = CONTROL[mini(i + 2, count - 1)][0]
		var w1: float = CONTROL[i][1]
		var w2: float = CONTROL[i + 1][1]
		for j in range(SUB):
			var t: float = float(j) / float(SUB)
			pts.append(p1.cubic_interpolate(p2, p0, p3, t))
			widths.append(lerpf(w1, w2, t))
	var last_p: Vector3 = CONTROL[count - 1][0]
	var last_w: float = CONTROL[count - 1][1]
	pts.append(last_p)
	widths.append(last_w)

	var n: int = pts.size()
	var acc: float = 0.0
	for i in range(n):
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var d: Vector3 = (b - a).normalized()
		dirs.append(d)
		rights.append(d.cross(Vector3.UP).normalized())
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		dist.append(acc)
	total = acc
	finish_s = total - 12.0
	var cp: float = CHECKPOINT_EVERY
	checkpoints.append(start_s)
	while cp < finish_s - 30.0:
		checkpoints.append(cp)
		cp += CHECKPOINT_EVERY


func index_at(s: float) -> int:
	return clampi(dist.bsearch(s), 0, pts.size() - 1)


func pos_at(s: float) -> Vector3:
	s = clampf(s, 0.0, total)
	var i: int = clampi(dist.bsearch(s), 1, pts.size() - 1)
	var d0: float = dist[i - 1]
	var d1: float = dist[i]
	var t: float = 0.0
	if d1 > d0:
		t = (s - d0) / (d1 - d0)
	return pts[i - 1].lerp(pts[i], t)


func nearest_index(p: Vector3, hint: int) -> int:
	var best: int = hint
	var best_d: float = INF
	var from: int = maxi(hint - 8, 0)
	var to: int = mini(hint + 24, pts.size() - 1)
	for i in range(from, to + 1):
		var d: float = pts[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func spawn_point(s: float, lateral: float) -> Vector3:
	var i: int = index_at(s)
	return pos_at(s) + rights[i] * lateral + Vector3.UP * 0.8


# ------------------------------------------------------------------- mesh

func _quad(st: SurfaceTool, col: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)


func _build_track_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var down := Vector3(0.0, -THICK, 0.0)
	for i in range(pts.size() - 1):
		var col: Color = PALETTE[(i >> 2) % PALETTE.size()]
		if dist[i] >= finish_s:
			col = Color(0.95, 0.95, 0.95) if (i % 2) == 0 else Color(0.12, 0.12, 0.12)
		var l0: Vector3 = pts[i] - rights[i] * widths[i] * 0.5
		var r0: Vector3 = pts[i] + rights[i] * widths[i] * 0.5
		var l1: Vector3 = pts[i + 1] - rights[i + 1] * widths[i + 1] * 0.5
		var r1: Vector3 = pts[i + 1] + rights[i + 1] * widths[i + 1] * 0.5
		var side: Color = col.darkened(0.3)
		_quad(st, col, l0, l1, r1, r0)
		_quad(st, side, l0 + down, l1 + down, l1, l0)
		_quad(st, side, r0, r1, r1 + down, r0 + down)
		_quad(st, side.darkened(0.3), r0 + down, r1 + down, l1 + down, l0 + down)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.55

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


# --------------------------------------------------------------- oggetti

func _color_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.5
	return mat


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, solid: bool, yaw: float = 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _color_mat(col)
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		holder = body
	else:
		holder = Node3D.new()
	holder.add_child(mi)
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = yaw


func _add_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, col: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _color_mat(col)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	body.position = pos


func _yaw_of(i: int) -> float:
	return atan2(-dirs[i].x, -dirs[i].z)


func _build_obstacles() -> void:
	var k: int = 0
	for o: Array in OBSTACLES:
		var s: float = o[0]
		var lat: float = o[1]
		var kind: String = o[2]
		var i: int = index_at(s)
		var half: float = widths[i] * 0.5 - 0.9
		var base: Vector3 = pos_at(s) + rights[i] * lat * half
		obstacle_list.append(Vector2(s, lat * half))
		var prop: Dictionary = Props.build(kind, k)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = prop["shape"]
		cs.position = prop["shape_pos"]
		body.add_child(cs)
		var visual: Node3D = prop["node"]
		body.add_child(visual)
		add_child(body)
		var extra_yaw: float = prop["yaw"]
		body.position = base + Vector3.DOWN * 0.04
		body.rotation.y = _yaw_of(i) + extra_yaw
		k += 1


func _add_gate(s: float, col: Color) -> void:
	var i: int = index_at(s)
	var c: Vector3 = pos_at(s)
	var half: float = widths[i] * 0.5 + 0.5
	var yaw: float = _yaw_of(i)
	_add_box(self, Vector3(0.6, 5.0, 0.6), c - rights[i] * half + Vector3.UP * 2.0, col, false, yaw)
	_add_box(self, Vector3(0.6, 5.0, 0.6), c + rights[i] * half + Vector3.UP * 2.0, col, false, yaw)
	_add_box(self, Vector3(half * 2.0 + 0.6, 0.8, 0.6), c + Vector3.UP * 4.9, col, false, yaw)


func _build_gates() -> void:
	_add_gate(start_s + 3.0, Color(0.16, 0.62, 0.56))
	for n in range(1, checkpoints.size()):
		_add_gate(checkpoints[n], Color(1.00, 0.82, 0.25))
	_add_gate(finish_s, Color(0.90, 0.22, 0.27))
