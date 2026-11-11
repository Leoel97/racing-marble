extends RigidBody3D
## Biglia del giocatore: avanza da sola, si sterza inclinando il telefono.

const Look := preload("res://scripts/marble_look.gd")

# Modello di guida: la biglia accelera con la pendenza, frena con l'aria
# e perde velocita' ogni volta che si sterza.
const SLOPE_GAIN := 90.0     # spinta lungo la pista per unita' di pendenza
const DRAG := 0.0175         # resistenza che cresce con il quadrato della velocita'
const SCRUB := 0.15          # velocita' persa sterzando
const MIN_SPEED := 6.0       # sotto questa soglia una piccola spinta evita lo stallo
const LATERAL_SPEED := 9.0
const ROLL_INERTIA := 1.4    # una sfera che rotola "pesa" 7/5: compensa la spinta

var track: Node3D
var body_color: Color = Color(0.90, 0.22, 0.27)
var track_idx: int = 0
var progress: float = 0.0
var controls_enabled: bool = false
var invert: bool = false
var sensitivity: float = 2.5
var touch_steer: float = 0.0
var auto_steer: bool = false   # usato solo dal test automatico

var _auto_target: float = 0.0
var _auto_stuck: float = 0.0
var _auto_hold: float = 0.0
var _auto_side: float = 1.0
var _respawn_pending: bool = false
var _respawn_xform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	mass = 1.0
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.0
	angular_damp = 0.0
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.15
	physics_material_override = pm
	var shape := SphereShape3D.new()
	shape.radius = Look.RADIUS
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	add_child(Look.make_mesh(body_color, Color(1.0, 1.0, 1.0)))


func get_steer() -> float:
	if auto_steer:
		return _autopilot()
	var g: Vector3 = Input.get_gravity()
	if g.length() < 0.5:
		g = Input.get_accelerometer()
	var st: float = 0.0
	if g.length() > 0.5:
		st = g.x / 9.81 * sensitivity
		if absf(st) < 0.04:
			st = 0.0
	if invert:
		st = -st
	st += touch_steer + Input.get_axis("ui_left", "ui_right")
	return clampf(st, -1.0, 1.0)


func _autopilot() -> float:
	## Pilota del test automatico: sta al centro, schiva gli ostacoli in arrivo
	## e scarta di lato se resta comunque bloccato.
	var dt: float = get_physics_process_delta_time()
	var right: Vector3 = track.rights[track_idx]
	var off: float = (global_position - track.pts[track_idx]).dot(right)
	var limit: float = maxf(track.widths[track_idx] * 0.5 - 0.9, 0.0)
	var target: float = 0.0
	for o: Vector2 in track.obstacle_list:
		var ahead: float = o.x - progress
		if ahead > -1.5 and ahead < 22.0 and absf(target - o.y) < 1.6:
			var side: float = 1.0 if off >= o.y else -1.0
			var dodge: float = o.y + side * 1.9
			if absf(dodge) > limit:
				dodge = o.y - side * 1.9
			target = dodge
	if _auto_hold > 0.0:
		_auto_hold -= dt
		target = _auto_target
	elif linear_velocity.dot(track.dirs[track_idx]) < 3.0:
		_auto_stuck += dt
		if _auto_stuck > 0.6:
			_auto_stuck = 0.0
			_auto_side = -_auto_side
			_auto_target = clampf(off + _auto_side * 2.0, -limit, limit)
			_auto_hold = 1.5
	else:
		_auto_stuck = 0.0
	return clampf((target - off) * 0.8, -1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Riserva per provare senza sensori: tocca meta' sinistra/destra dello schermo.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var half: float = get_viewport().get_visible_rect().size.x * 0.5
			touch_steer = -1.0 if touch.position.x < half else 1.0
		else:
			touch_steer = 0.0


func _physics_process(_delta: float) -> void:
	if track == null:
		return
	track_idx = track.nearest_index(global_position, track_idx)
	progress = track.dist[track_idx]
	if not controls_enabled or freeze:
		return
	var fwd: Vector3 = track.dirs[track_idx]
	var right: Vector3 = track.rights[track_idx]
	var vf: float = linear_velocity.dot(fwd)
	var vr: float = linear_velocity.dot(right)
	var steer: float = get_steer()
	var slope: float = -fwd.y
	var acc: float = SLOPE_GAIN * slope - DRAG * vf * absf(vf) - SCRUB * absf(steer) * maxf(vf, 0.0)
	if vf < MIN_SPEED:
		acc = maxf(acc, (MIN_SPEED - vf) * 3.0)
	apply_central_force(fwd * acc * mass * ROLL_INERTIA)
	apply_central_force(right * (steer * LATERAL_SPEED - vr) * 10.0 * mass)


func place_at(pos: Vector3, idx: int) -> void:
	## Sposta la biglia (alla partenza o a un checkpoint) azzerando la velocita'.
	track_idx = idx
	if freeze:
		global_position = pos
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		reset_physics_interpolation()
	else:
		_respawn_xform = Transform3D(Basis.IDENTITY, pos)
		_respawn_pending = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _respawn_pending:
		_respawn_pending = false
		state.transform = _respawn_xform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		reset_physics_interpolation.call_deferred()
