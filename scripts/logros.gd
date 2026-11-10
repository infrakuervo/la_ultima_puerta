extends RefCounted
## Logros y estadísticas, solo vista/persistencia. Lista en data/logros.json; aquí van las
## condiciones, leídas de los eventos y del estado de la simulación. Algunos logros abren
## dones nuevos del draft (campo unlock), así la progresión meta trae contenido, no solo números.

const DATA_PATH: String = "res://data/logros.json"

var list: Array = []
var got: Dictionary = {}          # id -> true
var stats: Dictionary = {"partidas": 0, "victorias": 0, "bajas": 0, "oleadas": 0, "mejor_brasa": 0}
var run: Dictionary = {}          # estado de la partida en curso
var fresh: Array = []             # logros conseguidos en esta partida (para la pantalla final)


func _init() -> void:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			list = d.get("list", [])
	new_run()


func new_run() -> void:
	run = {"door_hit": false, "augur_all": true, "brasa_best": 0, "augurs": 0}
	fresh.clear()


func def(id: String) -> Dictionary:
	for l in list:
		if String(l["id"]) == id:
			return l
	return {}


## Ids de dones abiertos por los logros conseguidos.
func unlocked_boons() -> Array:
	var out: Array = []
	for l in list:
		if got.has(String(l["id"])) and l.has("unlock"):
			out.append(String(l["unlock"]))
	return out


func to_save() -> Dictionary:
	return {"logros": got.keys(), "stats": stats}


func from_save(d: Dictionary) -> void:
	for id in d.get("logros", []):
		got[String(id)] = true
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[String(k)] = int(st[k])


## Comprueba un evento. Devuelve los ids conseguidos ahora (vacío casi siempre).
## challenge: hay reto semanal en curso.
func on_event(sim, ev: Dictionary, challenge: bool) -> Array:
	var out: Array = []
	match String(ev["t"]):
		"wave_start":
			if int(ev["wave"]) == 1:
				new_run()
				stats["partidas"] = int(stats["partidas"]) + 1
			elif sim.augur == "" and sim.augurs_enabled:
				run["augur_all"] = false
			if sim.augur != "":
				run["augurs"] = int(run.get("augurs", 0)) + 1
			_try(out, "manada", _alive(sim) >= 6)
		"wave_clear":
			stats["oleadas"] = int(stats["oleadas"]) + 1
			_try(out, "primera_sangre", true)
			if sim.is_endless():
				_try(out, "abismo", int(ev["wave"]) >= 10)
				_try(out, "mas_alla", int(ev["wave"]) >= 20)
		"kill":
			stats["bajas"] = int(stats["bajas"]) + 1
		"door_hit":
			run["door_hit"] = true
		"brasa_land":
			var h: int = int(ev["hits"])
			run["brasa_best"] = maxi(int(run["brasa_best"]), h)
			stats["mejor_brasa"] = maxi(int(stats["mejor_brasa"]), h)
			_try(out, "brasa_perfecta", h >= 8)
		"bought", "draft_pick":
			_try(out, "manada", _alive(sim) >= 6)
		"revived":
			var t: Dictionary = sim.named_creature()
			_try(out, "cicatrices", not t.is_empty() and int(t["scars"]) >= 3)
		"form_seen":
			_try(out, "coleccionista", sim.seen_forms.size() >= 10)
		"skill":
			_try(out, "arquitecto", sim.skill_points_spent() >= 50)
		"victory":
			stats["victorias"] = int(stats["victorias"]) + 1
			var sid: String = sim.siege_id()
			_try(out, "puerta_resiste", sid == "primer")
			_try(out, "alba_rota", sid == "alba")
			_try(out, "ira_encendida", sim.wrath >= 3)
			_try(out, "intocable", not bool(run["door_hit"]))
			_try(out, "supersticioso", bool(run["augur_all"]) and sim.augurs_enabled)
			_try(out, "semanal", challenge)
	return out


func _try(out: Array, id: String, cond: bool) -> void:
	if cond and not got.has(id) and not def(id).is_empty():
		got[id] = true
		fresh.append(id)
		out.append(id)


func _alive(sim) -> int:
	var n: int = 0
	for c in sim.creatures:
		if not c["dead"]:
			n += 1
	return n
