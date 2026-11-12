extends RefCounted
## Animazioni al traguardo.

const Props := preload("res://scripts/props.gd")

static var _star: ImageTexture


static func _star_texture() -> ImageTexture:
	if _star != null:
		return _star
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var p := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var edge: float = 0.52 + 0.3 * cos(atan2(p.x, -p.y) * 5.0)
			var a: float = clampf((edge - p.length()) * 14.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_star = ImageTexture.create_from_image(img)
	return _star


static func _gradient(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(colors.size()):
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
		var c: Color = colors[i]
		cols.append(c)
	g.offsets = offsets
	g.colors = cols
	return g


static func _burst(parent: Node, pos: Vector3, amount: int, speed: float, spread: float, gravity: float, life: float, size: float, colors: Array, star: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if star:
		mat.albedo_texture = _star_texture()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.color_initial_ramp = _gradient(colors)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 1.5).timeout.connect(p.queue_free)


static func _hop(body: RigidBody3D, strength: float, spin: bool) -> void:
	## In gara e' un vero salto; nell'anteprima (biglia ferma) si muove solo l'immagine.
	if not body.freeze:
		body.apply_central_impulse(Vector3.UP * strength)
		if spin:
			body.apply_torque_impulse(Vector3.UP * 6.0)
		return
	var mesh: Node3D = body.get("mesh_node")
	if mesh == null:
		return
	var tw: Tween = body.create_tween()
	tw.tween_property(mesh, "position:y", strength * 0.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if spin:
		body.create_tween().tween_property(mesh, "rotation:y", mesh.rotation.y + TAU * 2.0, 0.6)


static func play(kind: String, parent: Node, body: RigidBody3D) -> void:
	var pos: Vector3 = body.global_position
	var toys: Array = Props.TOY_COLORS
	match kind:
		"trottola":
			_hop(body, 4.0, true)
		"coriandoli":
			_hop(body, 4.0, false)
			_burst(parent, pos + Vector3.UP * 0.6, 140, 11.0, 55.0, 12.0, 2.2, 0.2, toys, false)
		"stelle":
			_hop(body, 5.0, true)
			_burst(parent, pos + Vector3.UP * 0.6, 70, 9.0, 70.0, 5.0, 2.4, 0.6, [Color(1, 0.95, 0.5), Color(1, 0.8, 0.2), Color(1, 1, 1)], true)
		"fuochi":
			_hop(body, 5.0, false)
			var offsets: Array = [Vector3(-3, 5, -2), Vector3(3, 6.5, -4), Vector3(0, 8, -6), Vector3(-2, 6, -8)]
			for i in range(offsets.size()):
				var off: Vector3 = offsets[i]
				var col: Color = toys[i % toys.size()]
				var timer: SceneTreeTimer = parent.get_tree().create_timer(0.35 * i)
				timer.timeout.connect(_burst.bind(parent, pos + off, 90, 8.0, 180.0, 3.0, 1.5, 0.28, [col, col.lightened(0.5), Color(1, 1, 1)], false))
		_:
			_hop(body, 6.0, false)
