extends Control
## Schermata "La mia biglia": materiale, motivo, colori e animazione al traguardo.
## Gli elementi bloccati mostrano il lucchetto e le vittorie necessarie; toccandoli
## si vede l'anteprima sulla biglia ma non si possono tenere.

signal previewed(config: Dictionary)
signal finish_previewed(id: String)
signal saved(config: Dictionary)

const Catalog := preload("res://scripts/catalog.gd")
const Icons := preload("res://scripts/icons.gd")

const TABS := [["material", "MATERIALE"], ["pattern", "MOTIVO"], ["colors", "COLORI"], ["finish", "TRAGUARDO"]]

var ui: CanvasLayer
var wins: int = 0
var config: Dictionary = {}
var tab: String = "material"

var wins_label: Label
var info_label: Label
var tab_buttons: Dictionary = {}
var content: VBoxContainer
var scroll: ScrollContainer
var _press_scroll: int = 0


func setup(ui_ref: CanvasLayer) -> void:
	ui = ui_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card: PanelContainer = ui._card(0.0)
	add_child(card)
	card.anchor_left = 0.5
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = -70.0
	card.offset_right = -36.0
	card.offset_top = 22.0
	card.offset_bottom = -22.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	var title: Label = ui._label("LA MIA BIGLIA", 40, ui.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", ui._margins(ui._box(ui.YELLOW, 22), 20.0, 4.0, 6.0))
	head.add_child(pill)
	wins_label = ui._label("", 28, ui.INK)
	pill.add_child(wins_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for t: Array in TABS:
		var key: String = t[0]
		var label: String = t[1]
		var b: Button = ui._button(label, 23, ui.ROW, ui.WHITE_DARK, Vector2(0, 64))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_open_tab.bind(key))
		tabs.add_child(b)
		tab_buttons[key] = b

	scroll = ScrollContainer.new()
	scroll.scroll_deadzone = 12
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	# un po' di spazio attorno alla lista: gli elementi arrotondati (e le loro ombre)
	# non toccano i bordi dritti dell'area che scorre
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(pad)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	pad.add_child(content)

	info_label = ui._label("", 24, ui.INK, 0, false)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0, 34)
	column.add_child(info_label)

	var done: Button = ui._button("FATTO", 38, ui.YELLOW, ui.YELLOW_DARK, Vector2(0, 88))
	done.pressed.connect(_done)
	column.add_child(done)
	visible = false


func open(current: Dictionary, total_wins: int) -> void:
	config = current.duplicate()
	wins = total_wins
	wins_label.text = "Vittorie: %d" % wins
	visible = true
	_open_tab(tab)


func _done() -> void:
	visible = false
	saved.emit(config)


func _open_tab(key: String) -> void:
	tab = key
	for k: String in tab_buttons:
		var b: Button = tab_buttons[k]
		var active: bool = k == key
		var bg: Color = ui.YELLOW if active else ui.ROW
		var dark: Color = ui.YELLOW_DARK if active else ui.WHITE_DARK
		var sb: StyleBoxFlat = ui._margins(ui._box(bg, 20, dark, 6), 10.0, 6.0, 12.0)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, sb)
	info_label.text = ""
	previewed.emit(config)
	_rebuild()
	scroll.set_deferred("scroll_vertical", 0)


func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	## Ricostruisce la lista senza perdere il punto in cui si era arrivati scorrendo.
	var keep: int = scroll.scroll_vertical
	_clear()
	_fill()
	scroll.set_deferred("scroll_vertical", keep)


func _fill() -> void:
	if tab == "colors":
		_color_row("Colore principale", "color_a")
		_color_row("Colore secondario", "color_b")
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var list: Array = Catalog.GROUPS[tab]
	for item: Dictionary in list:
		grid.add_child(_item_card(item))


func _item_card(item: Dictionary) -> Button:
	var id: String = item["id"]
	var need: int = item["wins"]
	var item_name: String = item["name"]
	var unlocked: bool = wins >= need
	var selected: bool = str(config.get(tab, "")) == id
	var bg: Color = ui.YELLOW if selected else (ui.ROW if unlocked else Color(0.80, 0.82, 0.87))
	var dark: Color = ui.YELLOW_DARK if selected else ui.WHITE_DARK.darkened(0.0 if unlocked else 0.12)
	var b: Button = ui._button(item_name, 28, bg, dark, Vector2(0, 104))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not unlocked:
		b.text = "%s\n%d vittorie" % [item_name, need]
		b.icon = Icons.lock(44, ui.INK.lightened(0.25))
		b.add_theme_constant_override("h_separation", 12)
		b.add_theme_font_size_override("font_size", 24)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, ui.INK.lightened(0.25))
	_scroll_friendly(b)
	b.pressed.connect(_pick_if_tap.bind(id))
	return b


func _scroll_friendly(b: Button) -> void:
	## Lascia passare il trascinamento alla lista, cosi' si scorre anche partendo da un bottone.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.button_down.connect(func() -> void: _press_scroll = scroll.scroll_vertical)


func _was_tap() -> bool:
	return absi(scroll.scroll_vertical - _press_scroll) < 10


func _pick_if_tap(id: String) -> void:
	if _was_tap():
		_pick(id)


func _pick(id: String) -> void:
	var item: Dictionary = Catalog.find(tab, id)
	var need: int = item["wins"]
	var item_name: String = item["name"]
	if wins >= need:
		config[tab] = id
		info_label.text = ""
		previewed.emit(config)
		_rebuild()
	else:
		# anteprima di un elemento bloccato: si vede, ma non viene tenuto
		var temp: Dictionary = config.duplicate()
		temp[tab] = id
		var missing: int = need - wins
		info_label.text = "%s si sblocca con %d vittorie: te ne %s %d." % [item_name, need, "manca" if missing == 1 else "mancano", missing]
		previewed.emit(temp)
	if tab == "finish":
		finish_previewed.emit(id)


func _color_row(title: String, key: String) -> void:
	content.add_child(ui._label(title, 28, ui.INK, 0, false))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	content.add_child(flow)
	for hex: String in Catalog.COLORS:
		var selected: bool = str(config.get(key, "")) == hex
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, 76)
		b.icon = Icons.dot(60, Color(hex), ui.INK, 5.0)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb: StyleBoxFlat = ui._box(ui.YELLOW if selected else Color(1, 1, 1, 0), 22)
		for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(state, sb)
		_scroll_friendly(b)
		b.pressed.connect(_pick_color_if_tap.bind(key, hex))
		flow.add_child(b)


func _pick_color_if_tap(key: String, hex: String) -> void:
	if _was_tap():
		_pick_color(key, hex)


func _pick_color(key: String, hex: String) -> void:
	config[key] = hex
	previewed.emit(config)
	_rebuild()
