extends Node3D
## Ambientazione: la cameretta attorno alla pista. Solo scenografia, nessuna collisione.
## Scala: la biglia ha raggio 0,5; un metro reale vale circa 62 unita'.
## Quasi tutto e' fatto di scatole unite in un'unica mesh, per pesare poco sul telefono.

const Props := preload("res://scripts/props.gd")
const TrackScript := preload("res://scripts/track.gd")

const ROOM_X := 130.0        # meta' larghezza della stanza
const ROOM_Z0 := 95.0        # parete dietro la partenza
const ROOM_Z1 := -530.0      # parete in fondo
const WALL_H := 170.0

const WALL := Color(0.99, 0.94, 0.84)
const WALL_ACCENT := Color(0.66, 0.84, 0.82)
const FLOOR_A := Color(0.80, 0.60, 0.40)
const FLOOR_B := Color(0.75, 0.55, 0.36)
const WOOD_DARK := Color(0.55, 0.38, 0.25)
const WOOD_LIGHT := Color(0.87, 0.72, 0.52)
const SKY := Color(0.62, 0.84, 0.98)

var _st: SurfaceTool
var _rng := RandomNumberGenerator.new()


func build(track: Node3D) -> void:
	_rng.seed = 7
	# pareti e pavimento: non fanno ombra, altrimenti il soffitto oscurerebbe tutta la stanza
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_shell()
	_window_left(-300.0)
	_window_far(-40.0)
	_door()
	_posters()
	_commit(false)
	# mobili, giocattoli e torri: fanno ombra
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_desk(track)
	_bed()
	_wardrobe()
	_bookshelf()
	_toy_chest()
	_floor_toys()
	_supports(track)
	_commit(true)
	_round_things()


# ---------------------------------------------------------------- utilita'

func _commit(shadows: bool) -> void:
	_st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.7
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _b(size: Vector3, center: Vector3, col: Color) -> void:
	## Aggiunge una scatola allineata agli assi alla mesh unica.
	var h: Vector3 = size * 0.5
	var p := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				p.append(center + Vector3(h.x * sx, h.y * sy, h.z * sz))
	# indici: x*4 + y*2 + z
	var faces := [
		[2, 3, 7, 6], [0, 4, 5, 1],     # sopra, sotto
		[0, 1, 3, 2], [4, 6, 7, 5],     # -x, +x
		[0, 2, 6, 4], [1, 5, 7, 3],     # -z, +z
	]
	var shades := [1.0, 0.72, 0.86, 0.86, 0.80, 0.92]
	for n in range(6):
		var f: Array = faces[n]
		var shade: float = shades[n]
		var c := Color(col.r * shade, col.g * shade, col.b * shade)
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var vi: int = f[idx]
			_st.set_color(c)
			_st.add_vertex(p[vi])


func _round(mesh: Mesh, col: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	mi.material_override = mat
	add_child(mi)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot_deg


func _toy_color() -> Color:
	return Props.TOY_COLORS[_rng.randi() % Props.TOY_COLORS.size()]


# ------------------------------------------------------------------ stanza

func _shell() -> void:
	var depth: float = ROOM_Z0 - ROOM_Z1
	var zc: float = (ROOM_Z0 + ROOM_Z1) * 0.5
	# parquet a listoni
	var plank: float = 10.0
	var x: float = -ROOM_X
	var n: int = 0
	while x < ROOM_X:
		_b(Vector3(plank - 0.15, 1.0, depth), Vector3(x + plank * 0.5, -0.5, zc), FLOOR_A if n % 2 == 0 else FLOOR_B)
		x += plank
		n += 1
	_b(Vector3(ROOM_X * 2.0, 0.5, depth), Vector3(0, -1.0, zc), FLOOR_B.darkened(0.3))
	# pareti (quella in fondo ha un colore diverso), soffitto, battiscopa
	_b(Vector3(ROOM_X * 2.0, WALL_H, 2), Vector3(0, WALL_H * 0.5, ROOM_Z1 - 1.0), WALL_ACCENT)
	_b(Vector3(ROOM_X * 2.0, WALL_H, 2), Vector3(0, WALL_H * 0.5, ROOM_Z0 + 1.0), WALL)
	_b(Vector3(2, WALL_H, depth), Vector3(-ROOM_X - 1.0, WALL_H * 0.5, zc), WALL)
	_b(Vector3(2, WALL_H, depth), Vector3(ROOM_X + 1.0, WALL_H * 0.5, zc), WALL)
	_b(Vector3(ROOM_X * 2.0, 2, depth), Vector3(0, WALL_H + 1.0, zc), Color(1, 1, 1))
	var skirt := Color(1, 1, 1)
	_b(Vector3(ROOM_X * 2.0, 6, 1.2), Vector3(0, 3, ROOM_Z1 + 0.6), skirt)
	_b(Vector3(ROOM_X * 2.0, 6, 1.2), Vector3(0, 3, ROOM_Z0 - 0.6), skirt)
	_b(Vector3(1.2, 6, depth), Vector3(-ROOM_X + 0.6, 3, zc), skirt)
	_b(Vector3(1.2, 6, depth), Vector3(ROOM_X - 0.6, 3, zc), skirt)


func _window_left(zc: float) -> void:
	var x: float = -ROOM_X + 0.6
	_b(Vector3(1.0, 74, 96), Vector3(x, 98, zc), Color(1, 1, 1))
	_b(Vector3(1.4, 66, 88), Vector3(x, 98, zc), SKY)
	_b(Vector3(1.8, 66, 2.5), Vector3(x, 98, zc), Color(1, 1, 1))
	_b(Vector3(1.8, 2.5, 88), Vector3(x, 98, zc), Color(1, 1, 1))
	_b(Vector3(7, 3, 104), Vector3(x + 3.0, 59.5, zc), Color(1, 1, 1))
	# tende
	_b(Vector3(2.5, 86, 16), Vector3(x + 2.5, 96, zc - 56), Props.YELLOW)
	_b(Vector3(2.5, 86, 16), Vector3(x + 2.5, 96, zc + 56), Props.YELLOW)
	_b(Vector3(3, 3, 136), Vector3(x + 2.5, 141, zc), WOOD_DARK)


func _window_far(xc: float) -> void:
	var z: float = ROOM_Z1 + 0.6
	_b(Vector3(96, 74, 1.0), Vector3(xc, 98, z), Color(1, 1, 1))
	_b(Vector3(88, 66, 1.4), Vector3(xc, 98, z), SKY)
	_b(Vector3(2.5, 66, 1.8), Vector3(xc, 98, z), Color(1, 1, 1))
	_b(Vector3(88, 2.5, 1.8), Vector3(xc, 98, z), Color(1, 1, 1))
	_b(Vector3(104, 3, 7), Vector3(xc, 59.5, z + 3.0), Color(1, 1, 1))
	_b(Vector3(16, 86, 2.5), Vector3(xc - 56, 96, z + 2.5), Props.ORANGE)
	_b(Vector3(16, 86, 2.5), Vector3(xc + 56, 96, z + 2.5), Props.ORANGE)
	_b(Vector3(136, 3, 3), Vector3(xc, 141, z + 2.5), WOOD_DARK)


func _door() -> void:
	var x: float = ROOM_X - 0.6
	var zc: float = -20.0
	_b(Vector3(1.4, 130, 64), Vector3(x, 65, zc), Color(1, 1, 1))
	_b(Vector3(2.0, 125, 56), Vector3(x, 62.5, zc), Color(0.93, 0.90, 0.84))
	_b(Vector3(2.4, 44, 40), Vector3(x, 92, zc), Color(0.88, 0.84, 0.77))
	_b(Vector3(2.4, 44, 40), Vector3(x, 34, zc), Color(0.88, 0.84, 0.77))


func _desk(track: Node3D) -> void:
	var top_y: float = track.pts[0].y - TrackScript.THICK      # la pista parte dal bordo del piano
	var zc: float = 25.0
	_b(Vector3(110, 3, 46), Vector3(0, top_y - 1.5, zc), WOOD_LIGHT)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b(Vector3(4, top_y - 3.0, 4), Vector3(sx * 51.0, (top_y - 3.0) * 0.5, zc + sz * 19.0), WOOD_DARK)
	# cassettiera
	_b(Vector3(28, 27, 40), Vector3(36, top_y - 16.5, zc), WOOD_LIGHT.darkened(0.08))
	for n in range(3):
		_b(Vector3(24, 7, 1), Vector3(36, top_y - 7.5 - n * 9.0, zc - 20.3), WOOD_LIGHT)
		_b(Vector3(5, 1.2, 1), Vector3(36, top_y - 7.5 - n * 9.0, zc - 21.0), WOOD_DARK)
	# libri impilati e quaderno
	var y: float = top_y
	for n in range(4):
		var col: Color = _toy_color()
		_b(Vector3(20.0 - n, 2.4, 14.0 - n * 0.5), Vector3(-36.0 + n * 0.7, y + 1.2, zc + 4.0), col)
		_b(Vector3(19.4 - n, 1.8, 13.6 - n * 0.5), Vector3(-35.6 + n * 0.7, y + 1.2, zc + 4.3), Color(1, 1, 1))
		y += 2.4
	_b(Vector3(15, 0.5, 20), Vector3(22, top_y + 0.25, zc + 6.0), Props.BLUE)
	_b(Vector3(13.6, 0.6, 18.6), Vector3(22.4, top_y + 0.3, zc + 6.0), Color(1, 1, 1))
	# sedia
	var cx: float = -78.0
	var cz: float = zc - 2.0
	_b(Vector3(26, 2.5, 26), Vector3(cx, 27, cz), Props.RED)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b(Vector3(2.5, 26, 2.5), Vector3(cx + sx * 11.0, 13, cz + sz * 11.0), WOOD_DARK)
	_b(Vector3(2.5, 30, 26), Vector3(cx - 11.75, 43, cz), Props.RED)


func _bed() -> void:
	var xc: float = -88.0
	var zc: float = -150.0
	_b(Vector3(74, 14, 126), Vector3(xc, 9, zc), WOOD_LIGHT)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b(Vector3(5, 4, 5), Vector3(xc + sx * 33.0, 2, zc + sz * 59.0), WOOD_DARK)
	_b(Vector3(70, 10, 122), Vector3(xc, 21, zc), Color(1, 1, 1))
	_b(Vector3(72, 10.6, 78), Vector3(xc, 21.2, zc - 22.0), Props.BLUE)
	_b(Vector3(72, 10.8, 10), Vector3(xc, 21.2, zc + 14.0), Props.YELLOW)
	_b(Vector3(46, 6, 22), Vector3(xc, 29, zc + 45.0), Color(0.98, 0.96, 0.92))
	_b(Vector3(74, 52, 4), Vector3(xc, 26, zc + 63.0), WOOD_LIGHT)
	_b(Vector3(74, 26, 4), Vector3(xc, 13, zc - 63.0), WOOD_LIGHT)
	# comodino con lampada
	_b(Vector3(24, 26, 24), Vector3(xc + 4.0, 13, zc + 84.0), WOOD_LIGHT.darkened(0.08))
	_b(Vector3(20, 9, 1), Vector3(xc + 4.0, 17, zc + 71.7), WOOD_LIGHT)


func _wardrobe() -> void:
	var x: float = ROOM_X - 20.0
	var zc: float = -165.0
	_b(Vector3(38, 126, 84), Vector3(x, 63, zc), Props.GREEN.lightened(0.55))
	_b(Vector3(1, 112, 39), Vector3(x - 19.3, 66, zc - 20.5), Color(1, 1, 1))
	_b(Vector3(1, 112, 39), Vector3(x - 19.3, 66, zc + 20.5), Color(1, 1, 1))
	_b(Vector3(1.6, 12, 2), Vector3(x - 20.0, 66, zc - 3.0), WOOD_DARK)
	_b(Vector3(1.6, 12, 2), Vector3(x - 20.0, 66, zc + 3.0), WOOD_DARK)
	_b(Vector3(40, 3, 86), Vector3(x, 127.5, zc), Color(1, 1, 1))


func _bookshelf() -> void:
	var x: float = ROOM_X - 13.0
	var zc: float = -320.0
	var w: float = 76.0
	_b(Vector3(24, 104, 2), Vector3(x, 52, zc - w * 0.5), Color(1, 1, 1))
	_b(Vector3(24, 104, 2), Vector3(x, 52, zc + w * 0.5), Color(1, 1, 1))
	_b(Vector3(1, 104, w), Vector3(x + 11.5, 52, zc), Color(0.92, 0.92, 0.95))
	for level in range(5):
		var sy: float = 1.0 + level * 25.5
		_b(Vector3(24, 2, w), Vector3(x, sy, zc), Color(1, 1, 1))
		if level == 4:
			continue
		var z: float = zc - w * 0.5 + 3.0
		while z < zc + w * 0.5 - 6.0:
			var thick: float = _rng.randf_range(2.2, 4.6)
			var tall: float = _rng.randf_range(15.0, 21.5)
			if _rng.randf() < 0.12:
				z += 7.0
				continue
			_b(Vector3(15, tall, thick - 0.2), Vector3(x - 2.5, sy + 1.0 + tall * 0.5, z + thick * 0.5), _toy_color())
			z += thick


func _toy_chest() -> void:
	var xc: float = -108.0
	var zc: float = -370.0
	_b(Vector3(32, 22, 52), Vector3(xc, 11, zc), Props.RED)
	_b(Vector3(34, 4, 54), Vector3(xc, 24, zc), Props.YELLOW)
	_b(Vector3(1, 6, 8), Vector3(xc + 16.6, 15, zc), Props.YELLOW)


func _floor_toys() -> void:
	# cubi di legno giganti (rispetto alla biglia) sparsi sul pavimento
	var spots := [
		Vector3(38, 0, -90), Vector3(46, 0, -96), Vector3(41, 6.5, -93),
		Vector3(-34, 0, -250), Vector3(-41, 0, -244), Vector3(60, 0, -400),
		Vector3(66, 0, -394), Vector3(63, 6.5, -398), Vector3(-52, 0, -470),
		Vector3(30, 0, -485), Vector3(36, 0, -480), Vector3(-70, 0, -300),
	]
	for sp: Vector3 in spots:
		_b(Vector3(6.4, 6.4, 6.4), sp + Vector3(0, 3.2, 0), _toy_color())
	# mattoncini sparsi
	for n in range(26):
		var px: float = _rng.randf_range(-95.0, 95.0)
		var pz: float = _rng.randf_range(-500.0, -60.0)
		if absf(px) < 22.0:
			px += 30.0 * signf(px + 0.01)
		var long_x: bool = _rng.randf() < 0.5
		var size := Vector3(4.0 if long_x else 2.0, 1.3, 2.0 if long_x else 4.0)
		_b(size, Vector3(px, 0.65, pz), _toy_color())
	# trenino
	var tz: float = -205.0
	var tx: float = 52.0
	_b(Vector3(8, 6, 12), Vector3(tx, 5, tz), Props.RED)
	_b(Vector3(8, 5, 6), Vector3(tx, 10.5, tz + 3.0), Props.BLUE)
	_b(Vector3(7, 5, 11), Vector3(tx, 4.5, tz + 14.0), Props.YELLOW)
	_b(Vector3(7, 5, 11), Vector3(tx, 4.5, tz + 27.0), Props.GREEN)


func _posters() -> void:
	var x: float = ROOM_X - 0.4
	_b(Vector3(0.8, 44, 34), Vector3(x, 100, -250.0), Color(1, 1, 1))
	_b(Vector3(1.0, 38, 28), Vector3(x, 100, -250.0), Props.PURPLE)
	_b(Vector3(1.2, 14, 14), Vector3(x, 104, -250.0), Props.YELLOW)
	var lx: float = -ROOM_X + 0.4
	_b(Vector3(0.8, 36, 50), Vector3(lx, 100, -120.0), Color(1, 1, 1))
	_b(Vector3(1.0, 30, 44), Vector3(lx, 100, -120.0), Props.GREEN)
	_b(Vector3(1.2, 10, 30), Vector3(lx, 96, -120.0), Props.ORANGE)
	_b(Vector3(40, 30, 0.8), Vector3(80, 104, ROOM_Z1 + 0.4), Color(1, 1, 1))
	_b(Vector3(34, 24, 1.0), Vector3(80, 104, ROOM_Z1 + 0.5), Props.RED)


func _supports(track: Node3D) -> void:
	## Torri di cubi colorati che reggono la pista.
	var block: float = 2.4
	var s: float = 32.0
	var k: int = 0
	while s < track.total - 4.0:
		var c: Vector3 = track.pos_at(s)
		var top: float = c.y - TrackScript.THICK
		var y: float = 0.0
		var n: int = 0
		while y < top - 0.05:
			var hgt: float = minf(block, top - y)
			_b(Vector3(block - 0.08, hgt - 0.06, block - 0.08), Vector3(c.x, y + hgt * 0.5, c.z), Props.TOY_COLORS[(k + n) % Props.TOY_COLORS.size()])
			y += block
			n += 1
		k += 1
		s += 26.0


func _round_things() -> void:
	# tappeto rotondo a cerchi
	var rug_pos := Vector3(18, 0, -330)
	var rings := [[62.0, Props.BLUE.lightened(0.35)], [48.0, Color(0.99, 0.95, 0.86)], [34.0, Props.RED.lightened(0.3)], [20.0, Color(0.99, 0.95, 0.86)]]
	for n in range(rings.size()):
		var ring: Array = rings[n]
		var disc := CylinderMesh.new()
		var radius: float = ring[0]
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.3
		disc.radial_segments = 40
		var col: Color = ring[1]
		_round(disc, col, rug_pos + Vector3(0, 0.15 + n * 0.06, 0))
	# pallone
	var ball := SphereMesh.new()
	ball.radius = 9.0
	ball.height = 18.0
	ball.radial_segments = 18
	ball.rings = 9
	_round(ball, Props.RED, Vector3(58, 9, -285))
	# orsacchiotto seduto vicino al traguardo
	var base := Vector3(-40, 0, -445)
	var fur := Color(0.72, 0.50, 0.32)
	var light := Color(0.90, 0.76, 0.58)
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 14
	sph.rings = 8
	_round(sph, fur, base + Vector3(0, 12, 0), Vector3(11, 12.5, 10))
	_round(sph, light, base + Vector3(3.5, 11, 0), Vector3(8, 9, 7.5))
	_round(sph, fur, base + Vector3(0.5, 30.5, 0), Vector3(8, 7.5, 8))
	_round(sph, light, base + Vector3(6.5, 29, 0), Vector3(3.5, 3, 3.6))
	_round(sph, Props.DARK, base + Vector3(9.6, 29.8, 0), Vector3(1.0, 0.8, 1.2))
	_round(sph, Props.DARK, base + Vector3(7.0, 32.5, 3.0), Vector3(0.7, 0.7, 0.7))
	_round(sph, Props.DARK, base + Vector3(7.0, 32.5, -3.0), Vector3(0.7, 0.7, 0.7))
	_round(sph, fur, base + Vector3(-0.5, 37, 6.2), Vector3(3, 3, 2.4))
	_round(sph, fur, base + Vector3(-0.5, 37, -6.2), Vector3(3, 3, 2.4))
	_round(sph, fur, base + Vector3(4, 16, 11), Vector3(4, 7.5, 4), Vector3(0, 0, -35))
	_round(sph, fur, base + Vector3(4, 16, -11), Vector3(4, 7.5, 4), Vector3(0, 0, -35))
	_round(sph, fur, base + Vector3(11, 4, 7.5), Vector3(8, 4, 4.4))
	_round(sph, fur, base + Vector3(11, 4, -7.5), Vector3(8, 4, 4.4))
	# lampada da scrivania e portapenne
	var cup := CylinderMesh.new()
	cup.top_radius = 4.0
	cup.bottom_radius = 3.6
	cup.height = 9.0
	cup.radial_segments = 14
	_round(cup, Props.GREEN, Vector3(-12, 44.0, 38))
