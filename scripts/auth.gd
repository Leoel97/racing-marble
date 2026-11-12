extends Node
## Account su Supabase: registrazione, accesso, verifica con codice, sessione salvata.
## Si usa solo l'autenticazione (nessuna tabella): il nickname sta nei dati dell'account.
## La chiave qui sotto e' quella pubblica ("publishable"), fatta per stare dentro l'app.

const SUPABASE_URL := "https://bctlvffqnyqcvifdqrmr.supabase.co"
const SUPABASE_KEY := "sb_publishable_zWj_l4cHdPhJJaq92YzBfQ_Oj7KPWDL"
const SESSION_PATH := "user://session.cfg"

var user_id: String = ""
var email: String = ""
var nickname: String = ""
var access_token: String = ""
var refresh_token: String = ""
var expires_at: float = 0.0
var offline: bool = false


func is_logged_in() -> bool:
	return user_id != ""


# ----------------------------------------------------------------- azioni

func sign_up(new_nickname: String, new_email: String, password: String) -> Dictionary:
	var res: Dictionary = await _post("/auth/v1/signup", {
		"email": new_email, "password": password, "data": {"nickname": new_nickname},
	})
	if not _succeeded(res):
		return _failure(res)
	var data: Dictionary = res["data"]
	if data.has("access_token"):
		_apply_session(data)
		return {"ok": true}
	# account creato ma da confermare con il codice arrivato via mail
	return {"ok": false, "needs_verify": true, "error": ""}


func sign_in(login_email: String, password: String) -> Dictionary:
	var res: Dictionary = await _post("/auth/v1/token?grant_type=password", {"email": login_email, "password": password})
	if not _succeeded(res):
		return _failure(res)
	_apply_session(res["data"])
	return {"ok": true}


func verify(verify_email: String, code: String) -> Dictionary:
	var res: Dictionary = await _post("/auth/v1/verify", {"type": "signup", "email": verify_email, "token": code})
	if not _succeeded(res):
		return _failure(res)
	var data: Dictionary = res["data"]
	if not data.has("access_token"):
		return {"ok": false, "needs_verify": false, "error": "Codice non valido."}
	_apply_session(data)
	return {"ok": true}


func resend(verify_email: String) -> Dictionary:
	var res: Dictionary = await _post("/auth/v1/resend", {"type": "signup", "email": verify_email})
	if not _succeeded(res):
		return _failure(res)
	return {"ok": true}


func restore() -> void:
	## All'avvio: riprende la sessione salvata. Senza rete si resta dentro con i dati salvati.
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return
	var saved_refresh: String = str(cfg.get_value("session", "refresh_token", ""))
	if saved_refresh == "":
		return
	var res: Dictionary = await _post("/auth/v1/token?grant_type=refresh_token", {"refresh_token": saved_refresh})
	if _succeeded(res):
		_apply_session(res["data"])
		return
	var reached: bool = res["network"]
	if reached:
		_clear()          # sessione scaduta o revocata: bisogna rifare l'accesso
		return
	user_id = str(cfg.get_value("session", "user_id", ""))
	email = str(cfg.get_value("session", "email", ""))
	nickname = str(cfg.get_value("session", "nickname", ""))
	refresh_token = saved_refresh
	offline = true


func sign_out() -> void:
	if access_token != "":
		await _post("/auth/v1/logout", {}, access_token)
	_clear()


func use_local_profile(local_nickname: String) -> void:
	## Solo per i test automatici: entra senza passare da Supabase.
	user_id = "local"
	nickname = local_nickname
	offline = true


# ---------------------------------------------------------------- interni

func _apply_session(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	expires_at = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	var user: Dictionary = data.get("user", {})
	user_id = str(user.get("id", ""))
	email = str(user.get("email", ""))
	var meta: Dictionary = user.get("user_metadata", {})
	nickname = str(meta.get("nickname", ""))
	if nickname == "":
		nickname = email.get_slice("@", 0)
	offline = false
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.set_value("session", "user_id", user_id)
	cfg.set_value("session", "email", email)
	cfg.set_value("session", "nickname", nickname)
	cfg.save(SESSION_PATH)


func _clear() -> void:
	user_id = ""
	email = ""
	nickname = ""
	access_token = ""
	refresh_token = ""
	offline = false
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func _succeeded(res: Dictionary) -> bool:
	var reached: bool = res["network"]
	var code: int = res["code"]
	return reached and code >= 200 and code < 300


func _failure(res: Dictionary) -> Dictionary:
	var reached: bool = res["network"]
	if not reached:
		return {"ok": false, "needs_verify": false, "error": "Nessuna connessione. Controlla internet e riprova."}
	var data: Dictionary = res["data"]
	var code: String = str(data.get("error_code", data.get("error", "")))
	var raw: String = str(data.get("msg", data.get("error_description", data.get("message", ""))))
	var http_code: int = res["code"]
	var text: String = ""
	match code:
		"invalid_credentials", "invalid_grant":
			text = "Email o password non corretti."
		"email_not_confirmed":
			return {"ok": false, "needs_verify": true, "error": ""}
		"user_already_exists", "email_exists":
			text = "Esiste già un account con questa email."
		"weak_password":
			text = "Password troppo debole: servono 8 caratteri con maiuscole, minuscole, numeri e simboli."
		"otp_expired", "otp_disabled":
			text = "Codice errato o scaduto."
		"over_email_send_rate_limit", "over_request_rate_limit":
			text = "Troppe richieste. Riprova tra qualche minuto."
		"email_address_invalid", "validation_failed":
			text = "Controlla i dati inseriti."
		"signup_disabled":
			text = "Le registrazioni sono chiuse."
		_:
			if raw.findn("already registered") >= 0:
				text = "Esiste già un account con questa email."
			elif raw.findn("not confirmed") >= 0:
				return {"ok": false, "needs_verify": true, "error": ""}
			elif raw.findn("invalid login") >= 0:
				text = "Email o password non corretti."
			else:
				text = "Qualcosa è andato storto (errore %d). Riprova." % http_code
	return {"ok": false, "needs_verify": false, "error": text, "code": code}


func _post(path: String, body: Dictionary, bearer: String = "") -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + SUPABASE_KEY])
	if bearer != "":
		headers.append("Authorization: Bearer " + bearer)
	var err: int = req.request(SUPABASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"network": false, "code": 0, "data": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	var data: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	return {"network": result == HTTPRequest.RESULT_SUCCESS, "code": code, "data": data}
