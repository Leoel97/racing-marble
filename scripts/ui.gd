extends CanvasLayer
## Interfaccia di Racing Marble: menu, impostazioni, HUD di gara, classifica.
## Tutto costruito da codice con un unico tema (font Fredoka, bottoni "a mattoncino").

signal play_pressed
signal menu_pressed
signal settings_changed(sensitivity: float, invert: bool)
signal logout_pressed

const ProgressBarScript := preload("res://scripts/progress_bar.gd")

const INK := Color(0.114, 0.169, 0.325)
const YELLOW := Color(1.0, 0.824, 0.247)
const YELLOW_DARK := Color(0.839, 0.588, 0.0)
const WHITE_DARK := Color(0.800, 0.831, 0.902)
const ROW := Color(0.933, 0.945, 0.969)
const SENS_MIN := 1.0
const SENS_MAX := 4.0

var font_bold: Font
var font_semi: Font

var base: Control
var safe: Control
var menu: Control
var settings: Control
var hud: Control
var results: Control
var center: Label

var pos_label: Label
var time_label: Label
var progress: Control
var results_headline: Label
var results_rows: VBoxContainer
var sens_slider: HSlider
var invert_btn: Button
var play_btn: Button
var name_label: Label
var account_label: Label

var _invert: bool = false
var _center_tween: Tween


func _ready() -> void:
	font_bold = load("res://assets/fonts/Fredoka-Bold.woff2")
	font_semi = load("res://assets/fonts/Fredoka-SemiBold.woff2")

	base = Control.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 30
	base.theme = th
	add_child(base)

	safe = _full(base)
	_build_hud()
	_build_menu()
	center = _label("", 190, Color.WHITE, 30)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_results()
	_build_settings()

	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


# ------------------------------------------------------------- mattoncini

func _full(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _label(text: String, font_size: int, color: Color, outline: int = 0, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font_semi)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, radius: int, bottom_color: Color = Color.TRANSPARENT, bottom: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = bottom_color
	sb.border_width_bottom = bottom
	sb.anti_aliasing = true
	return sb


func _margins(sb: StyleBoxFlat, horizontal: float, top: float, bottom: float) -> StyleBoxFlat:
	sb.content_margin_left = horizontal
	sb.content_margin_right = horizontal
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
	return sb


func _button(text: String, font_size: int, bg: Color, dark: Color, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, INK)
	var radius: int = int(minf(min_size.y * 0.32, 34.0))
	var normal := _margins(_box(bg, radius, dark, 9), 36.0, 8.0, 17.0)
	normal.shadow_color = Color(INK, 0.28)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 5)
	var pressed := _margins(_box(bg.darkened(0.08), radius, dark, 3), 36.0, 14.0, 11.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _card(min_width: float) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := _margins(_box(Color.WHITE, 38, WHITE_DARK, 10), 40.0, 30.0, 38.0)
	sb.shadow_color = Color(INK, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(min_width, 0)
	return card


func _overlay(dim_alpha: float) -> Control:
	## Schermata a tutto schermo con sfondo scurito e contenuto centrato.
	var screen := _full(base)
	var dim := ColorRect.new()
	dim.color = Color(INK, dim_alpha)
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	screen.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.set_meta("center", cc)
	return screen


func _circle_texture(diameter: int, fill: Color, border: Color, border_px: float) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r: float = diameter * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a: float = clampf(r - d, 0.0, 1.0)
			var mix_border: float = clampf(d - (r - border_px), 0.0, 1.0)
			var c: Color = fill.lerp(border, mix_border)
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _apply_safe_area() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var area: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var left: float = 0.0
	var top: float = 0.0
	var right: float = 0.0
	var bottom: float = 0.0
	if win.x > 0.0 and win.y > 0.0 and area.size.x > 0.0 and area.size.y > 0.0:
		var k: float = vp.x / win.x
		left = maxf(area.position.x, 0.0) * k
		top = maxf(area.position.y, 0.0) * k
		right = maxf(win.x - area.end.x, 0.0) * k
		bottom = maxf(win.y - area.end.y, 0.0) * k
	safe.offset_left = clampf(left, 36.0, 140.0)
	safe.offset_right = -clampf(right, 36.0, 140.0)
	safe.offset_top = clampf(top, 22.0, 90.0)
	safe.offset_bottom = -clampf(bottom, 24.0, 90.0)


# ------------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud = _full(safe)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var pill_style := _margins(_box(Color(INK, 0.9), 26, Color(0, 0, 0, 0.25), 5), 24.0, 2.0, 7.0)

	var pos_pill := PanelContainer.new()
	pos_pill.add_theme_stylebox_override("panel", pill_style)
	pos_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pos_pill)
	var pos_box := HBoxContainer.new()
	pos_box.add_theme_constant_override("separation", 4)
	pos_pill.add_child(pos_box)
	pos_label = _label("1°", 52, YELLOW)
	pos_box.add_child(pos_label)
	var pos_total := _label("/4", 30, Color.WHITE)
	pos_total.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_box.add_child(pos_total)

	progress = ProgressBarScript.new()
	progress.custom_minimum_size = Vector2(0, 60)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(progress)

	var time_pill := PanelContainer.new()
	time_pill.add_theme_stylebox_override("panel", pill_style)
	time_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(time_pill)
	time_label = _label("0:00.00", 40, Color.WHITE)
	time_label.custom_minimum_size = Vector2(170, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_pill.add_child(time_label)


func update_hud(place: int, time_text: String, fractions: Array, colors: Array) -> void:
	pos_label.text = "%d°" % place
	time_label.text = time_text
	progress.set_racers(fractions, colors)


# ------------------------------------------------------------------ menu

func _build_menu() -> void:
	menu = _full(safe)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(title)
	var line1 := _label("RACING", 92, Color.WHITE, 24)
	line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(line1)
	var line2 := _label("MARBLE", 128, YELLOW, 28)
	line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(line2)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.rotation_degrees = -3.0
	title.resized.connect(func() -> void: title.pivot_offset = title.size * 0.5)

	play_btn = _button("GIOCA", 62, YELLOW, YELLOW_DARK, Vector2(440, 124))
	menu.add_child(play_btn)
	play_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	play_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	play_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_btn.pressed.connect(func() -> void: play_pressed.emit())
	play_btn.resized.connect(func() -> void: play_btn.pivot_offset = play_btn.size * 0.5)
	var pulse := create_tween().set_loops()
	pulse.tween_property(play_btn, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)

	var gear := _button("IMPOSTAZIONI", 26, Color.WHITE, WHITE_DARK, Vector2(0, 70))
	menu.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gear.pressed.connect(open_settings)

	var name_pill := PanelContainer.new()
	name_pill.add_theme_stylebox_override("panel", _margins(_box(Color(INK, 0.9), 26, Color(0, 0, 0, 0.25), 5), 26.0, 6.0, 11.0))
	name_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(name_pill)
	name_label = _label("", 34, Color.WHITE)
	name_pill.add_child(name_label)
	name_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 0)

	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 22, Color.WHITE, 8, false)
	menu.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN


# ---------------------------------------------------------- impostazioni

func _build_settings() -> void:
	settings = _overlay(0.6)
	var cc: CenterContainer = settings.get_meta("center")
	var card := _card(620.0)
	cc.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var title := _label("IMPOSTAZIONI", 46, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_label("Sensibilità dello sterzo", 30, INK, 0, false))
	sens_slider = HSlider.new()
	sens_slider.min_value = SENS_MIN
	sens_slider.max_value = SENS_MAX
	sens_slider.step = 0.05
	sens_slider.custom_minimum_size = Vector2(520, 60)
	sens_slider.focus_mode = Control.FOCUS_NONE
	var track_sb := _box(ROW.darkened(0.08), 10)
	track_sb.content_margin_top = 9.0
	track_sb.content_margin_bottom = 9.0
	var fill_sb := _box(YELLOW, 10)
	sens_slider.add_theme_stylebox_override("slider", track_sb)
	sens_slider.add_theme_stylebox_override("grabber_area", fill_sb)
	sens_slider.add_theme_stylebox_override("grabber_area_highlight", fill_sb)
	var knob := _circle_texture(56, YELLOW, INK, 6.0)
	sens_slider.add_theme_icon_override("grabber", knob)
	sens_slider.add_theme_icon_override("grabber_highlight", knob)
	sens_slider.add_theme_icon_override("grabber_disabled", knob)
	sens_slider.value_changed.connect(func(_v: float) -> void: _emit_settings())
	box.add_child(sens_slider)

	var ends := HBoxContainer.new()
	var low := _label("Bassa", 22, INK.lightened(0.35), 0, false)
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(low)
	ends.add_child(_label("Alta", 22, INK.lightened(0.35), 0, false))
	box.add_child(ends)

	invert_btn = _button("", 30, ROW, WHITE_DARK, Vector2(0, 84))
	invert_btn.pressed.connect(_toggle_invert)
	box.add_child(invert_btn)

	account_label = _label("", 22, INK.lightened(0.35), 0, false)
	account_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(account_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var logout := _button("ESCI DALL'ACCOUNT", 26, Color.WHITE, WHITE_DARK, Vector2(0, 88))
	logout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logout.pressed.connect(func() -> void: logout_pressed.emit())
	row.add_child(logout)
	var close := _button("FATTO", 36, YELLOW, YELLOW_DARK, Vector2(0, 88))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(close_settings)
	row.add_child(close)
	settings.visible = false


func setup_settings(sensitivity: float, invert: bool) -> void:
	_invert = invert
	sens_slider.set_value_no_signal(clampf(sensitivity, SENS_MIN, SENS_MAX))
	_refresh_invert()


func set_account(nickname: String, email: String, offline: bool) -> void:
	name_label.text = nickname
	var line: String = email
	if offline:
		line = (email + "  ·  " if email != "" else "") + "senza connessione"
	account_label.text = line
	account_label.visible = line != ""


func hide_all() -> void:
	menu.visible = false
	hud.visible = false
	results.visible = false
	settings.visible = false
	clear_center()


func _refresh_invert() -> void:
	invert_btn.text = "Inverti sterzo:  " + ("SÌ" if _invert else "NO")


func _toggle_invert() -> void:
	_invert = not _invert
	_refresh_invert()
	_emit_settings()


func _emit_settings() -> void:
	settings_changed.emit(sens_slider.value, _invert)


func open_settings() -> void:
	settings.visible = true


func close_settings() -> void:
	settings.visible = false


# ------------------------------------------------------------- classifica

func _build_results() -> void:
	results = _overlay(0.5)
	var cc: CenterContainer = results.get_meta("center")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	cc.add_child(column)

	results_headline = _label("", 76, YELLOW, 22)
	results_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(results_headline)

	var card := _card(680.0)
	column.add_child(card)
	results_rows = VBoxContainer.new()
	results_rows.add_theme_constant_override("separation", 10)
	card.add_child(results_rows)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	var back := _button("MENU", 36, Color.WHITE, WHITE_DARK, Vector2(240, 96))
	back.pressed.connect(func() -> void: menu_pressed.emit())
	buttons.add_child(back)
	var again := _button("RIGIOCA", 40, YELLOW, YELLOW_DARK, Vector2(340, 96))
	again.pressed.connect(func() -> void: play_pressed.emit())
	buttons.add_child(again)
	results.visible = false


func show_results(rows: Array, player_place: int) -> void:
	## rows: [{name, time_text, color, is_player}], gia' in ordine di arrivo.
	for child in results_rows.get_children():
		results_rows.remove_child(child)
		child.queue_free()
	results_headline.text = "HAI VINTO!" if player_place == 1 else "%d° POSTO" % player_place
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var is_player: bool = row["is_player"]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _margins(_box(YELLOW if is_player else ROW, 20), 22.0, 6.0, 8.0))
		results_rows.add_child(panel)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 18)
		panel.add_child(line)
		var place := _label("%d°" % (i + 1), 40, INK)
		place.custom_minimum_size = Vector2(62, 0)
		line.add_child(place)
		var dot := Panel.new()
		var dot_color: Color = row["color"]
		var dot_sb := _box(dot_color, 18)
		dot_sb.set_border_width_all(4)
		dot_sb.border_color = INK
		dot.add_theme_stylebox_override("panel", dot_sb)
		dot.custom_minimum_size = Vector2(36, 36)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var racer_name: String = row["name"]
		var name_label := _label(racer_name, 36, INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var time_text: String = row["time_text"]
		line.add_child(_label(time_text, 34, INK, 0, false))
	hud.visible = false
	results.visible = true


# ----------------------------------------------------------------- stati

func show_menu() -> void:
	menu.visible = true
	hud.visible = false
	results.visible = false
	settings.visible = false
	clear_center()


func show_race() -> void:
	menu.visible = false
	hud.visible = true
	results.visible = false
	settings.visible = false


func pop(text: String, color: Color = Color.WHITE, font_size: int = 190, fade_after: float = -1.0) -> void:
	## Scritta grande al centro con effetto "rimbalzo" (conto alla rovescia, VIA!, ecc.).
	if _center_tween != null:
		_center_tween.kill()
	center.text = text
	center.add_theme_color_override("font_color", color)
	center.add_theme_font_size_override("font_size", font_size)
	center.pivot_offset = center.size * 0.5
	center.scale = Vector2(1.5, 1.5)
	center.modulate.a = 1.0
	_center_tween = create_tween()
	_center_tween.tween_property(center, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fade_after >= 0.0:
		_center_tween.tween_interval(fade_after)
		_center_tween.tween_property(center, "modulate:a", 0.0, 0.25)


func clear_center() -> void:
	if _center_tween != null:
		_center_tween.kill()
	center.text = ""
