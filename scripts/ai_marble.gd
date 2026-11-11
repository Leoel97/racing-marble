extends Node3D
## Avversario guidato dal gioco: segue la pista, e' un fantasma (nessun urto).

const Look := preload("res://scripts/marble_look.gd")

var track: Node3D
var display_name: String = "Bot"
var base_speed: float = 13.0
var lane: float = 0.0
var phase: float = 0.0
var s: float = 0.0
var speed: float = 0.0
var finished: bool = false
var finish_time: float = -1.0

var _mesh: MeshInstance3D


func setup(track_ref: Node3D, bot_name: String, color: Color, bot_speed: float, lane_offset: float) -> void:
	track = track_ref
	display_name = bot_name
	base_speed = bot_speed
	lane = lane_offset
	phase = randf() * TAU
	_mesh = Look.make_mesh(color, Color(1.0, 1.0, 1.0))
	add_child(_mesh)


func reset(start_s: float) -> void:
	s = start_s
	speed = 0.0
	finished = false
	finish_time = -1.0
	_place(0.0)


func tick(delta: float, race_time: float) -> void:
	if finished:
		return
	var wanted: float = base_speed * (1.0 + 0.08 * sin(race_time * 0.7 + phase))
	speed = move_toward(speed, wanted, 8.0 * delta)
	s += speed * delta
	if s >= track.finish_s:
		s = track.finish_s
		finished = true
		finish_time = race_time
	_place(speed * delta)


func _place(step: float) -> void:
	var i: int = track.index_at(s)
	var w: float = track.widths[i]
	var right: Vector3 = track.rights[i]
	var limit: float = maxf(w * 0.5 - 0.8, 0.0)
	var off: float = clampf(lane + sin(s * 0.05 + phase) * w * 0.22, -limit, limit)
	var p: Vector3 = track.pos_at(s)
	global_position = p + right * off + Vector3.UP * Look.RADIUS
	if step > 0.0:
		_mesh.rotate(right, -step / Look.RADIUS)
