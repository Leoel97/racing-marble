extends RefCounted
## Catalogo delle personalizzazioni della biglia e regole di sblocco.
## "wins" e' il numero di vittorie totali (primi posti) necessario.

const MATERIALS := [
	{"id": "vetro", "name": "Vetro", "wins": 0},
	{"id": "gomma", "name": "Gomma", "wins": 0},
	{"id": "metallo", "name": "Metallo", "wins": 3},
	{"id": "perla", "name": "Perla", "wins": 8},
	{"id": "cromo", "name": "Cromo", "wins": 15},
	{"id": "oro", "name": "Oro", "wins": 30},
	{"id": "galassia", "name": "Galassia", "wins": 50},
	{"id": "lava", "name": "Lava", "wins": 75},
]

const PATTERNS := [
	{"id": "spirale", "name": "Spirale", "wins": 0},
	{"id": "strisce", "name": "Strisce", "wins": 0},
	{"id": "tinta", "name": "Tinta unita", "wins": 0},
	{"id": "pois", "name": "Pois", "wins": 2},
	{"id": "onde", "name": "Onde", "wins": 5},
	{"id": "scacchi", "name": "Scacchi", "wins": 10},
	{"id": "occhio", "name": "Occhio di gatto", "wins": 20},
	{"id": "stelle", "name": "Stelle", "wins": 40},
]

const FINISHES := [
	{"id": "salto", "name": "Saltello", "wins": 0},
	{"id": "trottola", "name": "Trottola", "wins": 4},
	{"id": "coriandoli", "name": "Coriandoli", "wins": 12},
	{"id": "stelle", "name": "Pioggia di stelle", "wins": 25},
	{"id": "fuochi", "name": "Fuochi d'artificio", "wins": 60},
]

# i colori sono tutti liberi da subito
const COLORS := [
	"e63946", "f58433", "ffd23f", "2ec4a6", "457bcc", "9966cc",
	"fa99b3", "ffffff", "8d99ae", "20263a",
]

const GROUPS := {"material": MATERIALS, "pattern": PATTERNS, "finish": FINISHES}
const GROUP_NAMES := {"material": "Materiale", "pattern": "Motivo", "finish": "Traguardo"}


static func default_config() -> Dictionary:
	return {"material": "vetro", "pattern": "spirale", "finish": "salto", "color_a": "e63946", "color_b": "ffffff"}


static func find(group: String, id: String) -> Dictionary:
	var list: Array = GROUPS[group]
	for item: Dictionary in list:
		if item["id"] == id:
			return item
	return list[0]


static func is_unlocked(group: String, id: String, wins: int) -> bool:
	var need: int = find(group, id)["wins"]
	return wins >= need


static func sanitize(config: Dictionary, wins: int) -> Dictionary:
	## Tiene solo scelte valide e gia' sbloccate.
	var out: Dictionary = default_config()
	for group: String in GROUPS:
		var id: String = str(config.get(group, out[group]))
		var item: Dictionary = find(group, id)
		if item["id"] == id and is_unlocked(group, id, wins):
			out[group] = id
	for key: String in ["color_a", "color_b"]:
		var value: String = str(config.get(key, out[key]))
		if COLORS.has(value):
			out[key] = value
	return out


static func unlockables() -> Array:
	## Tutto cio' che richiede vittorie, in ordine crescente.
	var out: Array = []
	for group: String in GROUPS:
		var list: Array = GROUPS[group]
		for item: Dictionary in list:
			var need: int = item["wins"]
			if need > 0:
				out.append({"group": group, "id": item["id"], "name": item["name"], "wins": need})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wa: int = a["wins"]
		var wb: int = b["wins"]
		return wa < wb)
	return out


static func newly_unlocked(old_wins: int, new_wins: int) -> Array:
	var out: Array = []
	for item: Dictionary in unlockables():
		var need: int = item["wins"]
		if need > old_wins and need <= new_wins:
			out.append(item)
	return out


static func random_config(rng: RandomNumberGenerator, color_a: String) -> Dictionary:
	## Aspetto casuale per gli avversari guidati dal gioco.
	var mats: Array = ["vetro", "gomma", "metallo", "perla"]
	var pats: Array = ["spirale", "strisce", "pois", "onde", "scacchi"]
	return {
		"material": mats[rng.randi() % mats.size()],
		"pattern": pats[rng.randi() % pats.size()],
		"finish": "salto", "color_a": color_a, "color_b": "ffffff",
	}
