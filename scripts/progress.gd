extends Node
## Progressi del giocatore salvati sul telefono, separati per account:
## aspetto della biglia e vittorie (quelle gia' sul profilo + quelle ancora da caricare).

const Catalog := preload("res://scripts/catalog.gd")

var user_id: String = ""
var wins_synced: int = 0
var pending: int = 0
var config: Dictionary = Catalog.default_config()


func total_wins() -> int:
	## Le vittorie le decide il server: qui c'e' solo l'ultima copia letta dal profilo.
	return wins_synced


func _path() -> String:
	return "user://progress_%s.cfg" % user_id.md5_text().substr(0, 12)


func load_for(new_user_id: String) -> void:
	user_id = new_user_id
	wins_synced = 0
	pending = 0
	config = Catalog.default_config()
	var cfg := ConfigFile.new()
	if cfg.load(_path()) == OK:
		wins_synced = int(cfg.get_value("wins", "synced", 0))
		pending = int(cfg.get_value("wins", "pending", 0))
		var saved: Variant = cfg.get_value("marble", "config", {})
		if typeof(saved) == TYPE_DICTIONARY:
			config = saved
	config = Catalog.sanitize(config, total_wins())


func save() -> void:
	if user_id == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("wins", "synced", wins_synced)
	cfg.set_value("wins", "pending", pending)
	cfg.set_value("marble", "config", config)
	cfg.save(_path())


func set_wins(total: int) -> void:
	wins_synced = maxi(total, 0)
	pending = 0
	save()


func set_config(new_config: Dictionary) -> void:
	config = Catalog.sanitize(new_config, total_wins())
	save()
