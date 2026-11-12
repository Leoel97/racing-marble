extends Control
## Schermate dell'account: accesso, registrazione, verifica con codice.
## Quando compare la tastiera il contenuto scorre per tenere visibile il campo attivo.

signal login_requested(email: String, password: String)
signal register_requested(nickname: String, email: String, password: String)
signal verify_requested(email: String, code: String)
signal resend_requested(email: String)

var ui: CanvasLayer
var scroll: ScrollContainer
var holder: CenterContainer
var pages: Dictionary = {}
var error_label: Label
var busy_label: Label
var action_buttons: Array[Button] = []

var login_email: LineEdit
var login_password: LineEdit
var reg_nickname: LineEdit
var reg_email: LineEdit
var reg_password: LineEdit
var verify_code: LineEdit
var verify_text: Label
var verify_email: String = ""

var _kb_units: float = 0.0


func setup(ui_ref: CanvasLayer) -> void:
	ui = ui_ref
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(ui.INK, 0.45)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	holder = CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)

	var card: PanelContainer = ui._card(640.0)
	holder.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	_build_login(column)
	_build_register(column)
	_build_verify(column)

	error_label = ui._label("", 24, Color(0.85, 0.16, 0.22), 0, false)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.custom_minimum_size = Vector2(560, 0)
	column.add_child(error_label)
	busy_label = ui._label("Un attimo…", 24, ui.INK.lightened(0.3), 0, false)
	busy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(busy_label)

	resized.connect(_fit)
	_fit()
	visible = false


func _fit() -> void:
	holder.custom_minimum_size = Vector2(0, size.y)


func _process(_delta: float) -> void:
	if not visible:
		return
	# la tastiera copre meta' schermo: accorcia l'area e lascia scorrere il contenuto
	var win_h: float = float(DisplayServer.window_get_size().y)
	var units: float = 0.0
	if win_h > 0.0:
		units = float(DisplayServer.virtual_keyboard_get_height()) * size.y / win_h
	if absf(units - _kb_units) > 1.0:
		_kb_units = units
		scroll.offset_bottom = -units


# --------------------------------------------------------------- mattoncini

func _field(placeholder: String, keyboard: int, secret: bool, max_len: int) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.secret = secret
	f.max_length = max_len
	f.virtual_keyboard_type = keyboard as LineEdit.VirtualKeyboardType
	f.custom_minimum_size = Vector2(560, 68)
	f.add_theme_font_override("font", ui.font_semi)
	f.add_theme_font_size_override("font_size", 30)
	f.add_theme_color_override("font_color", ui.INK)
	f.add_theme_color_override("font_placeholder_color", ui.INK.lightened(0.5))
	f.add_theme_color_override("caret_color", ui.INK)
	var normal: StyleBoxFlat = ui._margins(ui._box(ui.ROW, 18), 22.0, 8.0, 8.0)
	var focus: StyleBoxFlat = ui._margins(ui._box(Color.WHITE, 18), 22.0, 8.0, 8.0)
	focus.set_border_width_all(4)
	focus.border_color = ui.YELLOW_DARK
	f.add_theme_stylebox_override("normal", normal)
	f.add_theme_stylebox_override("focus", focus)
	return f


func _title(text: String) -> Label:
	var l: Label = ui._label(text, 44, ui.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _link(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", ui.font_semi)
	b.add_theme_font_size_override("font_size", 25)
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color(0.20, 0.36, 0.72))
	b.add_theme_color_override("font_pressed_color", ui.INK)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	return b


func _action(text: String) -> Button:
	var b: Button = ui._button(text, 38, ui.YELLOW, ui.YELLOW_DARK, Vector2(0, 92))
	action_buttons.append(b)
	return b


func _page(parent: Control, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	pages[key] = box
	return box


# ----------------------------------------------------------------- pagine

func _build_login(parent: Control) -> void:
	var box := _page(parent, "login")
	box.add_child(_title("ACCEDI"))
	login_email = _field("Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS, false, 120)
	box.add_child(login_email)
	login_password = _field("Password", LineEdit.KEYBOARD_TYPE_PASSWORD, true, 72)
	box.add_child(login_password)
	var go := _action("ENTRA")
	go.pressed.connect(_submit_login)
	box.add_child(go)
	login_password.text_submitted.connect(func(_t: String) -> void: _submit_login())
	var link := _link("Non hai un account? Registrati")
	link.pressed.connect(open_register)
	box.add_child(link)


func _build_register(parent: Control) -> void:
	var box := _page(parent, "register")
	box.add_child(_title("CREA IL TUO ACCOUNT"))
	reg_nickname = _field("Nickname (da 3 a 16 caratteri)", LineEdit.KEYBOARD_TYPE_DEFAULT, false, 16)
	box.add_child(reg_nickname)
	reg_email = _field("Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS, false, 120)
	box.add_child(reg_email)
	reg_password = _field("Password", LineEdit.KEYBOARD_TYPE_PASSWORD, true, 72)
	box.add_child(reg_password)
	var hint: Label = ui._label("Almeno 8 caratteri con maiuscole, minuscole, numeri e simboli", 20, ui.INK.lightened(0.35), 0, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var go := _action("REGISTRATI")
	go.pressed.connect(_submit_register)
	box.add_child(go)
	var link := _link("Hai già un account? Accedi")
	link.pressed.connect(open_login)
	box.add_child(link)


func _build_verify(parent: Control) -> void:
	var box := _page(parent, "verify")
	box.add_child(_title("CONTROLLA LA MAIL"))
	verify_text = ui._label("", 26, ui.INK, 0, false)
	verify_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verify_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verify_text.custom_minimum_size = Vector2(560, 0)
	box.add_child(verify_text)
	verify_code = _field("Codice a 8 cifre", LineEdit.KEYBOARD_TYPE_NUMBER, false, 8)
	verify_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(verify_code)
	var go := _action("CONFERMA")
	go.pressed.connect(_submit_verify)
	box.add_child(go)
	var again := _link("Non è arrivato? Invia di nuovo il codice")
	again.pressed.connect(func() -> void: resend_requested.emit(verify_email))
	box.add_child(again)
	var back := _link("Torna all'accesso")
	back.pressed.connect(open_login)
	box.add_child(back)


func _show_page(key: String) -> void:
	for k: String in pages:
		var page: Control = pages[k]
		page.visible = (k == key)
	show_error("")
	set_busy(false)
	visible = true


func open_login() -> void:
	_show_page("login")


func open_register() -> void:
	_show_page("register")


func open_verify(email: String) -> void:
	verify_email = email
	verify_text.text = "Ti abbiamo mandato un codice a 8 cifre a\n%s\nScrivilo qui sotto per attivare l'account." % email
	verify_code.text = ""
	_show_page("verify")


func close() -> void:
	visible = false
	login_password.text = ""
	reg_password.text = ""
	DisplayServer.virtual_keyboard_hide()


func show_error(text: String) -> void:
	error_label.text = text
	error_label.visible = text != ""


func show_info(text: String) -> void:
	show_error(text)


func set_busy(busy: bool) -> void:
	busy_label.visible = busy
	for b in action_buttons:
		b.disabled = busy
	if busy:
		error_label.visible = false


# ------------------------------------------------------------- controlli

func _valid_email(text: String) -> bool:
	var at: int = text.find("@")
	return at > 0 and text.rfind(".") > at + 1 and not text.ends_with(".") and text.find(" ") < 0


func _valid_password(text: String) -> bool:
	if text.length() < 8:
		return false
	var lower: bool = false
	var upper: bool = false
	var digit: bool = false
	var symbol: bool = false
	for i in range(text.length()):
		var ch: String = text[i]
		if ch >= "a" and ch <= "z":
			lower = true
		elif ch >= "A" and ch <= "Z":
			upper = true
		elif ch >= "0" and ch <= "9":
			digit = true
		else:
			symbol = true
	return lower and upper and digit and symbol


func _submit_login() -> void:
	var email: String = login_email.text.strip_edges()
	if not _valid_email(email):
		show_error("Scrivi un indirizzo email valido.")
		return
	if login_password.text == "":
		show_error("Scrivi la password.")
		return
	login_requested.emit(email, login_password.text)


func _submit_register() -> void:
	var nick: String = reg_nickname.text.strip_edges()
	var email: String = reg_email.text.strip_edges()
	if nick.length() < 3:
		show_error("Il nickname deve avere almeno 3 caratteri.")
		return
	if not _valid_email(email):
		show_error("Scrivi un indirizzo email valido.")
		return
	if not _valid_password(reg_password.text):
		show_error("La password deve avere almeno 8 caratteri con maiuscole, minuscole, numeri e simboli.")
		return
	register_requested.emit(nick, email, reg_password.text)


func _submit_verify() -> void:
	var code: String = verify_code.text.strip_edges()
	if code.length() < 6:
		show_error("Scrivi il codice che hai ricevuto via mail.")
		return
	verify_requested.emit(verify_email, code)
