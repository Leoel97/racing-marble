extends Node3D
## Avversario guidato dal gioco: stesso modello di velocita' del giocatore
## (pendenza, attrito, perdita in sterzata), schiva gli ostacoli. E' un fantasma.

const Look := preload("res://scripts/marble_look.gd")
const Marble := preload("res://scripts/marble.gd")

const LATERAL_RATE := 5.0

var track: Node3D
var display_name: String = "Bot"
var color: Color = Color.WHITE
var skill: float = 1.0
var base_skill: float = 1.0
var lane: float = 0.0
var phase: float = 0.0
var s: float = 0.0
var off: float = 0.0
var speed: float = 0.0
var finished: bool = false
var finish_time: float = -1.0

var _mesh: MeshInstance3D


func setup(track_ref: Node3D, bot_name: String, bot_color: Color, bot_skill: float, lane_offset: float, look: Dictionary) -> void:
	track = track_ref
	display_name = bot_name
	color = bot_color
	base_skill = bot_skill
	skill = bot_skill
	lane = lane_offset
	phase = randf() * TAU
	_mesh = Look.make_mesh(look)
	add_child(_mesh)


func reset(start_s: float) -> void:
	s = start_s
	off = lane
	speed = 0.0
	skill = base_skill * randf_range(0.97, 1.03)   # ogni gara un po' diversa
	finished = false
	finish_time = -1.0
	_place(0.0)


func tick(delta: float, race_time: float) -> void:
	if finished:
		return
	var i: int = track.index_at(s)
	var w: float = track.widths[i]
	var limit: float = maxf(w * 0.5 - 0.8, 0.0)

	# dove vuole stare: la sua corsia, con un po' di ondeggiamento, evitando gli ostacoli
	var target: float = lane + sin(s * 0.05 + phase) * w * 0.12
	for o: Vector2 in track.obstacle_list:
		var ahead: float = o.x - s
		if ahead > -1.5 and ahead < 20.0 and absf(target - o.y) < 1.5:
			var side: float = 1.0 if target >= o.y else -1.0
			var dodge: float = o.y + side * 1.7
			if absf(dodge) > limit:
				dodge = o.y - side * 1.7
			target = dodge
	target = clampf(target, -limit, limit)
	var new_off: float = move_toward(off, target, LATERAL_RATE * delta)
	var steer: float = 0.0
	if delta > 0.0:
		steer = clampf(absf(new_off - off) / delta / Marble.LATERAL_SPEED, 0.0, 1.0)
	off = new_off

	var slope: float = -track.dirs[i].y
	var acc: float = Marble.SLOPE_GAIN * skill * slope - Marble.DRAG * speed * speed - Marble.SCRUB * steer * steer * speed
	if speed < Marble.MIN_SPEED:
		acc = maxf(acc, (Marble.MIN_SPEED - speed) * 3.0)
	speed = maxf(speed + acc * delta, 0.0)
	s += speed * delta
	if s >= track.finish_s:
		s = track.finish_s
		finished = true
		finish_time = race_time
	_place(speed * delta)


func _place(step: float) -> void:
	var i: int = track.index_at(s)
	var right: Vector3 = track.rights[i]
	var p: Vector3 = track.pos_at(s)
	global_position = p + right * off + Vector3.UP * Look.RADIUS
	if step > 0.0:
		_mesh.rotate(right, -step / Look.RADIUS)
