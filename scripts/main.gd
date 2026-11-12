extends Node3D
## Racing Marble: flusso di gioco (menu, conto alla rovescia, gara, classifica) e camera.

const TrackScript := preload("res://scripts/track.gd")
const MarbleScript := preload("res://scripts/marble.gd")
const AiScript := preload("res://scripts/ai_marble.gd")
const UiScript := preload("res://scripts/ui.gd")
const RoomScript := preload("res://scripts/room.gd")
const AuthScript := preload("res://scripts/auth.gd")
const AuthUiScript := preload("res://scripts/auth_ui.gd")

const SETTINGS_PATH := "user://settings.cfg"
const FALL_DEPTH := 5.0
const DEFAULT_SENSITIVITY := 2.5
const PLAYER_COLOR := Color(0.90, 0.22, 0.27)

enum State { MENU, COUNTDOWN, RACE, RESULTS }

var state: int = State.MENU
var track: Node3D
var player: RigidBody3D
var bots: Array[Node3D] = []
var camera: Camera3D
var ui: CanvasLayer
var auth: Node
var auth_ui: Control
var cam_fwd: Vector3 = Vector3.FORWARD
var menu_angle: float = 0.6

var race_time: float = 0.0
var countdown: float = 0.0
var countdown_shown: int = 0
var last_checkpoint: float = 0.0
var player_finish_time: float = -1.0
var results_delay: float = 0.0

var invert_steer: bool = false
var sensitivity: float = DEFAULT_SENSITIVITY

# modalita' di servizio usate dalla build automatica
var smoke_test: bool = false
var smoke_frames: int = 0
var shots_dir: String = ""


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autostart":
			smoke_test = true
		elif arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_load_settings()
	_build_world()
	ui = UiScript.new()
	add_child(ui)
	ui.setup_settings(sensitivity, invert_steer)
	ui.play_pressed.connect(_start_race)
	ui.menu_pressed.connect(_show_menu)
	ui.settings_changed.connect(_on_settings_changed)
	ui.logout_pressed.connect(_on_logout)

	auth = AuthScript.new()
	add_child(auth)
	auth_ui = AuthUiScript.new()
	ui.base.add_child(auth_ui)
	auth_ui.setup(ui)
	auth_ui.login_requested.connect(_on_login)
	auth_ui.register_requested.connect(_on_register)
	auth_ui.verify_requested.connect(_on_verify)
	auth_ui.resend_requested.connect(_on_resend)

	_show_menu()
	if smoke_test:
		auth.use_local_profile("Tester")
		_enter_menu()
		_start_race()
		countdown = 0.1
		player.auto_steer = true
		_auth_check()
	elif shots_dir != "":
		_run_shots()
	else:
		_boot_account()


# ---------------------------------------------------------------- account

func _boot_account() -> void:
	## All'avvio: riprende la sessione salvata, altrimenti mostra l'accesso.
	ui.hide_all()
	await auth.restore()
	if auth.is_logged_in():
		_enter_menu()
	else:
		auth_ui.open_login()


func _enter_menu() -> void:
	auth_ui.close()
	ui.set_account(auth.nickname, auth.email, auth.offline)
	_show_menu()


func _finish_auth(result: Dictionary, email: String) -> void:
	auth_ui.set_busy(false)
	var ok: bool = result.get("ok", false)
	var needs_verify: bool = result.get("needs_verify", false)
	if ok:
		_enter_menu()
	elif needs_verify:
		auth_ui.open_verify(email)
	else:
		auth_ui.show_error(str(result.get("error", "")))


func _on_login(email: String, password: String) -> void:
	auth_ui.set_busy(true)
	_finish_auth(await auth.sign_in(email, password), email)


func _on_register(nickname: String, email: String, password: String) -> void:
	auth_ui.set_busy(true)
	_finish_auth(await auth.sign_up(nickname, email, password), email)


func _on_verify(email: String, code: String) -> void:
	auth_ui.set_busy(true)
	_finish_auth(await auth.verify(email, code), email)


func _on_resend(email: String) -> void:
	auth_ui.set_busy(true)
	var result: Dictionary = await auth.resend(email)
	auth_ui.set_busy(false)
	var ok: bool = result.get("ok", false)
	auth_ui.show_info("Codice inviato di nuovo." if ok else str(result.get("error", "")))


func _on_logout() -> void:
	await auth.sign_out()
	state = State.MENU
	_reset_race()
	ui.hide_all()
	auth_ui.open_login()


func _auth_check() -> void:
	## Test automatico: verifica che Supabase risponda, usando credenziali finte.
	var result: Dictionary = await auth.sign_in("nessuno@example.com", "Sbagliata-123")
	print("AUTHCHECK ok=%s code=%s error=%s" % [result.get("ok", false), result.get("code", ""), result.get("error", "")])


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
	sun.rotation_degrees = Vector3(-52.0, -55.0, 0.0)   # la luce entra dalla finestra di sinistra
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)

	track = TrackScript.new()
	track.name = "Track"
	add_child(track)

	var room: Node3D = RoomScript.new()
	room.name = "Room"
	add_child(room)
	room.build(track)

	player = MarbleScript.new()
	player.name = "Player"
	player.track = track
	player.body_color = PLAYER_COLOR
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	player.freeze = true
	add_child(player)

	# [nome, colore, abilita', corsia]
	var bot_defs := [
		["Bot Blu", Color(0.27, 0.48, 0.80), 0.70, -0.8],
		["Bot Verde", Color(0.16, 0.62, 0.56), 0.77, 0.8],
		["Bot Giallo", Color(1.00, 0.82, 0.25), 0.83, 2.4],
	]
	for def: Array in bot_defs:
		var bot: Node3D = AiScript.new()
		add_child(bot)
		var bot_name: String = def[0]
		var bot_color: Color = def[1]
		var bot_skill: float = def[2]
		var bot_lane: float = def[3]
		bot.setup(track, bot_name, bot_color, bot_skill, bot_lane)
		bots.append(bot)

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	add_child(camera)
	camera.make_current()


# ---------------------------------------------------------- impostazioni

func _on_settings_changed(new_sensitivity: float, new_invert: bool) -> void:
	sensitivity = new_sensitivity
	invert_steer = new_invert
	player.sensitivity = sensitivity
	player.invert = invert_steer
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		invert_steer = bool(cfg.get_value("controls", "invert", false))
		sensitivity = float(cfg.get_value("controls", "sensitivity", DEFAULT_SENSITIVITY))


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
	player.linear_damp = 0.0
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
	ui.show_menu()


func _start_race() -> void:
	_reset_race()
	state = State.COUNTDOWN
	countdown = 3.0
	countdown_shown = 0
	ui.show_race()
	_refresh_hud()


func _go() -> void:
	state = State.RACE
	player.freeze = false
	player.controls_enabled = true
	ui.pop("VIA!", UiScript.YELLOW, 190, 0.5)


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown -= delta
			var n: int = int(ceil(maxf(countdown, 0.01)))
			if n != countdown_shown:
				countdown_shown = n
				ui.pop(str(n))
			if countdown <= 0.0:
				_go()
		State.RACE:
			_tick_race(delta)
	_update_camera(delta, false)
	if smoke_test:
		smoke_frames += 1
		if smoke_frames % 120 == 0:
			print("SMOKE t=%.1f state=%d progress=%.1f y=%.1f speed=%.1f pos=%d" % [race_time, state, player.progress, player.global_position.y, player.linear_velocity.length(), _player_position()])


func _tick_race(delta: float) -> void:
	race_time += delta
	for bot in bots:
		bot.tick(delta, race_time)

	if player_finish_time < 0.0:
		for cp: float in track.checkpoints:
			if player.progress >= cp and cp > last_checkpoint:
				last_checkpoint = cp
				ui.pop("CHECKPOINT!", Color.WHITE, 90, 0.5)
		var ref_y: float = track.pts[player.track_idx].y
		if player.global_position.y < ref_y - FALL_DEPTH:
			player.place_at(track.spawn_point(last_checkpoint, 0.0), track.index_at(last_checkpoint))
		if player.progress >= track.finish_s:
			player_finish_time = race_time
			player.controls_enabled = false
			player.linear_damp = 3.0
			ui.pop("TRAGUARDO!", UiScript.YELLOW, 130)
			results_delay = 2.0
	else:
		results_delay -= delta
		if results_delay <= 0.0:
			_show_results()
			return
	_refresh_hud()


func _refresh_hud() -> void:
	var span: float = maxf(track.finish_s - track.start_s, 1.0)
	var fractions: Array = [(player.progress - track.start_s) / span]
	var colors: Array = [PLAYER_COLOR]
	for bot in bots:
		fractions.append((bot.s - track.start_s) / span)
		colors.append(bot.color)
	var shown: float = race_time if player_finish_time < 0.0 else player_finish_time
	ui.update_hud(_player_position(), _format_time(shown), fractions, colors)


func _standings() -> Array:
	## Ordina i 4 concorrenti: prima chi ha finito (per tempo), poi per avanzamento.
	var rows: Array = []
	rows.append({"name": _player_name(), "time": player_finish_time, "progress": player.progress, "color": PLAYER_COLOR, "is_player": true})
	for bot in bots:
		rows.append({"name": bot.display_name, "time": bot.finish_time, "progress": bot.s, "color": bot.color, "is_player": false})
	rows.sort_custom(_compare_rows)
	return rows


func _player_name() -> String:
	return auth.nickname if auth != null and auth.nickname != "" else "Tu"


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
		var is_player: bool = row["is_player"]
		if is_player:
			return i + 1
	return 1


func _format_time(t: float) -> String:
	var minutes: int = int(t / 60.0)
	var seconds: float = t - minutes * 60.0
	return "%d:%05.2f" % [minutes, seconds]


func _show_results() -> void:
	state = State.RESULTS
	ui.clear_center()
	var rows: Array = _standings()
	var log_text: String = ""
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var t: float = row["time"]
		row["time_text"] = _format_time(t) if t >= 0.0 else "in gara"
		log_text += "%d. %s %s\n" % [i + 1, row["name"], row["time_text"]]
	ui.show_results(rows, _player_position())
	if smoke_test:
		print("SMOKE RESULTS\n" + log_text)


# ---------------------------------------------------------------- camera

func _update_camera(delta: float, snap: bool) -> void:
	var target: Vector3 = player.get_global_transform_interpolated().origin
	if state == State.MENU:
		# Nel menu la camera gira lentamente attorno alla biglia sulla griglia di partenza.
		menu_angle += delta * 0.25
		var grid_center: Vector3 = target + track.rights[player.track_idx] * 2.4
		camera.global_position = grid_center + Vector3(sin(menu_angle) * 5.5, 1.9, cos(menu_angle) * 5.5)
		camera.look_at(grid_center + Vector3.UP * 0.4, Vector3.UP)
		return
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


# ------------------------------------------- schermate per la revisione

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


func _run_shots() -> void:
	## Gioca una gara da solo e salva un'immagine di ogni schermata.
	DirAccess.make_dir_recursive_absolute(shots_dir)
	ui.hide_all()
	auth_ui.open_login()
	await _wait(0.6)
	await _shot("0a_accedi")
	auth_ui.open_register()
	auth_ui.show_error("Esiste già un account con questa email.")
	await _wait(0.3)
	await _shot("0b_registrati")
	auth_ui.open_verify("lello@example.com")
	await _wait(0.3)
	await _shot("0c_codice")
	auth.use_local_profile("Lello")
	_enter_menu()
	await _wait(1.0)
	await _shot("1_menu")
	ui.open_settings()
	await _wait(0.3)
	await _shot("2_impostazioni")
	ui.close_settings()
	_start_race()
	player.auto_steer = true
	await _wait(1.3)
	await _shot("3_conto_alla_rovescia")
	await _wait(5.7)
	await _shot("4_gara_a")
	await _wait(4.0)
	await _shot("5_gara_b")
	await _wait(4.0)
	await _shot("6_gara_c")
	await _wait(4.0)
	await _shot("6_gara_d")
	var guard: float = 0.0
	while state != State.RESULTS and guard < 90.0:
		await _wait(0.5)
		guard += 0.5
	await _wait(0.5)
	await _shot("7_classifica")
	get_tree().quit()
