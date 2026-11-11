extends Node3D
## Racing Marble - passo 1: una pista, la biglia a inclinazione, 3 avversari.

const TrackScript := preload("res://scripts/track.gd")
const MarbleScript := preload("res://scripts/marble.gd")
const AiScript := preload("res://scripts/ai_marble.gd")

const SETTINGS_PATH := "user://settings.cfg"
const FALL_DEPTH := 5.0

enum State { MENU, COUNTDOWN, RACE, RESULTS }

var state: int = State.MENU
var track: Node3D
var player: RigidBody3D
var bots: Array[Node3D] = []
var camera: Camera3D
var cam_fwd: Vector3 = Vector3.FORWARD

var race_time: float = 0.0
var countdown: float = 0.0
var last_checkpoint: float = 0.0
var player_finish_time: float = -1.0
var results_delay: float = 0.0
var flash_time: float = 0.0
var smoke_test: bool = false
var smoke_frames: int = 0

var invert_steer: bool = false
var sensitivity: float = 2.5

# interfaccia
var hud_pos: Label
var hud_time: Label
var center_label: Label
var menu_box: Control
var results_box: Control
var results_list: Label


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	smoke_test = OS.get_cmdline_user_args().has("--autostart")
	_load_settings()
	_build_world()
	_build_ui()
	_reset_race()
	_show_menu()
	if smoke_test:
		_start_race()
		countdown = 0.1
		player.auto_steer = true


# ------------------------------------------------------------------ mondo

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.98, 0.93, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.97, 0.92)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	track = TrackScript.new()
	track.name = "Track"
	add_child(track)

	player = MarbleScript.new()
	player.name = "Player"
	player.track = track
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	player.freeze = true
	add_child(player)

	var bot_defs := [
		["Bot Blu", Color(0.27, 0.48, 0.80), 13.0, -0.8],
		["Bot Verde", Color(0.16, 0.62, 0.56), 13.8, 0.8],
		["Bot Giallo", Color(1.00, 0.82, 0.25), 14.5, 2.4],
	]
	for def: Array in bot_defs:
		var bot: Node3D = AiScript.new()
		add_child(bot)
		var bot_name: String = def[0]
		var bot_color: Color = def[1]
		var bot_speed: float = def[2]
		var bot_lane: float = def[3]
		bot.setup(track, bot_name, bot_color, bot_speed, bot_lane)
		bots.append(bot)

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	add_child(camera)
	camera.make_current()


# ------------------------------------------------------------ interfaccia

func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 96)
	b.add_theme_font_size_override("font_size", 38)
	return b


func _make_panel(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	box.set_meta("root", center)
	return box


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	hud_pos = _make_label("1/4", 56)
	root.add_child(hud_pos)
	hud_pos.position = Vector2(48, 24)

	hud_time = _make_label("0.0", 44)
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hud_time)
	hud_time.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud_time.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_time.offset_right = -48.0
	hud_time.offset_left = -348.0
	hud_time.offset_top = 28.0

	center_label = _make_label("", 120)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- menu
	var mbox := _make_panel(root)
	menu_box = mbox.get_meta("root")
	var title := _make_label("Racing Marble", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mbox.add_child(title)
	var hint := _make_label("Inclina il telefono a destra e sinistra per sterzare", 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mbox.add_child(hint)
	var play := _make_button("GIOCA")
	play.pressed.connect(_start_race)
	mbox.add_child(play)

	var sens_label := _make_label("Sensibilita' sterzo", 26)
	mbox.add_child(sens_label)
	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = 5.0
	slider.step = 0.1
	slider.value = sensitivity
	slider.custom_minimum_size = Vector2(360, 48)
	slider.value_changed.connect(_on_sensitivity_changed)
	mbox.add_child(slider)

	var inv := CheckButton.new()
	inv.text = "Inverti sterzo"
	inv.add_theme_font_size_override("font_size", 28)
	inv.button_pressed = invert_steer
	inv.toggled.connect(_on_invert_toggled)
	mbox.add_child(inv)

	# --- risultati
	var rbox := _make_panel(root)
	results_box = rbox.get_meta("root")
	var rtitle := _make_label("Classifica", 60)
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rbox.add_child(rtitle)
	results_list = _make_label("", 36)
	rbox.add_child(results_list)
	var again := _make_button("RIGIOCA")
	again.pressed.connect(_start_race)
	rbox.add_child(again)
	var back := _make_button("MENU")
	back.pressed.connect(_show_menu)
	rbox.add_child(back)


func _on_sensitivity_changed(value: float) -> void:
	sensitivity = value
	player.sensitivity = value
	_save_settings()


func _on_invert_toggled(pressed: bool) -> void:
	invert_steer = pressed
	player.invert = pressed
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		invert_steer = bool(cfg.get_value("controls", "invert", false))
		sensitivity = float(cfg.get_value("controls", "sensitivity", 2.5))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "invert", invert_steer)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.save(SETTINGS_PATH)


# ------------------------------------------------------------------- gara

func _reset_race() -> void:
	race_time = 0.0
	player_finish_time = -1.0
	results_delay = 0.0
	last_checkpoint = track.start_s
	player.freeze = true
	player.controls_enabled = false
	player.linear_damp = 0.05
	player.invert = invert_steer
	player.sensitivity = sensitivity
	player.place_at(track.spawn_point(track.start_s, -2.4), track.index_at(track.start_s))
	for bot in bots:
		bot.reset(track.start_s)
	cam_fwd = track.dirs[track.index_at(track.start_s)]
	_update_camera(1.0, true)


func _show_menu() -> void:
	state = State.MENU
	_reset_race()
	menu_box.visible = true
	results_box.visible = false
	hud_pos.visible = false
	hud_time.visible = false
	center_label.text = ""


func _start_race() -> void:
	_reset_race()
	state = State.COUNTDOWN
	countdown = 3.0
	menu_box.visible = false
	results_box.visible = false
	hud_pos.visible = true
	hud_time.visible = true


func _go() -> void:
	state = State.RACE
	player.freeze = false
	player.controls_enabled = true
	center_label.text = "VIA!"
	flash_time = 0.8


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown -= delta
			center_label.text = str(int(ceil(maxf(countdown, 0.01))))
			if countdown <= 0.0:
				_go()
		State.RACE:
			_tick_race(delta)
	if flash_time > 0.0:
		flash_time -= delta
		if flash_time <= 0.0 and state == State.RACE:
			center_label.text = ""
	_update_camera(delta, false)
	if smoke_test:
		smoke_frames += 1
		if smoke_frames % 120 == 0:
			print("SMOKE t=%.1f state=%d progress=%.1f y=%.1f pos=%d" % [race_time, state, player.progress, player.global_position.y, _player_position()])


func _tick_race(delta: float) -> void:
	race_time += delta
	for bot in bots:
		bot.tick(delta, race_time)

	if player_finish_time < 0.0:
		# checkpoint
		for cp: float in track.checkpoints:
			if player.progress >= cp and cp > last_checkpoint:
				last_checkpoint = cp
				center_label.text = "Checkpoint!"
				flash_time = 0.8
		# caduta fuori pista
		var ref_y: float = track.pts[player.track_idx].y
		if player.global_position.y < ref_y - FALL_DEPTH:
			player.place_at(track.spawn_point(last_checkpoint, 0.0), track.index_at(last_checkpoint))
		# traguardo
		if player.progress >= track.finish_s:
			player_finish_time = race_time
			player.controls_enabled = false
			player.linear_damp = 3.0
			center_label.text = "TRAGUARDO!"
			flash_time = 0.0
			results_delay = 2.0
	else:
		results_delay -= delta
		if results_delay <= 0.0:
			_show_results()

	hud_pos.text = "%d/4" % _player_position()
	var shown: float = race_time if player_finish_time < 0.0 else player_finish_time
	hud_time.text = _format_time(shown)


func _standings() -> Array:
	## Ordina i 4 concorrenti: prima chi ha finito (per tempo), poi per avanzamento.
	var rows: Array = []
	rows.append({"name": "Tu", "time": player_finish_time, "progress": player.progress})
	for bot in bots:
		rows.append({"name": bot.display_name, "time": bot.finish_time, "progress": bot.s})
	rows.sort_custom(_compare_rows)
	return rows


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var ta: float = a["time"]
	var tb: float = b["time"]
	if ta >= 0.0 and tb >= 0.0:
		return ta < tb
	if ta >= 0.0:
		return true
	if tb >= 0.0:
		return false
	var pa: float = a["progress"]
	var pb: float = b["progress"]
	return pa > pb


func _player_position() -> int:
	var rows: Array = _standings()
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if row["name"] == "Tu":
			return i + 1
	return 1


func _format_time(t: float) -> String:
	var minutes: int = int(t / 60.0)
	var seconds: float = t - minutes * 60.0
	return "%d:%05.2f" % [minutes, seconds]


func _show_results() -> void:
	state = State.RESULTS
	center_label.text = ""
	var text: String = ""
	var rows: Array = _standings()
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var t: float = row["time"]
		var time_text: String = _format_time(t) if t >= 0.0 else "in gara"
		text += "%d.  %s   %s\n" % [i + 1, row["name"], time_text]
	results_list.text = text.strip_edges()
	if smoke_test:
		print("SMOKE RESULTS\n" + results_list.text)
	results_box.visible = true


# ---------------------------------------------------------------- camera

func _update_camera(delta: float, snap: bool) -> void:
	var target: Vector3 = player.get_global_transform_interpolated().origin
	var fwd: Vector3 = track.dirs[player.track_idx]
	if snap:
		cam_fwd = fwd
	else:
		cam_fwd = cam_fwd.lerp(fwd, 1.0 - exp(-4.0 * delta)).normalized()
	var want: Vector3 = target - cam_fwd * 7.5 + Vector3.UP * 3.8
	if snap:
		camera.global_position = want
	else:
		camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-9.0 * delta))
	camera.look_at(target + cam_fwd * 5.0, Vector3.UP)
