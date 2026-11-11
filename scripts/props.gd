extends RefCounted
## Oggetti lungo la pista: giocattoli e oggetti di casa costruiti da codice
## con forme semplici (low-poly). Ogni oggetto ha la base a y = 0 e guarda verso -Z.
## build() restituisce { node, shape, shape_pos, yaw }.

const WOOD := Color(0.93, 0.80, 0.58)
const RED := Color(0.90, 0.22, 0.27)
const YELLOW := Color(1.00, 0.82, 0.25)
const GREEN := Color(0.16, 0.62, 0.56)
const BLUE := Color(0.27, 0.48, 0.80)
const ORANGE := Color(0.96, 0.52, 0.20)
const PURPLE := Color(0.60, 0.40, 0.80)
const PINK := Color(0.98, 0.60, 0.70)
const DARK := Color(0.13, 0.15, 0.22)
const WHITE := Color(0.97, 0.97, 0.95)
const TOY_COLORS := [RED, YELLOW, GREEN, BLUE, ORANGE, PURPLE]

static var _materials: Dictionary = {}
static var _font: Font


static func _mat(col: Color) -> StandardMaterial3D:
	var key: String = col.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.45
		_materials[key] = m
	return _materials[key]


static func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(bottom: float, top: float, height: float, segments: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func _ball(radius: float, segments: int = 14) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	return m


static func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func _cyl_shape(radius: float, height: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s


static func _result(node: Node3D, shape: Shape3D, shape_pos: Vector3, yaw: float = 0.0) -> Dictionary:
	return {"node": node, "shape": shape, "shape_pos": shape_pos, "yaw": yaw}


static func build(kind: String, variant: int) -> Dictionary:
	match kind:
		"brick":
			return _bricks(variant)
		"cubes":
			return _letter_cubes(variant)
		"duck":
			return _duck()
		"car":
			return _car(variant)
		"rings":
			return _rings()
		"pencil":
			return _pencil(variant)
		"dice":
			return _dice(variant)
		"pins":
			return _pins()
	return _bricks(variant)


# ------------------------------------------------------------ mattoncini

static func _one_brick(parent: Node3D, col: Color, y: float, yaw_deg: float) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = Vector3(0, y, 0)
	holder.rotation_degrees = Vector3(0, yaw_deg, 0)
	_part(holder, _box(Vector3(1.3, 0.6, 0.66)), col, Vector3(0, 0.3, 0))
	for ix in range(4):
		for iz in range(2):
			_part(holder, _cyl(0.11, 0.11, 0.1, 10), col, Vector3(-0.48 + ix * 0.32, 0.65, -0.16 + iz * 0.32))


static func _bricks(variant: int) -> Dictionary:
	var node := Node3D.new()
	var a: Color = TOY_COLORS[variant % TOY_COLORS.size()]
	var b: Color = TOY_COLORS[(variant + 3) % TOY_COLORS.size()]
	_one_brick(node, a, 0.0, 0.0)
	_one_brick(node, b, 0.6, 90.0 if variant % 2 == 0 else 25.0)
	return _result(node, _box_shape(Vector3(1.3, 1.3, 1.0)), Vector3(0, 0.65, 0), deg_to_rad(float(variant % 3) * 12.0 - 12.0))


# ---------------------------------------------------- cubi con le lettere

static func _letter_cube(parent: Node3D, size: float, y: float, yaw_deg: float, col: Color, letter: String) -> void:
	if _font == null:
		_font = load("res://assets/fonts/Fredoka-Bold.woff2")
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = Vector3(0, y + size * 0.5, 0)
	holder.rotation_degrees = Vector3(0, yaw_deg, 0)
	_part(holder, _box(Vector3(size, size, size)), WOOD, Vector3.ZERO)
	var h: float = size * 0.5
	# [direzione della faccia, rotazione dell'etichetta]
	var faces := [
		[Vector3(0, 0, 1), Vector3(0, 0, 0)],
		[Vector3(0, 0, -1), Vector3(0, 180, 0)],
		[Vector3(1, 0, 0), Vector3(0, 90, 0)],
		[Vector3(-1, 0, 0), Vector3(0, -90, 0)],
		[Vector3(0, 1, 0), Vector3(-90, 0, 0)],
	]
	for f: Array in faces:
		var dir: Vector3 = f[0]
		var rot: Vector3 = f[1]
		var panel := _part(holder, _box(Vector3(size * 0.78, size * 0.78, 0.02)), col, dir * (h + 0.005), rot)
		panel.name = "Faccia"
		var label := Label3D.new()
		label.text = letter
		label.font = _font
		label.font_size = 160
		label.outline_size = 0
		label.pixel_size = size * 0.0042
		label.modulate = Color.WHITE
		holder.add_child(label)
		label.position = dir * (h + 0.02)
		label.rotation_degrees = rot


static func _letter_cubes(variant: int) -> Dictionary:
	var node := Node3D.new()
	var letters := ["A", "B", "C", "R", "M", "G", "O", "K"]
	var l1: String = letters[variant % letters.size()]
	var l2: String = letters[(variant + 3) % letters.size()]
	_letter_cube(node, 1.1, 0.0, 0.0, TOY_COLORS[variant % TOY_COLORS.size()], l1)
	var height: float = 1.1
	if variant % 2 == 0:
		_letter_cube(node, 0.8, 1.1, 28.0, TOY_COLORS[(variant + 2) % TOY_COLORS.size()], l2)
		height = 1.9
	return _result(node, _box_shape(Vector3(1.1, height, 1.1)), Vector3(0, height * 0.5, 0), deg_to_rad(float(variant % 4) * 10.0 - 15.0))


# ------------------------------------------------------------- paperella

static func _duck() -> Dictionary:
	var node := Node3D.new()
	_part(node, _ball(0.55), YELLOW, Vector3(0, 0.46, 0.05), Vector3.ZERO, Vector3(1.0, 0.82, 1.25))
	_part(node, _cyl(0.0, 0.22, 0.4, 8), YELLOW, Vector3(0, 0.62, 0.72), Vector3(-55, 0, 0))
	_part(node, _ball(0.34), YELLOW, Vector3(0, 1.04, -0.36))
	_part(node, _cyl(0.16, 0.0, 0.34, 8), ORANGE, Vector3(0, 0.98, -0.78), Vector3(-90, 0, 0), Vector3(1.25, 1.0, 0.6))
	_part(node, _ball(0.055, 8), DARK, Vector3(0.15, 1.15, -0.63))
	_part(node, _ball(0.055, 8), DARK, Vector3(-0.15, 1.15, -0.63))
	_part(node, _ball(0.3, 10), YELLOW.darkened(0.08), Vector3(0.5, 0.5, 0.1), Vector3.ZERO, Vector3(0.35, 0.7, 1.0))
	_part(node, _ball(0.3, 10), YELLOW.darkened(0.08), Vector3(-0.5, 0.5, 0.1), Vector3.ZERO, Vector3(0.35, 0.7, 1.0))
	# guarda verso chi arriva
	return _result(node, _cyl_shape(0.62, 1.35), Vector3(0, 0.675, 0), PI + 0.3)


# ------------------------------------------------------------- macchinina

static func _car(variant: int) -> Dictionary:
	var node := Node3D.new()
	var col: Color = [RED, BLUE, GREEN, ORANGE][variant % 4]
	_part(node, _box(Vector3(0.95, 0.34, 1.6)), col, Vector3(0, 0.42, 0))
	_part(node, _box(Vector3(0.8, 0.3, 0.75)), Color(0.72, 0.88, 0.97), Vector3(0, 0.74, 0.1))
	_part(node, _box(Vector3(0.84, 0.06, 0.8)), col.darkened(0.15), Vector3(0, 0.92, 0.1))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_part(node, _cyl(0.24, 0.24, 0.18, 12), DARK, Vector3(sx * 0.5, 0.24, sz * 0.5), Vector3(0, 0, 90))
			_part(node, _cyl(0.11, 0.11, 0.2, 8), WHITE, Vector3(sx * 0.5, 0.24, sz * 0.5), Vector3(0, 0, 90))
		_part(node, _ball(0.08, 8), YELLOW, Vector3(sx * 0.3, 0.45, -0.8))
	return _result(node, _box_shape(Vector3(1.15, 0.95, 1.6)), Vector3(0, 0.475, 0), deg_to_rad(float(variant % 3) * 20.0 - 20.0))


# --------------------------------------------------- torre degli anelli

static func _rings() -> Dictionary:
	var node := Node3D.new()
	_part(node, _cyl(0.6, 0.6, 0.12, 16), WHITE, Vector3(0, 0.06, 0))
	_part(node, _cyl(0.07, 0.07, 1.45, 8), WHITE, Vector3(0, 0.72, 0))
	var outer: float = 0.58
	for n in range(5):
		var torus := TorusMesh.new()
		torus.outer_radius = outer
		torus.inner_radius = outer - 0.26
		torus.rings = 14
		torus.ring_segments = 8
		var col: Color = TOY_COLORS[n % TOY_COLORS.size()]
		_part(node, torus, col, Vector3(0, 0.25 + n * 0.25, 0))
		outer -= 0.075
	_part(node, _ball(0.15, 10), RED, Vector3(0, 1.5, 0))
	return _result(node, _cyl_shape(0.6, 1.55), Vector3(0, 0.775, 0))


# ----------------------------------------------------------------- matita

static func _pencil(variant: int) -> Dictionary:
	var node := Node3D.new()
	var col: Color = [YELLOW, GREEN, BLUE][variant % 3]
	var r: float = 0.2
	# sdraiata lungo l'asse X
	_part(node, _cyl(r, r, 2.2, 6), col, Vector3(0, r, 0), Vector3(0, 0, 90))
	_part(node, _cyl(r, 0.06, 0.42, 6), WOOD, Vector3(-1.31, r, 0), Vector3(0, 0, 90))
	_part(node, _cyl(0.06, 0.0, 0.14, 6), DARK, Vector3(-1.59, r, 0), Vector3(0, 0, 90))
	_part(node, _cyl(r + 0.012, r + 0.012, 0.18, 10), Color(0.75, 0.77, 0.80), Vector3(1.19, r, 0), Vector3(0, 0, 90))
	_part(node, _cyl(r, r, 0.24, 10), PINK, Vector3(1.40, r, 0), Vector3(0, 0, 90))
	var yaw: float = deg_to_rad(65.0 if variant % 2 == 0 else -65.0)
	return _result(node, _box_shape(Vector3(3.1, r * 2.0, r * 2.0)), Vector3(-0.07, r, 0), yaw)


# ------------------------------------------------------------------- dado

static func _dice(variant: int) -> Dictionary:
	var node := Node3D.new()
	var size: float = 1.15
	var h: float = size * 0.5
	_part(node, _box(Vector3(size, size, size)), WHITE, Vector3(0, h, 0))
	var pip := _cyl(0.1, 0.1, 0.02, 10)
	var q: float = size * 0.26
	# faccia in alto: 5
	for p: Vector2 in [Vector2(0, 0), Vector2(-q, -q), Vector2(q, -q), Vector2(-q, q), Vector2(q, q)]:
		_part(node, pip, DARK, Vector3(p.x, size + 0.005, p.y))
	# davanti e dietro: 3 e 4
	for p: Vector2 in [Vector2(-q, q), Vector2(0, 0), Vector2(q, -q)]:
		_part(node, pip, DARK, Vector3(p.x, h + p.y, -h - 0.005), Vector3(90, 0, 0))
	for p: Vector2 in [Vector2(-q, -q), Vector2(q, -q), Vector2(-q, q), Vector2(q, q)]:
		_part(node, pip, DARK, Vector3(p.x, h + p.y, h + 0.005), Vector3(90, 0, 0))
	# lati: 1 e 6
	_part(node, _cyl(0.14, 0.14, 0.02, 10), RED, Vector3(h + 0.005, h, 0), Vector3(0, 0, 90))
	for p: Vector2 in [Vector2(-q, -q), Vector2(-q, 0), Vector2(-q, q), Vector2(q, -q), Vector2(q, 0), Vector2(q, q)]:
		_part(node, pip, DARK, Vector3(-h - 0.005, h + p.y, p.x), Vector3(0, 0, 90))
	return _result(node, _box_shape(Vector3(size, size, size)), Vector3(0, h, 0), deg_to_rad(float(variant % 5) * 17.0))


# ---------------------------------------------------------------- birilli

static func _pins() -> Dictionary:
	var node := Node3D.new()
	for p: Vector2 in [Vector2(0, -0.36), Vector2(-0.36, 0.26), Vector2(0.36, 0.26)]:
		_part(node, _cyl(0.2, 0.12, 0.25, 10), WHITE, Vector3(p.x, 0.125, p.y))
		_part(node, _ball(0.27, 12), WHITE, Vector3(p.x, 0.46, p.y), Vector3.ZERO, Vector3(1.0, 1.35, 1.0))
		_part(node, _cyl(0.13, 0.11, 0.3, 10), WHITE, Vector3(p.x, 0.92, p.y))
		_part(node, _cyl(0.135, 0.125, 0.09, 10), RED, Vector3(p.x, 0.9, p.y))
		_part(node, _ball(0.16, 10), WHITE, Vector3(p.x, 1.14, p.y))
	return _result(node, _cyl_shape(0.68, 1.3), Vector3(0, 0.65, 0))
