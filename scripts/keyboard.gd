extends Control
## Tastiera del gioco: sostituisce quella di sistema in tutti i campi di testo.
## Compatta, centrata in basso, con lo stile dell'interfaccia.
## Tre disposizioni: lettere, numeri e simboli, tastierino numerico (per i codici).

const LETTERS := [
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", "@"],
	["#shift", "z", "x", "c", "v", "b", "n", "m", ".", "#back"],
	["#symbols", "_", "-", "#space", "#ok"],
]
const SYMBOLS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["!", "?", "#", "$", "%", "&", "*", "+", "=", "/"],
	["(", ")", "'", "\"", ":", ";", ",", "<", ">", "#back"],
	["#letters", "@", ".", "#space", "#ok"],
]
const NUMPAD := [
	["1", "2", "3"],
	["4", "5", "6"],
	["7", "8", "9"],
	["#back", "0", "#ok"],
]

const KEY_H := 62.0
const GAP := 8

var ui: CanvasLayer
var panel: PanelContainer
var rows_box: VBoxContainer
var field: LineEdit
var layout: String = "letters"
var shift: bool = false

var _back_held: bool = false
var _back_timer: float = 0.0


func setup(ui_ref: CanvasLayer) -> void:
	ui = ui_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	var sb: StyleBoxFlat = ui._margins(ui._box(Color(ui.INK, 0.97), 26), 16.0, 14.0, 14.0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", GAP)
	panel.add_child(rows_box)
	visible = false


func is_open() -> bool:
	return visible


func height_units() -> float:
	return panel.size.y if visible else 0.0


func contains(point: Vector2) -> bool:
	return visible and panel.get_global_rect().has_point(point)


func open(target: LineEdit, numeric: bool) -> void:
	field = target
	shift = false
	layout = "numpad" if numeric else "letters"
	visible = true
	_rebuild()


func close(target: LineEdit = null) -> void:
	if target != null and target != field:
		return
	field = null
	visible = false
	_back_held = false


func _process(delta: float) -> void:
	# tenendo premuto CANC si continua a cancellare
	if not _back_held or field == null:
		return
	_back_timer -= delta
	if _back_timer <= 0.0:
		_back_timer = 0.06
		field.delete_char_at_caret()


# ------------------------------------------------------------- disposizione

func _rebuild() -> void:
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	var rows: Array = LETTERS
	var width: float = 940.0
	if layout == "symbols":
		rows = SYMBOLS
	elif layout == "numpad":
		rows = NUMPAD
		width = 420.0
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", GAP)
		rows_box.add_child(line)
		for key: String in row:
			line.add_child(_key(key))
	panel.custom_minimum_size = Vector2(width, 0)
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _key(key: String) -> Button:
	var text: String = key
	var bg: Color = Color.WHITE
	var dark: Color = ui.WHITE_DARK
	var ratio: float = 1.0
	var font_size: int = 32
	match key:
		"#shift":
			text = "ABC" if not shift else "abc"
			bg = ui.YELLOW if shift else Color(0.72, 0.77, 0.88)
			dark = ui.YELLOW_DARK if shift else Color(0.55, 0.60, 0.74)
			font_size = 22
		"#back":
			text = "CANC"
			bg = Color(0.72, 0.77, 0.88)
			dark = Color(0.55, 0.60, 0.74)
			font_size = 22
		"#symbols":
			text = "123"
			bg = Color(0.72, 0.77, 0.88)
			dark = Color(0.55, 0.60, 0.74)
			ratio = 1.5
			font_size = 24
		"#letters":
			text = "abc"
			bg = Color(0.72, 0.77, 0.88)
			dark = Color(0.55, 0.60, 0.74)
			ratio = 1.5
			font_size = 24
		"#space":
			text = "spazio"
			ratio = 4.0
			font_size = 22
		"#ok":
			text = "OK"
			bg = ui.YELLOW
			dark = ui.YELLOW_DARK
			ratio = 2.0 if layout != "numpad" else 1.0
			font_size = 28
		_:
			if shift and layout == "letters":
				text = key.to_upper()
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.custom_minimum_size = Vector2(0, KEY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = ratio
	b.clip_text = true
	b.add_theme_font_override("font", ui.font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	for name_key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(name_key, ui.INK)
	var normal: StyleBoxFlat = ui._margins(ui._box(bg, 14, dark, 5), 2.0, 2.0, 7.0)
	var pressed: StyleBoxFlat = ui._margins(ui._box(bg.darkened(0.15), 14, dark, 2), 2.0, 5.0, 4.0)
	for state: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, normal)
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if key == "#back":
		b.button_down.connect(_back_down)
		b.button_up.connect(_back_up)
	else:
		b.pressed.connect(_press.bind(key))
	return b


# ------------------------------------------------------------------ tasti

func _back_down() -> void:
	if field == null:
		return
	field.delete_char_at_caret()
	_back_held = true
	_back_timer = 0.4


func _back_up() -> void:
	_back_held = false


func _press(key: String) -> void:
	if field == null:
		return
	match key:
		"#shift":
			shift = not shift
			_rebuild()
		"#symbols":
			layout = "symbols"
			_rebuild()
		"#letters":
			layout = "letters"
			_rebuild()
		"#space":
			field.insert_text_at_caret(" ")
		"#ok":
			var target: LineEdit = field
			target.text_submitted.emit(target.text)
			if is_instance_valid(target) and target.has_focus():
				target.release_focus()
		_:
			var ch: String = key
			if shift and layout == "letters":
				ch = key.to_upper()
			field.insert_text_at_caret(ch)
			if shift and layout == "letters":
				shift = false
				_rebuild()
