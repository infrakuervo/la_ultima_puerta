extends RefCounted
## Lógica pura de La Última Puerta: sin dibujo ni audio.
## La vista (main.gd) lee el estado y consume `events`; los tests lo manejan directamente.
## Todos los números salen de res://data/balance.json y res://data/waves.json.

const TICK: float = 1.0 / 30.0

var B: Dictionary = {}
var WAVES: Array = []
var ROUTES: Dictionary = {}
var SIEGES: Array = []           # data/waves.json -> sieges: [{id, name, waves, unlock}]
var siege_index: int = 0
var wrath: int = 0               # nivel de Ira: enemigos más duros, más esencia
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Estado de la partida
var phase: String = "prep"      # prep | combat | route | forge | victory | defeat
var wave_index: int = 0         # índice de la oleada actual o siguiente (0-based)
var defeat_wave: int = 0
var door_hp: float = 100.0
var door_max: float = 100.0
var souls: int = 0
var creatures: Array = []
var enemies: Array = []
var zones: Array = []
var spawn_queue: Array = []
var wave_time: float = 0.0
var events: Array = []
var route: String = ""
var relic: String = ""
var next_id: int = 1
var brasa_cd: float = 0.0
var rayo_cd: float = 0.0
var pending_brasas: Array = []
var tar_pools: Array = []        # charcos de brea del Sapo: {p, r, t}
var draft_enabled: bool = false  # tras cada oleada se elige 1 de 3
var draft: Array = []
var meta_mode: bool = false      # árbol permanente: se paga con esencia y se conserva entre partidas
var essence: int = 0
var skills: Dictionary = {}      # id de habilidad -> rango comprado
var SK: Dictionary = {}          # id -> definición (data/skills.json)
var SK_ORDER: Array = []
var BRANCHES: Array = []
var _fx_cache: Dictionary = {}
var _fx_valid: bool = false
var _stat_cache: Dictionary = {}
var kills: int = 0
var seen_forms: Array = []       # formas vistas (bestiario); la vista lo persiste
var message: String = ""
var remix_enabled: bool = false  # oleadas remezcladas por partida (la vista y el bot lo activan)
var augurs_enabled: bool = false # augurios a elegir antes de cada oleada
var augur: String = ""           # augurio elegido para la oleada actual o siguiente ("" = Calma)
var augur_offer: Array = []      # ids ofrecidos en esta preparación
var _front_lane: int = -1
var week_augur: String = ""      # reto semanal: augurio que dura toda la partida
var boons: Array = []            # dones de la partida elegidos en el draft (ids del pool)


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	B = load_json("res://data/balance.json")
	var w: Dictionary = load_json("res://data/waves.json")
	if w.has("sieges"):
		SIEGES = w["sieges"]
	else:
		SIEGES = [{"id": "primer", "name": "Primer asedio", "waves": w["waves"]}]
	WAVES = SIEGES[0]["waves"]
	ROUTES = w["routes"]
	var sk: Dictionary = load_json("res://data/skills.json")
	BRANCHES = sk["branches"]
	for nd in sk["nodes"]:
		SK[nd["id"]] = nd
		SK_ORDER.append(nd["id"])
	reset()


static func load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return {}
	return JSON.parse_string(f.get_as_text())


## Elige asedio y nivel de Ira para la próxima partida (llamar antes de reset()).
func set_siege(i: int, wrath_level: int = 0) -> void:
	siege_index = clampi(i, 0, SIEGES.size() - 1)
	WAVES = SIEGES[siege_index]["waves"]
	wrath = clampi(wrath_level, 0, int(B["wrath"]["max"]))


func siege_id() -> String:
	return String(SIEGES[siege_index]["id"])


func siege_name() -> String:
	return String(SIEGES[siege_index]["name"])


func wrath_hp() -> float:
	return 1.0 + float(B["wrath"]["hp"]) * float(wrath)


func wrath_dmg() -> float:
	return 1.0 + float(B["wrath"]["dmg"]) * float(wrath)


func reset() -> void:
	phase = "prep"
	boons.clear()
	wave_index = 0
	defeat_wave = 0
	if not meta_mode:
		skills.clear()
	_invalidate()
	door_max = float(B["door"]["hp"]) * (1.0 + fmul("door.hp"))
	door_hp = door_max
	souls = int(B["economy"]["start_souls"])
	creatures.clear()
	enemies.clear()
	zones.clear()
	spawn_queue.clear()
	events.clear()
	route = ""
	relic = ""
	next_id = 1
	brasa_cd = 0.0
	rayo_cd = 0.0
	pending_brasas.clear()
	tar_pools.clear()
	draft.clear()
	kills = 0
	wave_time = 0.0
	augur = ""
	augur_offer.clear()
	WAVES = SIEGES[siege_index]["waves"]
	if is_endless():
		var base: Dictionary = SIEGES[_siege_by_id(String(SIEGES[siege_index]["endless"]["base_siege"]))].duplicate()
		base["remix"] = SIEGES[siege_index].get("remix", {})
		WAVES = _remix_waves(base) if remix_enabled else base["waves"].duplicate(true)
	elif remix_enabled:
		WAVES = _remix_waves(SIEGES[siege_index])
	var tizon: Dictionary = _new_creature("sabueso", {"x": 520.0, "lane": 1})
	tizon["name"] = "Tizón"
	tizon["named"] = true
	creatures.append(tizon)
	_note_seen("sabueso")
	message = "Coloca a tus monstruos y pulsa «Iniciar oleada»."


# ----------------------------------------------------------------------------
# Consultas
# ----------------------------------------------------------------------------

func label(kind: String) -> String:
	return String(B["labels"].get(kind, kind))


func wave_count() -> int:
	return WAVES.size()


func is_endless() -> bool:
	return SIEGES[siege_index].has("endless")


func current_wave() -> Dictionary:
	return WAVES[mini(wave_index, WAVES.size() - 1)]


func lane_y(lane: int) -> float:
	return float(B["arena"]["lane_y"][lane])


func demon_pos() -> Vector2:
	return Vector2(float(B["arena"]["door_x"]) + 10.0, lane_y(1))


func epos(e: Dictionary) -> Vector2:
	return Vector2(float(e["x"]), lane_y(int(e["lane"])) + float(e["yo"]))


func creature_by_id(id: int) -> Dictionary:
	for c in creatures:
		if c["id"] == id:
			return c
	return {}


func enemy_by_id(id: int) -> Dictionary:
	for e in enemies:
		if e["id"] == id:
			return e
	return {}


func named_creature() -> Dictionary:
	for c in creatures:
		if c["named"]:
			return c
	return {}


func has_kind(kind: String) -> bool:
	for c in creatures:
		if not c["dead"] and c["kind"] == kind:
			return true
	return false


func cost_of(item: String) -> int:
	var c: float = float(B["economy"]["costs"].get(item, 999999))
	if item == "sabueso":
		c *= maxf(0.3, 1.0 + fmul("eco.sabueso_cost"))
	return int(round(c))


func epitaph() -> String:
	var t: Dictionary = named_creature()
	if t.is_empty():
		return ""
	return "%s, %s. %d bajas. %d cicatrices." % [t["name"], label(t["kind"]), t["kills"], t["scars"]]


## Resumen por carril de la oleada `idx`: [ {kind: cantidad}, {...}, {...} ]
## Resumen de la oleada `idx` en 4 cubos: carriles 0, 1, 2 y 3 = frente sorteado.
func preview(idx: int) -> Array:
	var lanes: Array = [{}, {}, {}, {}]
	if idx < 0 or idx >= WAVES.size():
		return lanes
	var w: Dictionary = WAVES[idx]
	for g in w["spawns"]:
		var kind: String = g["kind"]
		if kind == "@hero":
			kind = String(ROUTES[route]["hero"]) if route != "" else "heroe"
		var lane: int = int(g["lane"])
		if lane < 0:
			lane = 3
		var prev: int = int(lanes[lane].get(kind, 0))
		lanes[lane][kind] = prev + int(g["count"])
	return lanes


func preview_totals(idx: int) -> Dictionary:
	var tot: Dictionary = {}
	for bucket in preview(idx):
		for k in bucket.keys():
			tot[k] = int(tot.get(k, 0)) + int(bucket[k])
	return tot


func zone_min_x() -> float:
	return float(B["zones"]["rear"]["x0"])


func zone_max_x() -> float:
	return float(B["zones"]["front"]["x1"])


func spot_ok(x: float, lane: int, ignore_id: int) -> bool:
	if x < zone_min_x() or x > zone_max_x() or lane < 0 or lane > 2:
		return false
	var gap: float = float(B["zones"]["min_gap"])
	for c in creatures:
		if c["dead"] or c["id"] == ignore_id:
			continue
		if int(c["home_lane"]) == lane and absf(float(c["home_x"]) - x) < gap:
			return false
	return true


## Primer hueco libre en la zona "front" o "rear" (si no hay, en la otra). {} si no cabe.
func find_spot(depth: String) -> Dictionary:
	var order: Array = [depth, "rear" if depth == "front" else "front"]
	var gap: float = float(B["zones"]["min_gap"])
	for d in order:
		var z: Dictionary = B["zones"][d]
		var x: float = float(z["x1"]) - 20.0
		while x >= float(z["x0"]) + 10.0:
			for lane in [1, 0, 2]:
				if spot_ok(x, lane, -1):
					return {"x": x, "lane": lane}
			x -= gap + 4.0
	return {}


func _note_seen(form: String) -> void:
	if not seen_forms.has(form):
		seen_forms.append(form)
		events.append({"t": "form_seen", "form": form})


# ----------------------------------------------------------------------------
# Acciones del jugador (entre oleadas)
# ----------------------------------------------------------------------------

func place_at(cid: int, x: float, lane: int) -> bool:
	if phase == "combat" or phase == "victory" or phase == "defeat":
		return false
	var c: Dictionary = creature_by_id(cid)
	if c.is_empty():
		return false
	x = clampf(x, zone_min_x(), zone_max_x())
	if not spot_ok(x, lane, cid):
		return false
	_set_pos(c, x, lane)
	events.append({"t": "placed", "id": cid})
	return true


func _set_pos(c: Dictionary, x: float, lane: int) -> void:
	c["lane"] = lane
	c["home_lane"] = lane
	c["x"] = x
	c["home_x"] = x


func stat_mult(c: Dictionary) -> float:
	return 1.0 + float(B["economy"]["level_step"]) * float(int(c["level"]) - 1)


func hp_mult(c: Dictionary) -> float:
	return stat_mult(c) * (1.0 + fmul("beast.hp"))


func dmg_mult(c: Dictionary) -> float:
	var m: float = stat_mult(c) * (1.0 + fmul("beast.dmg"))
	m *= 1.0 + fadd("special.scar_dmg") * float(c["scars"])
	var others: int = 0
	for o in creatures:
		if o["id"] != c["id"] and not o["dead"] and not o["fallen"]:
			others += 1
	m *= 1.0 + fadd("special.pack") * float(others)
	return m


func calc_max_hp(c: Dictionary) -> float:
	return float(_stats(c["kind"])["hp"]) * hp_mult(c)


func refresh_creatures() -> void:
	for c in creatures:
		c["max_hp"] = calc_max_hp(c)
		if phase != "combat":
			c["hp"] = c["max_hp"]


func level_cost(c: Dictionary) -> int:
	var costs: Array = B["economy"]["level_costs"]
	var i: int = int(c["level"]) - 1
	if i < 0 or i >= costs.size() or int(c["level"]) >= 3 + int(fadd("eco.max_level")):
		return -1
	return int(round(float(costs[i]) * maxf(0.3, 1.0 + fmul("eco.level_cost"))))


func can_level(cid: int) -> bool:
	if phase != "prep":
		return false
	var c: Dictionary = creature_by_id(cid)
	if c.is_empty() or c["dead"]:
		return false
	var cost: int = level_cost(c)
	return cost > 0 and souls >= cost


func level_up(cid: int) -> bool:
	if not can_level(cid):
		return false
	var c: Dictionary = creature_by_id(cid)
	souls -= level_cost(c)
	c["level"] += 1
	c["max_hp"] = calc_max_hp(c)
	c["hp"] = c["max_hp"]
	events.append({"t": "leveled", "id": cid, "level": c["level"]})
	return true


func can_buy(item: String) -> bool:
	if phase != "prep":
		return false
	if souls < cost_of(item):
		return false
	match item:
		"sabueso":
			return not find_spot("front").is_empty()
		"ojo":
			for c in creatures:
				if c["kind"] == "ojo" and not c["loaned"] and not c["dead"]:
					return false
			return has_kind("ojo") or not find_spot("rear").is_empty()
	return false


func buy(item: String) -> bool:
	if not can_buy(item):
		return false
	souls -= cost_of(item)
	match item:
		"sabueso":
			var sc: Dictionary = _new_creature("sabueso", find_spot("front"))
			sc["name"] = "Sabueso"
			creatures.append(sc)
		"ojo":
			var existing: Dictionary = {}
			for c in creatures:
				if c["kind"] == "ojo" and not c["dead"]:
					existing = c
			if not existing.is_empty():
				existing["loaned"] = false
				existing["name"] = label("ojo")
			else:
				var oc: Dictionary = _new_creature("ojo", find_spot("rear"))
				oc["name"] = label("ojo")
				creatures.append(oc)
				_note_seen("ojo")
	events.append({"t": "bought", "item": item})
	return true


func choose_route(r: String) -> bool:
	if phase != "route" or not ROUTES.has(r):
		return false
	route = r
	phase = "prep"
	events.append({"t": "route_chosen", "route": r})
	_prepare_next()
	return true


func give_relic() -> bool:
	if phase != "forge":
		return false
	var r: Dictionary = ROUTES[route]
	var t: Dictionary = named_creature()
	var form: String = r["form"]
	var st: Dictionary = B[form]
	t["kind"] = form
	t["max_hp"] = calc_max_hp(t)
	t["hp"] = t["max_hp"]
	t["state"] = "home"
	t["skill_cd"] = 0.0
	t["presa_cd"] = 0.0
	relic = ""
	_note_seen(form)
	events.append({"t": "mutated", "id": t["id"], "form": form, "name": t["name"]})
	phase = "prep"
	_prepare_next()
	return true


func start_wave() -> bool:
	if phase != "prep" or not draft.is_empty():
		return false
	_front_lane = rng.randi_range(0, 2) if augur_fx("one_front") > 0.0 else -1
	spawn_queue = _build_spawns(WAVES[wave_index])
	enemies.clear()
	zones.clear()
	phase = "combat"
	wave_time = 0.0
	brasa_cd = 0.0
	rayo_cd = 0.0
	pending_brasas.clear()
	tar_pools.clear()
	for c in creatures:
		_reset_combat_state(c)
	events.append({"t": "wave_start", "wave": wave_index + 1})
	return true


func _reset_combat_state(c: Dictionary) -> void:
	c["state"] = "home"
	c["air"] = false
	c["lane"] = c["home_lane"]
	c["x"] = c["home_x"]
	c["stun"] = 0.0
	c["windup"] = 0.0
	c["cd"] = 0.0
	c["presa_cd"] = 0.0
	c["skill_cd"] = 0.0
	c["hambre"] = 0
	c["target"] = -1
	c["hp"] = c["max_hp"]


func _build_spawns(w: Dictionary) -> Array:
	var q: Array = []
	for g in w["spawns"]:
		var kind: String = g["kind"]
		if kind == "@hero":
			kind = String(ROUTES[route]["hero"]) if route != "" else "verdugo"
		var n: int = int(g["count"])
		var est: Dictionary = B["enemies"].get(kind, {})
		if not (est.get("elite", false) or est.get("hero", false) or est.get("boss", false)):
			n = int(round(float(n) * (1.0 + augur_fx("count"))))
		var gap: float = float(g.get("gap", 1.0))
		var d: float = float(g.get("delay", 0.0))
		var lane: int = int(g["lane"]) if _front_lane < 0 else _front_lane
		for i in n:
			q.append({"t": d + gap * i, "lane": lane, "kind": kind})
	var extra: int = int(augur_fx("extra_elite"))
	var pool: Array = SIEGES[siege_index].get("remix", {}).get("elites", [])
	for j in extra:
		if not pool.is_empty():
			q.append({"t": 6.0 + 4.0 * j, "lane": _front_lane, "kind": String(pool[rng.randi() % pool.size()])})
	q.sort_custom(func(a, b): return a["t"] < b["t"])
	return q


func _prepare_next() -> void:
	var w: Dictionary = WAVES[wave_index]
	if w.get("loan_ojo", false) and not has_kind("ojo"):
		var spot: Dictionary = find_spot("rear")
		if not spot.is_empty():
			var o: Dictionary = _new_creature("ojo", spot)
			o["loaned"] = true
			o["name"] = "Ojo prestado"
			creatures.append(o)
			_note_seen("ojo")
			events.append({"t": "loan_ojo", "id": o["id"]})
	message = "Oleada %d: %s" % [wave_index + 1, w["title"]]
	_offer_augurs()


# ----------------------------------------------------------------------------
# Variedad por partida: oleadas remezcladas y augurios
# ----------------------------------------------------------------------------

## Copia las oleadas del asedio cambiando la composición con el mismo presupuesto (recompensa):
## el grupo principal de cada oleada conserva su tipo (es el tema y la nota de la oleada); los
## demás comunes pueden cambiar por otro común y las élites por otra élite. Cantidades ±jitter.
func _remix_waves(sg: Dictionary) -> Array:
	var rx: Dictionary = sg.get("remix", {})
	var out: Array = []
	var src: Array = sg["waves"]
	for wi in src.size():
		var w: Dictionary = src[wi].duplicate(true)
		out.append(w)
		if rx.is_empty() or (wi == 0 and bool(rx.get("keep_first", true))):
			continue
		var main_i: int = -1
		var best: float = -1.0
		for gi in w["spawns"].size():
			var g: Dictionary = w["spawns"][gi]
			var est: Dictionary = B["enemies"].get(String(g["kind"]), {})
			var budget: float = float(est.get("reward", 0)) * float(g["count"])
			if budget > best and not est.get("elite", false):
				best = budget
				main_i = gi
		for gi in w["spawns"].size():
			var g2: Dictionary = w["spawns"][gi]
			var kind: String = String(g2["kind"])
			if kind.begins_with("@"):
				continue
			var st: Dictionary = B["enemies"].get(kind, {})
			if st.get("hero", false) or st.get("boss", false):
				continue
			var commons: Array = rx.get("commons", [])
			var elites: Array = rx.get("elites", [])
			if st.get("elite", false):
				if kind in elites and rng.randf() < float(rx.get("elite_swap", 0.0)):
					g2["kind"] = String(elites[rng.randi() % elites.size()])
				continue
			var n: float = float(g2["count"])
			if gi != main_i and kind in commons and rng.randf() < float(rx.get("swap", 0.0)):
				var nk: String = String(commons[rng.randi() % commons.size()])
				n = n * float(st["reward"]) / float(B["enemies"][nk]["reward"])
				g2["kind"] = nk
			var jit: float = float(rx.get("jitter", 0.0))
			g2["count"] = maxi(1, int(round(n * rng.randf_range(1.0 - jit, 1.0 + jit))))
	return out


func _hp_scale() -> float:
	return wrath_hp() * (1.0 + augur_fx("enemy_hp")) * float(current_wave().get("hp_mult", 1.0))


func _siege_by_id(id: String) -> int:
	for i in SIEGES.size():
		if String(SIEGES[i]["id"]) == id:
			return i
	return 0


## Oleada generada de La Grieta (índice 0-based `i`, tras las del asedio base).
## Presupuesto en recompensa que crece, un tema (grupo principal) y relleno al azar,
## élites que aumentan, héroe y jefe cada cierto número de oleadas, y vida extra por oleada.
func _gen_wave(i: int) -> Dictionary:
	var en: Dictionary = SIEGES[siege_index]["endless"]
	var rx: Dictionary = SIEGES[siege_index].get("remix", {})
	var base_n: int = SIEGES[_siege_by_id(String(en["base_siege"]))]["waves"].size()
	var k: int = i - base_n + 1   # 1 = primera oleada generada
	var budget: float = float(en["budget"]) * pow(float(en["growth"]), float(k))
	var themes: Array = en["themes"]
	var th: Dictionary = themes[rng.randi() % themes.size()]
	var spawns: Array = []
	var main_kind: String = String(th["main"])
	var main_n: int = maxi(3, int(round(budget * 0.5 / float(B["enemies"][main_kind]["reward"]))))
	spawns.append({"kind": main_kind, "count": main_n, "lane": -1, "gap": 0.7})
	var left: float = budget * 0.5
	var commons: Array = rx.get("commons", ["campesino"])
	var gi: int = 1
	while left > 4.0 and gi < 5:
		var ck: String = String(commons[rng.randi() % commons.size()])
		var rw: float = float(B["enemies"][ck]["reward"])
		var n: int = maxi(1, int(round(minf(left, budget * 0.25) / rw)))
		spawns.append({"kind": ck, "count": n, "lane": -1, "gap": 0.9, "delay": 3.0 * gi})
		left -= rw * n
		gi += 1
	var elites: Array = rx.get("elites", [])
	var ne: int = mini(int(en["elites_max"]), int(en["elites_base"]) + k / int(en["elites_every"]))
	for j in ne:
		if not elites.is_empty():
			spawns.append({"kind": String(elites[rng.randi() % elites.size()]), "count": 1, "lane": -1, "delay": 4.0 + 5.0 * j})
	var title: String = String(th["title"])
	var note: String = String(th["note"])
	var wave_no: int = i + 1
	if wave_no % int(en["boss_every"]) == 0:
		spawns.append({"kind": String(en["boss"]), "count": 1, "lane": 1, "delay": 8.0})
		title = "El Gran Maestre vuelve"
		note = "El jefe de la Orden juzga un carril: apártate o resiste."
	elif wave_no % int(en["hero_every"]) == 0:
		spawns.append({"kind": "@hero", "count": 1, "lane": -1, "delay": 6.0})
		title = "El heraldo vuelve"
		note = "Tu heraldo regresa, más duro."
	return {"title": title, "note": note, "spawns": spawns, "hp_mult": 1.0 + float(en["hp_step"]) * float(k), "generated": true}


func augur_def(id: String) -> Dictionary:
	for a in B.get("augurs", {}).get("list", []):
		if String(a["id"]) == id:
			return a
	return {}


func augur_fx(k: String) -> float:
	var v: float = 0.0
	if augur != "":
		v += float(augur_def(augur).get("fx", {}).get(k, 0.0))
	if week_augur != "" and week_augur != augur:
		v += float(augur_def(week_augur).get("fx", {}).get(k, 0.0))
	return v


func _offer_augurs() -> void:
	augur = ""
	augur_offer.clear()
	if not augurs_enabled or wave_index < 1:
		return
	var pool: Array = []
	for a in B.get("augurs", {}).get("list", []):
		if wave_index + 1 >= int(a.get("min_wave", 2)):
			pool.append(a)
	var n: int = int(B["augurs"].get("offer", 2))
	while augur_offer.size() < n and not pool.is_empty():
		var tot: float = 0.0
		for a2 in pool:
			tot += float(a2.get("weight", 1))
		var r: float = rng.randf() * tot
		for a3 in pool:
			r -= float(a3.get("weight", 1))
			if r <= 0.0:
				augur_offer.append(String(a3["id"]))
				pool.erase(a3)
				break


## Elige un augurio de los ofrecidos (o "" para Calma). Solo en preparación.
func choose_augur(id: String) -> bool:
	if phase != "prep" or (id != "" and not (id in augur_offer)):
		return false
	augur = id
	events.append({"t": "augur", "id": id})
	return true


func _new_creature(kind: String, spot: Dictionary) -> Dictionary:
	var st: Dictionary = B[kind]
	var c: Dictionary = {
		"id": next_id, "kind": kind, "name": label(kind), "named": false, "level": 1,
		"lane": int(spot["lane"]), "home_lane": int(spot["lane"]),
		"x": float(spot["x"]), "home_x": float(spot["x"]),
		"hp": float(_stats(kind)["hp"]) * (1.0 + fmul("beast.hp")), "max_hp": float(_stats(kind)["hp"]) * (1.0 + fmul("beast.hp")),
		"cd": 0.0, "presa_cd": 0.0, "skill_cd": 0.0, "stun": 0.0, "windup": 0.0,
		"state": "home", "t": 0.0, "scars": 0, "kills": 0,
		"dead": false, "fallen": false, "loaned": false,
		"hambre": 0, "target": -1, "air": false,
		"from_x": 0.0, "to_x": 0.0, "from_lane": 0, "to_lane": 0,
	}
	next_id += 1
	return c


# ----------------------------------------------------------------------------
# Simulación
# ----------------------------------------------------------------------------

func step(dt: float) -> void:
	if phase != "combat":
		return
	wave_time += dt
	while spawn_queue.size() > 0 and spawn_queue[0]["t"] <= wave_time:
		var sp: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(sp["kind"], sp["lane"])
		if sp.has("x"):
			enemies[enemies.size() - 1]["x"] = float(sp["x"])
	_update_zones(dt)
	for c in creatures:
		_update_creature(c, dt)
	_update_spells(dt)
	for e in enemies:
		_update_enemy(e, dt)
	_cleanup()
	_check_end()


func _spawn_enemy(kind: String, lane: int) -> void:
	if lane < 0:
		lane = rng.randi_range(0, 2)
	var st: Dictionary = B["enemies"][kind]
	var e: Dictionary = {
		"id": next_id, "kind": kind, "lane": lane, "x": float(B["arena"]["spawn_x"]),
		"hp": float(st["hp"]) * _hp_scale(), "max_hp": float(st["hp"]) * _hp_scale(),
		"cd": rng.randf() * 0.6, "held": 0.0, "stun": 0.0, "shield": 0.0, "summons": 0,
		"judge_t": float(st.get("judge_cd", 0.0)) * 0.6, "judge_wind": 0.0, "judge_lane": -1,
		"shield_t": float(st.get("shield_cd", 0.0)) * 0.5,
		"burn_t": 0.0, "burn_dps": 0.0,
		"pull_t": 0.0, "pull_x": 0.0, "pull_speed": 0.0, "fed": false,
		"marked": false, "heal_t": float(st.get("heal_cd", 2.0)), "bell_t": float(st.get("bell_cd", 4.0)) * 0.7,
		"dead": false, "bump": rng.randf(), "yo": rng.randf_range(-30.0, 30.0),
		"aim_t": 0.0, "sweep_t": 0.0, "sweep_cd_t": float(st.get("sweep_cd", 0.0)) * 0.5,
		"ring_t": float(st.get("ring_cd", 0.0)) * 0.6,
	}
	next_id += 1
	enemies.append(e)
	if st.get("elite", false) or st.get("hero", false) or st.get("boss", false):
		events.append({"t": "elite_spawn", "kind": kind, "id": e["id"], "lane": lane})


func damage_enemy(e: Dictionary, amount: float, src: int = -1, armored: bool = true) -> void:
	if e["dead"]:
		return
	var st: Dictionary = B["enemies"][e["kind"]]
	if src >= 0:
		var attacker: Dictionary = creature_by_id(src)
		if not attacker.is_empty():
			amount *= dmg_mult(attacker)
	var mult: float = float(st.get("armor", 1.0)) if armored else 1.0
	if armored:
		mult *= _cover_mult(e)
	var dealt: float = amount * mult
	if float(e.get("shield", 0.0)) > 0.0:
		var ab: float = minf(float(e["shield"]), dealt)
		e["shield"] = float(e["shield"]) - ab
		dealt -= ab
	e["hp"] -= dealt
	if armored:
		events.append({"t": "hit", "x": e["x"], "lane": e["lane"], "id": e["id"], "amount": amount * mult, "y": epos(e).y})
	_check_summon(e, st)
	if e["hp"] <= 0.0:
		e["dead"] = true
		var reward: int = int(round(float(st["reward"]) * (1.0 + fmul("eco.reward")) * (1.0 + augur_fx("reward"))))
		souls += reward
		kills += 1
		var c: Dictionary = creature_by_id(src)
		if not c.is_empty():
			c["kills"] += 1
		events.append({"t": "kill", "x": e["x"], "lane": e["lane"], "reward": reward, "id": e["id"], "kind": e["kind"], "y": epos(e).y})


# El Muro de Marfil protege al aliado que camina justo detrás de él.
func _cover_mult(e: Dictionary) -> float:
	for m in enemies:
		if m["dead"] or m["id"] == e["id"]:
			continue
		var ms: Dictionary = B["enemies"][m["kind"]]
		if not ms.has("cover_range"):
			continue
		if m["lane"] == e["lane"] and m["x"] < e["x"] and e["x"] - m["x"] <= float(ms["cover_range"]):
			return float(ms["cover"])
	return 1.0


# La turba corre más cerca de un Capataz.
func _haste_mult(e: Dictionary) -> float:
	var slow: float = 1.0
	if float(e.get("tar", 0.0)) > 0.0:
		slow = float(B["sapo"]["slow"])
	var best: float = 1.0
	for m in enemies:
		if m["dead"] or m["id"] == e["id"]:
			continue
		var ms: Dictionary = B["enemies"][m["kind"]]
		if not ms.has("haste_radius"):
			continue
		if epos(m).distance_to(epos(e)) <= float(ms["haste_radius"]):
			best = maxf(best, float(ms["haste"]))
	return best * slow


func _creature_point(c: Dictionary) -> Vector2:
	return Vector2(float(c["x"]), lane_y(int(c["lane"])))


func damage_creature(c: Dictionary, amount: float) -> void:
	if c["dead"] or c["fallen"] or c["air"]:
		return
	amount *= wrath_dmg()
	if c["state"] == "stone":
		c["stored"] = float(c.get("stored", 0.0)) + amount
		events.append({"t": "stone_absorb", "id": c["id"]})
		return
	c["hp"] -= amount
	events.append({"t": "creature_hit", "id": c["id"], "amount": amount})
	if c["hp"] <= 0.0:
		c["hp"] = 0.0
		if c["named"]:
			c["fallen"] = true
		else:
			c["dead"] = true
		events.append({"t": "creature_down", "id": c["id"], "named": c["named"]})


func _update_zones(dt: float) -> void:
	var pools: Array = []
	for tp in tar_pools:
		tp["t"] -= dt
		if tp["t"] <= 0.0:
			continue
		pools.append(tp)
		for e in enemies:
			if not e["dead"] and epos(e).distance_to(tp["p"]) <= tp["r"]:
				e["tar"] = maxf(float(e.get("tar", 0.0)), 0.5)
	tar_pools = pools
	var keep: Array = []
	for z in zones:
		z["t"] -= dt
		if z["t"] <= 0.0:
			continue
		keep.append(z)
		for e in enemies:
			if e["dead"] or e["lane"] != z["lane"]:
				continue
			if e["x"] >= z["x0"] and e["x"] <= z["x1"]:
				e["burn_t"] = maxf(e["burn_t"], 0.6)
				e["burn_dps"] = maxf(e["burn_dps"], float(_stats("horno")["burn_dps"]))
	zones = keep


func brasa_radius() -> float:
	return float(_stats("brasa")["radius"])


func cast_brasa(p: Vector2) -> bool:
	if phase != "combat" or brasa_cd > 0.0:
		return false
	var c: Dictionary = _stats("brasa")
	brasa_cd = float(c["cd"]) * (1.0 + augur_fx("spell_cd"))
	var r: float = brasa_radius()
	pending_brasas.append({"t": float(c["delay"]), "d": float(c["delay"]), "p": p, "r": r, "k": 1.0})
	events.append({"t": "brasa_cast", "p": p, "r": r, "delay": float(c["delay"])})
	if fadd("special.brasa_echo") > 0.0:
		var ed: float = float(c["delay"]) + 0.6
		pending_brasas.append({"t": ed, "d": ed, "p": p, "r": r * 0.8, "k": 0.6})
		events.append({"t": "brasa_cast", "p": p, "r": r * 0.8, "delay": ed})
	return true


func rayo_target(p: Vector2) -> Dictionary:
	var c: Dictionary = _stats("rayo")
	var origin: Vector2 = demon_pos()
	var best: Dictionary = {}
	var best_d: float = float(c["pick_radius"])
	for e in enemies:
		if e["dead"]:
			continue
		var ep: Vector2 = epos(e)
		if ep.distance_to(origin) > float(c["range"]):
			continue
		var d: float = ep.distance_to(p)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _rayo_hit(e: Dictionary, base: float, c: Dictionary) -> void:
	var dmg: float = base
	if e["hp"] / e["max_hp"] < 0.35:
		dmg *= 1.0 + fadd("special.rayo_exec")
	damage_enemy(e, dmg, -1)
	if not e["dead"] and float(c["stun"]) > 0.0:
		e["stun"] = maxf(e["stun"], float(c["stun"]))


func cast_rayo(p: Vector2) -> bool:
	if phase != "combat" or rayo_cd > 0.0:
		return false
	var tgt: Dictionary = rayo_target(p)
	if tgt.is_empty():
		return false
	var c: Dictionary = _stats("rayo")
	rayo_cd = float(c["cd"]) * (1.0 + augur_fx("spell_cd"))
	var tp: Vector2 = epos(tgt)
	_rayo_hit(tgt, float(c["dmg"]), c)
	events.append({"t": "rayo", "from": demon_pos(), "to": tp, "target": tgt["id"]})
	if fadd("special.rayo_chain") > 0.0:
		var hit: Array = [tgt["id"]]
		var cur: Vector2 = tp
		var k: float = 1.0
		for j in int(c["chain_count"]):
			var nxt: Dictionary = {}
			var sd: float = float(c["chain_range"])
			for e in enemies:
				if e["dead"] or hit.has(e["id"]):
					continue
				var d: float = epos(e).distance_to(cur)
				if d <= sd:
					sd = d
					nxt = e
			if nxt.is_empty():
				break
			k *= float(c["chain_frac"])
			_rayo_hit(nxt, float(c["dmg"]) * k, c)
			events.append({"t": "rayo_chain", "from": cur, "to": epos(nxt), "target": nxt["id"]})
			hit.append(nxt["id"])
			cur = epos(nxt)
	return true


func _update_spells(dt: float) -> void:
	brasa_cd = maxf(0.0, brasa_cd - dt)
	rayo_cd = maxf(0.0, rayo_cd - dt)
	var c: Dictionary = _stats("brasa")
	var keep: Array = []
	for b in pending_brasas:
		b["t"] -= dt
		if b["t"] > 0.0:
			keep.append(b)
			continue
		var hits: int = 0
		for e in enemies:
			if e["dead"]:
				continue
			if epos(e).distance_to(b["p"]) <= float(b["r"]):
				hits += 1
				damage_enemy(e, float(c["dmg"]) * float(b["k"]), -1)
				if not e["dead"]:
					e["burn_t"] = maxf(e["burn_t"], float(c["burn_time"]))
					e["burn_dps"] = maxf(e["burn_dps"], float(c["burn_dps"]))
					if float(c["stun"]) > 0.0:
						e["stun"] = maxf(e["stun"], float(c["stun"]))
		events.append({"t": "brasa_land", "p": b["p"], "r": b["r"], "hits": hits})
	pending_brasas = keep


# --- Criaturas ---------------------------------------------------------------

func _update_creature(c: Dictionary, dt: float) -> void:
	if c["dead"] or c["fallen"]:
		return
	c["cd"] = maxf(0.0, c["cd"] - dt)
	c["presa_cd"] = maxf(0.0, c["presa_cd"] - dt)
	c["skill_cd"] = maxf(0.0, c["skill_cd"] - dt)
	var rg: float = fadd("special.regen")
	if rg > 0.0:
		c["hp"] = minf(c["max_hp"], c["hp"] + c["max_hp"] * rg * dt)
	if c["stun"] > 0.0:
		c["stun"] -= dt
		return
	match c["kind"]:
		"sabueso":
			_ai_presa(c, dt, "sabueso")
		"alacran":
			_ai_presa(c, dt, "alacran")
		"sapo":
			_ai_sapo(c, dt)
		"manta":
			_ai_manta(c, dt)
		"horno":
			_ai_horno(c, dt)
		"trueno":
			_ai_trueno(c, dt)
		"ojo":
			_ai_ojo(c)
		"gargola":
			_ai_gargola(c, dt)
		"enjambre":
			_ai_enjambre(c)
		"garfio":
			_ai_garfio(c, dt)


func _move_toward(c: Dictionary, tx: float, speed: float, dt: float) -> void:
	var dx: float = tx - c["x"]
	var step_len: float = speed * dt
	if absf(dx) <= step_len:
		c["x"] = tx
	else:
		c["x"] += signf(dx) * step_len


func _melee_target(c: Dictionary, leash: float, anchor: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = 1e9
	for e in enemies:
		if e["dead"] or e["lane"] != c["lane"]:
			continue
		if absf(e["x"] - anchor) > leash:
			continue
		var d: float = absf(e["x"] - c["x"])
		if d < best_d:
			best_d = d
			best = e
	return best


func _melee_step(c: Dictionary, st: Dictionary, dt: float, anchor: float) -> Dictionary:
	var tgt: Dictionary = _melee_target(c, float(st["leash"]), anchor)
	if tgt.is_empty():
		_move_toward(c, anchor, float(st["speed"]) * 0.8, dt)
		return {}
	var dx: float = tgt["x"] - c["x"]
	if absf(dx) > float(st["reach"]):
		_move_toward(c, tgt["x"], float(st["speed"]), dt)
	elif c["cd"] <= 0.0:
		c["cd"] = float(st["cd"])
		damage_enemy(tgt, float(st["dmg"]), c["id"])
		events.append({"t": "bite", "id": c["id"]})
	return tgt


func _melee_bite_only(c: Dictionary, st: Dictionary) -> void:
	if c["cd"] > 0.0:
		return
	var tgt: Dictionary = _melee_target(c, float(st["reach"]) + 20.0, c["x"])
	if tgt.is_empty():
		return
	c["cd"] = float(st["cd"])
	damage_enemy(tgt, float(st["dmg"]), c["id"])
	events.append({"t": "bite", "id": c["id"]})


func _is_hero(kind: String) -> bool:
	return bool(B["enemies"][kind].get("hero", false))


func _ai_presa(c: Dictionary, dt: float, kind: String) -> void:
	var st: Dictionary = _stats(kind)
	if c["windup"] > 0.0:
		c["windup"] -= dt
		if c["windup"] <= 0.0:
			var t: Dictionary = enemy_by_id(int(c["target"]))
			if not t.is_empty() and not t["dead"]:
				var hold: float = float(st["presa_time"])
				if _is_hero(t["kind"]):
					hold *= 0.5
				t["held"] = hold
				if st.has("grab_dmg"):
					damage_enemy(t, float(st["grab_dmg"]), c["id"])
				if fadd("special.presa_dmg") > 0.0:
					damage_enemy(t, float(st["dmg"]) * fadd("special.presa_dmg"), c["id"])
				events.append({"t": "presa", "id": c["id"], "target": t["id"]})
		return
	var tgt: Dictionary = _melee_step(c, st, dt, c["home_x"])
	if tgt.is_empty():
		return
	if c["presa_cd"] <= 0.0 and tgt["held"] <= 0.0 and absf(tgt["x"] - c["x"]) <= float(st["presa_range"]):
		c["presa_cd"] = float(st["presa_cd"])
		c["windup"] = float(st["presa_windup"])
		c["target"] = tgt["id"]
		events.append({"t": "presa_windup", "id": c["id"], "target": tgt["id"]})


func _ai_sapo(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("sapo")
	if c["windup"] > 0.0:
		c["windup"] -= dt
		if c["windup"] <= 0.0:
			_sapo_land(c, st)
		return
	if c["cd"] > 0.0:
		return
	var best: Dictionary = {}
	var best_n: int = 0
	for e in enemies:
		if e["dead"]:
			continue
		var d: float = e["x"] - c["x"]
		if d < float(st["min_range"]) or d > float(st["range"]):
			continue
		var n: int = 0
		for o in enemies:
			if not o["dead"] and epos(o).distance_to(epos(e)) <= float(st["tar_radius"]):
				n += 1
		if n > best_n:
			best_n = n
			best = e
	if best.is_empty():
		return
	c["target"] = best["id"]
	c["windup"] = float(st["windup"])
	c["cd"] = float(st["cd"])
	events.append({"t": "sapo_windup", "id": c["id"], "target": best["id"]})


func _sapo_land(c: Dictionary, st: Dictionary) -> void:
	var t: Dictionary = enemy_by_id(int(c["target"]))
	var p: Vector2 = epos(t) if not t.is_empty() and not t["dead"] else Vector2(c["x"] + 300.0, lane_y(int(c["lane"])))
	var hit: int = 0
	for e in enemies:
		if e["dead"] or epos(e).distance_to(p) > float(st["tar_radius"]):
			continue
		hit += 1
		damage_enemy(e, float(st["tar_dmg"]), c["id"])
		if not e["dead"]:
			e["tar"] = float(st["tar_time"])
	tar_pools.append({"p": p, "r": float(st["tar_radius"]), "t": float(st["tar_time"])})
	events.append({"t": "sapo_spit", "id": c["id"], "x": p.x, "y": p.y, "from_x": c["x"], "lane": c["lane"], "hit": hit})


func _ai_manta(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("manta")
	match c["state"]:
		"home":
			if c["skill_cd"] > 0.0:
				return
			var best_lane: int = -1
			var best_n: int = 0
			for lane in 3:
				var n: int = 0
				for e in enemies:
					if not e["dead"] and e["lane"] == lane and e["x"] >= c["home_x"] and e["x"] <= c["home_x"] + float(st["sweep_len"]):
						n += 1
				if n > best_n:
					best_n = n
					best_lane = lane
			if best_lane < 0 or best_n < int(st["min_targets"]):
				return
			c["target"] = best_lane
			c["state"] = "dive"
			c["windup"] = float(st["windup"])
			events.append({"t": "manta_dive", "id": c["id"], "lane": best_lane})
		"dive":
			c["windup"] -= dt
			if c["windup"] <= 0.0:
				c["state"] = "glide"
				c["air"] = true
				c["lane"] = int(c["target"])
				c["hit"] = []
				events.append({"t": "manta_glide", "id": c["id"], "lane": c["lane"]})
		"glide":
			c["x"] += float(st["speed"]) * dt
			for e in enemies:
				if e["dead"] or e["lane"] != c["lane"] or c["hit"].has(e["id"]):
					continue
				if absf(e["x"] - c["x"]) <= 34.0:
					c["hit"].append(e["id"])
					damage_enemy(e, float(st["hit_dmg"]), c["id"])
					if not e["dead"]:
						e["stun"] = maxf(e["stun"], float(st["hit_stun"]))
			if c["x"] >= c["home_x"] + float(st["sweep_len"]):
				c["state"] = "back"
		"back":
			c["x"] -= float(st["speed"]) * dt
			if c["x"] <= c["home_x"]:
				c["x"] = c["home_x"]
				c["lane"] = c["home_lane"]
				c["air"] = false
				c["state"] = "home"
				c["skill_cd"] = float(st["swoop_cd"])


func _ai_horno(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("horno")
	match c["state"]:
		"home":
			_melee_step(c, st, dt, c["home_x"])
			if c["skill_cd"] > 0.0:
				return
			var cand: Array = []
			for e in enemies:
				if e["dead"] or e["lane"] != c["lane"]:
					continue
				var dx: float = e["x"] - c["x"]
				if dx > 20.0 and dx <= float(st["inhale_range"]):
					cand.append(e)
			if cand.size() == 0:
				return
			cand.sort_custom(func(a, b): return a["x"] < b["x"])
			c["state"] = "inhale"
			c["t"] = 0.0
			c["hambre"] = 0
			var n: int = mini(cand.size(), int(st["inhale_max"]))
			for i in n:
				var pe: Dictionary = cand[i]
				var frac: float = 0.5 if _is_hero(pe["kind"]) else 1.0
				pe["pull_t"] = float(st["inhale_time"])
				pe["pull_x"] = c["x"] + 50.0 + 22.0 * i
				pe["pull_speed"] = absf(pe["x"] - pe["pull_x"]) / float(st["inhale_time"]) * frac
				pe["fed"] = true
				c["hambre"] += 1
			events.append({"t": "horno_inhale", "id": c["id"], "n": n})
		"inhale":
			c["t"] += dt
			_melee_bite_only(c, st)
			if c["t"] < float(st["inhale_time"]):
				return
			for e2 in enemies:
				if e2["dead"] or e2["lane"] != c["lane"] or e2["fed"]:
					continue
				if absf(e2["x"] - c["x"]) <= 110.0 and c["hambre"] < int(st["inhale_max"]):
					e2["fed"] = true
					c["hambre"] += 1
			if c["hambre"] >= int(st["inhale_max"]):
				_horno_spit(c, false)
			elif c["t"] >= float(st["fill_timeout"]):
				# Tarda demasiado en llenarse: llamarada menor.
				if c["hambre"] > 0:
					_horno_spit(c, true)
				else:
					_horno_end(c)


func _horno_spit(c: Dictionary, minor: bool) -> void:
	var st: Dictionary = _stats("horno")
	var dmg: float = float(st["minor_dmg"]) if minor else float(st["spit_dmg"])
	var burn_time: float = float(st["minor_burn_time"]) if minor else float(st["burn_time"])
	var x0: float = c["x"]
	var x1: float = c["x"] + float(st["spit_range"]) * (0.6 if minor else 1.0)
	for e in enemies:
		if e["dead"] or e["lane"] != c["lane"]:
			continue
		if e["x"] >= x0 - 10.0 and e["x"] <= x1:
			damage_enemy(e, dmg, c["id"])
			if not e["dead"]:
				e["burn_t"] = burn_time
				e["burn_dps"] = float(st["burn_dps"])
	if not minor:
		zones.append({"lane": c["lane"], "x0": x0, "x1": x1, "t": float(st["ground_time"])})
	events.append({"t": "horno_spit", "id": c["id"], "minor": minor, "x0": x0, "x1": x1, "lane": c["lane"]})
	_horno_end(c)


func _horno_end(c: Dictionary) -> void:
	c["state"] = "home"
	c["skill_cd"] = float(_stats("horno")["inhale_cd"])
	c["hambre"] = 0
	for e in enemies:
		e["fed"] = false


# Apoyos (curan) primero y luego tiradores, élites incluidas, según los datos.
func _support_priority(kind: String) -> float:
	var st: Dictionary = B["enemies"].get(kind, {})
	if st.get("support", false):
		return 2.0
	if st.get("ranged", false):
		return 1.0
	return 0.0


func _trueno_pick_target(c: Dictionary) -> Dictionary:
	var st: Dictionary = _stats("trueno")
	# 1) la marca del Ojo manda, en cualquier carril.
	for e in enemies:
		if not e["dead"] and e["marked"] and absf(e["x"] - c["x"]) <= float(st["jump_range"]):
			return e
	# 2) el apoyo más atrasado en su carril o los contiguos.
	var best: Dictionary = {}
	var best_score: float = -1.0
	for e2 in enemies:
		if e2["dead"] or absi(int(e2["lane"]) - int(c["lane"])) > 1:
			continue
		var gap: float = e2["x"] - c["x"]
		if gap < float(st["min_gap"]) or gap > float(st["jump_range"]):
			continue
		var pr: float = _support_priority(e2["kind"])
		if pr <= 0.0:
			continue
		var score: float = pr * 10000.0 + e2["x"]
		if score > best_score:
			best_score = score
			best = e2
	return best


func _ai_trueno(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("trueno")
	match c["state"]:
		"home":
			_melee_step(c, st, dt, c["home_x"])
			if c["skill_cd"] > 0.0:
				return
			var tgt: Dictionary = _trueno_pick_target(c)
			if tgt.is_empty():
				return
			c["state"] = "crouch"
			c["t"] = 0.0
			c["target"] = tgt["id"]
			events.append({"t": "trueno_crouch", "id": c["id"], "target": tgt["id"]})
		"crouch":
			c["t"] += dt
			if c["t"] < float(st["crouch_time"]):
				return
			var tg: Dictionary = enemy_by_id(int(c["target"]))
			if tg.is_empty() or tg["dead"]:
				c["state"] = "home"
				c["skill_cd"] = 1.0
				return
			c["state"] = "air"
			c["t"] = 0.0
			c["air"] = true
			c["from_x"] = c["x"]
			c["from_lane"] = c["lane"]
			c["to_x"] = tg["x"] - 30.0
			c["to_lane"] = tg["lane"]
			events.append({"t": "trueno_jump", "id": c["id"], "from_x": c["from_x"],
				"from_lane": c["from_lane"], "to_x": c["to_x"], "to_lane": c["to_lane"]})
		"air":
			c["t"] += dt
			var k: float = clampf(c["t"] / float(st["jump_time"]), 0.0, 1.0)
			c["x"] = lerpf(c["from_x"], c["to_x"], k)
			if k >= 1.0:
				c["air"] = false
				c["lane"] = c["to_lane"]
				c["state"] = "rear"
				c["t"] = 0.0
				c["skill_cd"] = float(st["jump_cd"])
				_trueno_land(c)
		"rear":
			c["t"] += dt
			var near: Dictionary = _melee_step(c, st, dt, c["to_x"])
			var weak: bool = c["hp"] < c["max_hp"] * 0.35
			if c["t"] >= float(st["return_after"]) or weak or (near.is_empty() and c["t"] > 1.2):
				c["state"] = "return"
				c["lane"] = c["home_lane"]
		"return":
			_move_toward(c, c["home_x"], float(st["speed"]) * 1.4, dt)
			if absf(c["x"] - c["home_x"]) < 2.0:
				c["state"] = "home"


func _trueno_land(c: Dictionary) -> void:
	var st: Dictionary = _stats("trueno")
	var tid: int = int(c["target"])
	var tg: Dictionary = enemy_by_id(tid)
	var hit_ids: Array = []
	if not tg.is_empty() and not tg["dead"]:
		damage_enemy(tg, float(st["land_dmg"]), c["id"])
		hit_ids.append(tid)
	var chain: Array = st["chain_dmg"]
	var cand: Array = []
	for e in enemies:
		if e["dead"] or e["id"] == tid or e["lane"] != c["lane"]:
			continue
		if absf(e["x"] - c["x"]) <= float(st["chain_range"]):
			cand.append(e)
	var cx: float = c["x"]
	cand.sort_custom(func(a, b): return absf(a["x"] - cx) < absf(b["x"] - cx))
	var n: int = 0
	for e2 in cand:
		if n >= chain.size():
			break
		damage_enemy(e2, float(chain[n]), c["id"])
		hit_ids.append(e2["id"])
		n += 1
	events.append({"t": "trueno_land", "id": c["id"], "x": c["x"], "lane": c["lane"], "hits": hit_ids})


func _ai_ojo(c: Dictionary) -> void:
	var st: Dictionary = _stats("ojo")
	var with_horno: bool = has_kind("horno") or has_kind("enjambre")
	if has_kind("trueno"):
		_ojo_update_mark(c)
	else:
		for m in enemies:
			m["marked"] = false
	if c["cd"] > 0.0:
		return
	var tgt: Dictionary = {}
	var best_d: float = 1e9
	for e in enemies:
		if e["dead"] or absi(int(e["lane"]) - int(c["lane"])) > 1:
			continue
		var d: float = absf(e["x"] - c["x"])
		if d > float(st["range"]):
			continue
		if with_horno and e["burn_t"] > 0.0:
			d -= 400.0
		if d < best_d:
			best_d = d
			tgt = e
	if tgt.is_empty():
		return
	c["cd"] = float(st["cd"])
	var was_burning: bool = tgt["burn_t"] > 0.0
	damage_enemy(tgt, float(st["dmg"]), c["id"])
	events.append({"t": "ojo_shot", "id": c["id"], "target": tgt["id"], "x": tgt["x"], "lane": tgt["lane"]})
	if with_horno and was_burning:
		_ojo_chain(c, tgt)


func _ojo_chain(c: Dictionary, origin: Dictionary) -> void:
	var st: Dictionary = _stats("ojo")
	var cand: Array = []
	for e in enemies:
		if e["dead"] or e["id"] == origin["id"] or e["burn_t"] <= 0.0:
			continue
		if absi(int(e["lane"]) - int(c["lane"])) > 1:
			continue
		if absf(e["x"] - origin["x"]) <= float(st["chain_range"]):
			cand.append(e)
	var ox: float = origin["x"]
	cand.sort_custom(func(a, b): return absf(a["x"] - ox) < absf(b["x"] - ox))
	var ids: Array = []
	var n: int = mini(cand.size(), int(st["chain_count"]))
	for i in n:
		var ce: Dictionary = cand[i]
		damage_enemy(ce, float(st["chain_dmg"]), c["id"])
		ids.append(ce["id"])
	if ids.size() > 0:
		events.append({"t": "ojo_chain", "id": c["id"], "from": origin["id"], "to": ids})


func _ojo_update_mark(c: Dictionary) -> void:
	var st: Dictionary = _stats("ojo")
	for cur in enemies:
		if cur["marked"] and not cur["dead"]:
			return
	var best: Dictionary = {}
	var best_score: float = -1.0
	for e in enemies:
		if e["dead"] or absf(e["x"] - c["x"]) > float(st["mark_range"]):
			continue
		var pr: float = _support_priority(e["kind"])
		if pr <= 0.0:
			continue
		var score: float = pr * 10000.0 + e["x"]
		if score > best_score:
			best_score = score
			best = e
	if not best.is_empty():
		best["marked"] = true
		events.append({"t": "ojo_mark", "id": c["id"], "target": best["id"]})


# --- Enemigos ----------------------------------------------------------------

func _frontmost_creature(lane: int) -> Dictionary:
	var best: Dictionary = {}
	var bx: float = -1.0
	for c in creatures:
		if c["dead"] or c["fallen"] or c["air"] or c["lane"] != lane:
			continue
		if c["x"] > bx:
			bx = c["x"]
			best = c
	return best


func _blocker(e: Dictionary, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var bx: float = -1.0
	for c in creatures:
		if c["dead"] or c["fallen"] or c["air"] or c["lane"] != e["lane"]:
			continue
		if c["x"] <= e["x"] + 8.0 and e["x"] - c["x"] <= reach and c["x"] > bx:
			bx = c["x"]
			best = c
	return best


func _rearmost_creature_in_range(e: Dictionary, rng_r: float) -> Dictionary:
	var best: Dictionary = {}
	var bx: float = 1e9
	for c in creatures:
		if c["dead"] or c["fallen"] or c["air"] or c["lane"] != e["lane"]:
			continue
		if c["x"] < e["x"] and e["x"] - c["x"] <= rng_r and c["x"] < bx:
			bx = c["x"]
			best = c
	return best


func _blocked_by_ally(e: Dictionary, gap: float) -> bool:
	for a in enemies:
		if a["id"] == e["id"] or a["dead"] or a["lane"] != e["lane"]:
			continue
		if a["x"] < e["x"] and e["x"] - a["x"] < gap:
			return true
	return false


func _hit_door(amount: float, e: Dictionary) -> void:
	amount *= wrath_dmg() * (1.0 + augur_fx("door_dmg"))
	door_hp -= amount
	events.append({"t": "door_hit", "lane": e["lane"], "x": e["x"], "amount": amount})


func _update_enemy(e: Dictionary, dt: float) -> void:
	if e["dead"]:
		return
	var st: Dictionary = B["enemies"][e["kind"]]
	e["cd"] = maxf(0.0, e["cd"] - dt)
	if st.get("burn_immune", false):
		e["burn_t"] = 0.0
	if st.get("unstoppable", false):
		e["held"] = 0.0
		e["stun"] = 0.0
		e["pull_t"] = 0.0
		e["tar"] = 0.0
	if e["burn_t"] > 0.0:
		e["burn_t"] -= dt
		damage_enemy(e, float(e["burn_dps"]) * dt, -1, false)
		if e["dead"]:
			return
	if e["held"] > 0.0:
		e["held"] -= dt
	if float(e.get("tar", 0.0)) > 0.0:
		e["tar"] = float(e["tar"]) - dt
	if e["stun"] > 0.0:
		e["stun"] -= dt
	if st.get("support", false) and e["stun"] <= 0.0:
		e["heal_t"] -= dt
		if e["heal_t"] <= 0.0 and st.get("pulse", false):
			e["heal_t"] = float(st["heal_cd"])
			var healed: int = 0
			for a in enemies:
				if a["dead"] or epos(a).distance_to(epos(e)) > float(st["heal_radius"]):
					continue
				if a["hp"] < a["max_hp"]:
					healed += 1
				a["hp"] = minf(a["max_hp"], a["hp"] + float(st["heal"]))
			events.append({"t": "heal_pulse", "x": e["x"], "lane": e["lane"], "r": float(st["heal_radius"]), "healed": healed})
		elif e["heal_t"] <= 0.0:
			e["heal_t"] = float(st["heal_cd"])
			for a in enemies:
				if a["dead"] or a["lane"] != e["lane"]:
					continue
				if absf(a["x"] - e["x"]) <= float(st["heal_radius"]):
					a["hp"] = minf(a["max_hp"], a["hp"] + float(st["heal"]))
			events.append({"t": "heal", "x": e["x"], "lane": e["lane"]})
	if st.has("shield_cd") and e["stun"] <= 0.0:
		e["shield_t"] -= dt
		if e["shield_t"] <= 0.0:
			e["shield_t"] = float(st["shield_cd"])
			var n_sh: int = 0
			for a3 in enemies:
				if a3["dead"] or epos(a3).distance_to(epos(e)) > float(st["shield_radius"]):
					continue
				a3["shield"] = maxf(float(a3.get("shield", 0.0)), float(st["shield"]) * wrath_hp())
				n_sh += 1
			events.append({"t": "shield_pulse", "x": e["x"], "lane": e["lane"], "r": float(st["shield_radius"]), "n": n_sh})
	if st.has("judge_cd"):
		_boss_judgment(e, st, dt)
	if st.get("bell", false) and e["stun"] <= 0.0:
		e["bell_t"] -= dt
		if e["bell_t"] <= 0.0:
			e["bell_t"] = float(st["bell_cd"])
			var front: Dictionary = _frontmost_creature(int(e["lane"]))
			if not front.is_empty():
				front["stun"] = float(st["stun"])
				events.append({"t": "bell", "lane": e["lane"], "id": front["id"], "x": e["x"]})
	if st.has("ring_cd") and e["stun"] <= 0.0:
		e["ring_t"] -= dt
		if e["ring_t"] <= 0.0:
			e["ring_t"] = float(st["ring_cd"])
			var rc: Vector2 = epos(e)
			var hit_n: int = 0
			for c in creatures:
				if c["dead"] or c["fallen"] or c["air"]:
					continue
				if _creature_point(c).distance_to(rc) <= float(st["ring_r"]):
					c["stun"] = maxf(c["stun"], float(st["ring_stun"]))
					c["windup"] = 0.0
					hit_n += 1
			events.append({"t": "ring", "x": e["x"], "lane": e["lane"], "r": float(st["ring_r"]), "hit": hit_n})
	if e["pull_t"] > 0.0:
		e["pull_t"] -= dt
		var dxp: float = e["pull_x"] - e["x"]
		var stp: float = float(e["pull_speed"]) * dt
		if absf(dxp) <= stp:
			e["x"] = e["pull_x"]
		else:
			e["x"] += signf(dxp) * stp
		return
	if e["stun"] > 0.0:
		return
	var door_x: float = float(B["arena"]["door_x"])
	if st.has("sweep_dmg"):
		e["sweep_cd_t"] = maxf(0.0, e["sweep_cd_t"] - dt)
		if e["sweep_t"] > 0.0:
			e["sweep_t"] -= dt
			if e["sweep_t"] <= 0.0:
				_tajo_sweep(e, st)
			return
		if e["sweep_cd_t"] <= 0.0 and not _blocker(e, float(st["reach"]) + 40.0).is_empty():
			e["sweep_t"] = float(st["sweep_wind"])
			events.append({"t": "sweep_wind", "id": e["id"], "x": e["x"], "lane": e["lane"], "wind": float(st["sweep_wind"])})
			return
	if st.get("ranged", false):
		var r: float = float(st["range"])
		if e["aim_t"] > 0.0:
			e["aim_t"] -= dt
			if e["aim_t"] <= 0.0:
				_tirador_fire(e, st)
			return
		var tgt: Dictionary = _rearmost_creature_in_range(e, r)
		if not tgt.is_empty():
			if e["cd"] <= 0.0:
				e["cd"] = float(st["cd"])
				if st.has("aim"):
					e["aim_t"] = float(st["aim"])
					events.append({"t": "aim", "id": e["id"], "x": e["x"], "lane": e["lane"], "range": r, "aim": float(st["aim"])})
					return
				damage_creature(tgt, float(st["dmg"]))
				events.append({"t": "shot", "x": e["x"], "lane": e["lane"], "tx": tgt["x"]})
			return
		if e["x"] - door_x <= r:
			if e["cd"] <= 0.0:
				e["cd"] = float(st["cd"])
				_hit_door(float(st["door_dmg"]), e)
			return
	else:
		var blocker: Dictionary = {} if st.get("ignore_block", false) else _blocker(e, float(st["reach"]))
		if st.get("explode", false) and e["x"] - door_x <= float(st["reach"]) + 20.0:
			_hit_door(float(st["door_dmg"]), e)
			e["dead"] = true
			events.append({"t": "explode", "x": e["x"], "lane": e["lane"], "id": e["id"], "y": epos(e).y})
			return
		if not blocker.is_empty():
			if e["cd"] <= 0.0 and float(st["dmg"]) > 0.0:
				e["cd"] = float(st["cd"])
				damage_creature(blocker, float(st["dmg"]))
				var ex: float = float(st.get("execute", 0.0))
				if ex > 0.0 and not blocker["dead"] and not blocker["fallen"] and blocker["hp"] / blocker["max_hp"] < ex:
					events.append({"t": "execute", "id": blocker["id"]})
					damage_creature(blocker, blocker["hp"])
			return
		if e["x"] - door_x <= float(st["reach"]) + 20.0:
			if e["cd"] <= 0.0 and float(st["door_dmg"]) > 0.0:
				e["cd"] = float(st["cd"])
				_hit_door(float(st["door_dmg"]), e)
			return
	if e["held"] > 0.0:
		return
	if st.get("support", false):
		for a2 in enemies:
			if a2["dead"] or a2["lane"] != e["lane"] or a2["kind"] == e["kind"]:
				continue
			if a2["x"] < e["x"] and e["x"] - a2["x"] < float(st["follow_gap"]):
				return
	elif not st.get("ignore_block", false) and _blocked_by_ally(e, 20.0):
		return
	e["x"] -= float(st["speed"]) * dt * _haste_mult(e) * (1.0 + augur_fx("enemy_speed"))


# Virote de torno: atraviesa a todas las criaturas de la fila (hasta 3) con daño decreciente.
func _tirador_fire(e: Dictionary, st: Dictionary) -> void:
	var line: Array = []
	for c in creatures:
		if c["dead"] or c["fallen"] or c["air"] or c["lane"] != e["lane"]:
			continue
		if c["x"] < e["x"] and e["x"] - c["x"] <= float(st["range"]):
			line.append(c)
	line.sort_custom(func(a, b): return a["x"] > b["x"])
	var k: float = 1.0
	var far_x: float = e["x"] - 40.0
	for i in mini(line.size(), int(st["pierce"])):
		damage_creature(line[i], float(st["dmg"]) * k)
		far_x = line[i]["x"]
		k *= 0.7
	events.append({"t": "tirador_shot", "x": e["x"], "lane": e["lane"], "tx": far_x, "hits": mini(line.size(), int(st["pierce"]))})


# Barrido del hacha: golpea a todo lo que esté en el semicírculo frontal.
func _tajo_sweep(e: Dictionary, st: Dictionary) -> void:
	e["sweep_cd_t"] = float(st["sweep_cd"])
	var centre: Vector2 = epos(e) + Vector2(-60.0, 0.0)
	var n: int = 0
	for c in creatures:
		if c["dead"] or c["fallen"] or c["air"]:
			continue
		if _creature_point(c).distance_to(centre) <= float(st["sweep_r"]):
			damage_creature(c, float(st["sweep_dmg"]))
			n += 1
	events.append({"t": "sweep", "x": centre.x, "lane": e["lane"], "y": centre.y, "r": float(st["sweep_r"]), "hits": n})


# --- Jefe y élites del segundo asedio -----------------------------------------------

# Al bajar de cada umbral de vida, el jefe llama a su escolta junto a él.
func _check_summon(e: Dictionary, st: Dictionary) -> void:
	if e["dead"] or not st.has("summon_at"):
		return
	var marks: Array = st["summon_at"]
	var i: int = int(e["summons"])
	if i >= marks.size() or e["hp"] / e["max_hp"] > float(marks[i]):
		return
	e["summons"] = i + 1
	var k: int = 0
	for kind in st["summon"]:
		spawn_queue.push_front({"t": wave_time, "lane": (int(e["lane"]) + k) % 3, "kind": String(kind), "x": float(e["x"]) + 50.0 + 30.0 * k})
		k += 1
	events.append({"t": "summon", "id": e["id"], "x": e["x"], "lane": e["lane"]})


# Juicio: marca el carril con más criaturas y, tras un aviso, golpea a todas las de ese carril.
func _boss_judgment(e: Dictionary, st: Dictionary, dt: float) -> void:
	if e["judge_wind"] > 0.0:
		e["judge_wind"] -= dt
		if e["judge_wind"] <= 0.0:
			var hit: int = 0
			for c in creatures:
				if c["dead"] or c["fallen"] or c["air"] or int(c["lane"]) != int(e["judge_lane"]):
					continue
				if float(c["x"]) < float(e["x"]):
					damage_creature(c, float(st["judge_dmg"]))
					hit += 1
			events.append({"t": "judgment", "lane": e["judge_lane"], "x": e["x"], "hit": hit})
		return
	e["judge_t"] -= dt
	if e["judge_t"] > 0.0:
		return
	var counts: Array = [0, 0, 0]
	for c2 in creatures:
		if not c2["dead"] and not c2["fallen"] and not c2["air"] and float(c2["x"]) < float(e["x"]):
			counts[int(c2["lane"])] += 1
	var best: int = int(e["lane"])
	for l in 3:
		if counts[l] > counts[best]:
			best = l
	e["judge_t"] = float(st["judge_cd"])
	e["judge_wind"] = float(st["judge_wind"])
	e["judge_lane"] = best
	events.append({"t": "judgment_wind", "lane": best, "x": e["x"], "wind": float(st["judge_wind"]), "id": e["id"]})


# --- Bestias del segundo pack ----------------------------------------------------

# Gárgola de Ceniza: tanque que, herida, se vuelve piedra (inmune); al romperse devuelve lo encajado en una onda.
func _ai_gargola(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("gargola")
	if c["state"] == "stone":
		c["t"] += dt
		if c["t"] < float(st["stone_time"]):
			return
		c["state"] = "home"
		c["skill_cd"] = float(st["stone_cd"])
		var dmg: float = float(st["shock_dmg"]) + float(c.get("stored", 0.0)) * float(st["shock_mult"])
		var cp: Vector2 = _creature_point(c)
		var n: int = 0
		for e in enemies:
			if not e["dead"] and epos(e).distance_to(cp) <= float(st["shock_r"]):
				damage_enemy(e, dmg, c["id"])
				n += 1
		c["hp"] = minf(c["max_hp"], c["hp"] + c["max_hp"] * float(st["stone_heal"]))
		c["stored"] = 0.0
		events.append({"t": "stone_break", "id": c["id"], "x": c["x"], "lane": c["lane"], "r": float(st["shock_r"]), "hits": n})
		return
	_melee_step(c, st, dt, c["home_x"])
	if c["skill_cd"] <= 0.0 and c["hp"] < c["max_hp"] * float(st["stone_at"]):
		c["state"] = "stone"
		c["t"] = 0.0
		c["stored"] = 0.0
		events.append({"t": "stone", "id": c["id"]})


# Enjambre Ígneo: desde atrás manda moscas a los enemigos más enteros y les prende fuego.
func _ai_enjambre(c: Dictionary) -> void:
	if c["cd"] > 0.0:
		return
	var st: Dictionary = _stats("enjambre")
	var cand: Array = []
	for e in enemies:
		if e["dead"]:
			continue
		var dx: float = e["x"] - c["x"]
		if dx < 0.0 or dx > float(st["range"]):
			continue
		cand.append(e)
	if cand.is_empty():
		return
	cand.sort_custom(func(a, b):
		var ba: bool = a["burn_t"] > 0.0
		var bb: bool = b["burn_t"] > 0.0
		if ba != bb:
			return bb
		return a["hp"] > b["hp"])
	var ids: Array = []
	for i in mini(cand.size(), int(st["targets"])):
		var t: Dictionary = cand[i]
		damage_enemy(t, float(st["swarm_dmg"]), c["id"])
		if not t["dead"] and not B["enemies"][t["kind"]].get("burn_immune", false):
			t["burn_t"] = maxf(t["burn_t"], float(st["burn_time"]))
			t["burn_dps"] = maxf(t["burn_dps"], float(st["burn_dps"]))
		ids.append(t["id"])
	c["cd"] = float(st["cd"])
	events.append({"t": "swarm", "id": c["id"], "targets": ids})


# Ánima del Garfio: engancha a un apoyo o tirador lejano y lo arrastra hasta la vanguardia.
func _ai_garfio(c: Dictionary, dt: float) -> void:
	var st: Dictionary = _stats("garfio")
	if c["windup"] > 0.0:
		c["windup"] -= dt
		if c["windup"] <= 0.0:
			var t: Dictionary = enemy_by_id(int(c["target"]))
			if not t.is_empty() and not t["dead"] and not B["enemies"][t["kind"]].get("unstoppable", false):
				t["lane"] = c["lane"]
				t["pull_t"] = 0.5
				t["pull_x"] = c["x"] + 46.0
				t["pull_speed"] = absf(t["x"] - t["pull_x"]) / 0.5
				t["stun"] = maxf(t["stun"], float(st["hook_stun"]))
				damage_enemy(t, float(st["hook_dmg"]), c["id"])
				events.append({"t": "hook", "id": c["id"], "target": t["id"], "lane": c["lane"], "from_x": c["x"]})
		return
	_melee_step(c, st, dt, c["home_x"])
	if c["skill_cd"] > 0.0:
		return
	var best: Dictionary = {}
	var best_sc: float = -1.0
	for e in enemies:
		if e["dead"] or absi(int(e["lane"]) - int(c["lane"])) > 1:
			continue
		var dx: float = e["x"] - c["x"]
		if dx < float(st["hook_min"]) or dx > float(st["hook_range"]):
			continue
		if B["enemies"][e["kind"]].get("unstoppable", false):
			continue
		var sc: float = _support_priority(e["kind"]) * 10000.0 + e["x"]
		if sc > best_sc:
			best_sc = sc
			best = e
	if best.is_empty():
		return
	c["windup"] = float(st["hook_windup"])
	c["target"] = best["id"]
	c["skill_cd"] = float(st["hook_cd"])
	events.append({"t": "hook_windup", "id": c["id"], "target": best["id"]})


func _cleanup() -> void:
	var alive_e: Array = []
	for e in enemies:
		if not e["dead"]:
			alive_e.append(e)
	enemies = alive_e
	var keep: Array = []
	for c in creatures:
		if not c["dead"]:
			keep.append(c)
	creatures = keep


func _check_end() -> void:
	if door_hp <= 0.0:
		door_hp = 0.0
		phase = "defeat"
		defeat_wave = wave_index + 1
		events.append({"t": "defeat", "wave": defeat_wave})
		return
	if spawn_queue.is_empty() and enemies.is_empty():
		_wave_cleared()


func _wave_cleared() -> void:
	var cleared: int = wave_index + 1
	var w: Dictionary = WAVES[wave_index]
	souls += int(B["economy"]["wave_bonus"]) + int(fadd("eco.wave_bonus")) + int(augur_fx("souls"))
	souls += mini(25, int(float(souls) * fadd("special.interest")))
	door_hp = minf(door_max, door_hp + door_max * fadd("door.regen"))
	events.append({"t": "wave_clear", "wave": cleared})
	if meta_mode:
		_gain_essence(int(round(float(int(B["meta"]["wave_base"]) + int(B["meta"]["wave_step"]) * cleared) * (1.0 + augur_fx("essence")))))
	if augur != "":
		events.append({"t": "augur_done", "id": augur})
	augur = ""
	augur_offer.clear()
	for c in creatures:
		if c["fallen"]:
			c["fallen"] = false
			c["scars"] += 1
			events.append({"t": "revived", "id": c["id"]})
		_reset_combat_state(c)
	zones.clear()
	pending_brasas.clear()
	wave_index += 1
	if is_endless() and wave_index >= WAVES.size():
		WAVES.append(_gen_wave(WAVES.size()))
	if wave_index >= WAVES.size():
		phase = "victory"
		if meta_mode:
			_gain_essence(int(B["meta"]["victory"]))
		events.append({"t": "victory"})
		return
	if draft_enabled:
		make_draft()
	var after: String = String(w.get("after", "prep"))
	if after == "route":
		phase = "route"
		message = "Elige a qué heraldo reciben tus bestias."
	elif after == "forge":
		relic = String(ROUTES[route]["relic"])
		phase = "forge"
		message = "Has conseguido el %s." % relic
	else:
		phase = "prep"
		_prepare_next()


# ----------------------------------------------------------------------------
# Árbol de habilidades
# ----------------------------------------------------------------------------

func _invalidate() -> void:
	_fx_valid = false
	_fx_cache.clear()
	_stat_cache.clear()


func _fx_totals() -> Dictionary:
	if _fx_valid:
		return _fx_cache
	_fx_cache = {}
	for id in skills:
		var r: int = int(skills[id])
		if r <= 0 or not SK.has(id):
			continue
		for f in SK[id]["fx"]:
			_fx_add(f, r)
	# dones de la partida: mismos efectos que el árbol
	for bid in boons:
		for f2 in draft_def(String(bid)).get("fx", []):
			_fx_add(f2, 1)
	_fx_valid = true
	return _fx_cache


func _fx_add(f: Dictionary, r: int) -> void:
	var k: String = f["k"]
	if not _fx_cache.has(k):
		_fx_cache[k] = {"mul": 0.0, "add": 0.0}
	_fx_cache[k]["mul"] += float(f.get("mul", 0.0)) * r
	_fx_cache[k]["add"] += float(f.get("add", 0.0)) * r


func draft_def(id: String) -> Dictionary:
	for o in B["draft"]["pool"]:
		if String(o["id"]) == id:
			return o
	return {}


func fmul(k: String) -> float:
	var t: Dictionary = _fx_totals()
	return float(t[k]["mul"]) if t.has(k) else 0.0


func fadd(k: String) -> float:
	var t: Dictionary = _fx_totals()
	return float(t[k]["add"]) if t.has(k) else 0.0


# Estadísticas base de una bestia o un hechizo con el árbol aplicado.
func _stats(kind: String) -> Dictionary:
	if _stat_cache.has(kind):
		return _stat_cache[kind]
	var is_beast: bool = B.has(kind)
	var base: Dictionary = B[kind] if is_beast else B["spells"][kind]
	var d: Dictionary = base.duplicate(true)
	for key in d.keys():
		var v: Variant = d[key]
		var t: int = typeof(v)
		if t != TYPE_INT and t != TYPE_FLOAT and t != TYPE_ARRAY:
			continue
		var m: float = fmul(kind + "." + key)
		var a: float = fadd(kind + "." + key)
		if is_beast and (key == "speed" or key == "leash" or key == "cd"):
			m += fmul("beast." + key)
		var f: float = maxf(0.3, 1.0 + m)
		if t == TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(float(x) * f)
			d[key] = arr
		else:
			d[key] = float(v) * f + a
	_stat_cache[kind] = d
	return d


## Elección tras cada oleada: 3 opciones al azar (ponderadas) del pool de data/balance.json.
func make_draft() -> void:
	draft.clear()
	var cfg: Dictionary = B["draft"]
	var cands: Array = []
	for o in cfg["pool"]:
		if _draft_ok(o):
			cands.append(o)
	while draft.size() < int(cfg["count"]) and not cands.is_empty():
		var tot: float = 0.0
		for o in cands:
			tot += float(o.get("weight", 1))
		var r: float = rng.randf() * tot
		var idx: int = cands.size() - 1
		for i in cands.size():
			r -= float(cands[i].get("weight", 1))
			if r <= 0.0:
				idx = i
				break
		var o: Dictionary = cands[idx]
		cands.remove_at(idx)
		var title: String = label(String(o["kind"])) if o["type"] == "beast" else String(o.get("title", o["id"]))
		draft.append({"id": o["id"], "type": o["type"], "kind": o.get("kind", ""), "title": title, "desc": String(o.get("desc", "")),
			"amount": float(o.get("amount", 0)), "rarity": String(o.get("rarity", "comun")), "icon": String(o.get("icon", ""))})
	if not draft.is_empty():
		events.append({"t": "draft"})


func _draft_ok(o: Dictionary) -> bool:
	match String(o["type"]):
		"beast":
			var st: Dictionary = B[String(o["kind"])]
			return not find_spot(String(st.get("spot", "front"))).is_empty()
		"door":
			return door_hp < door_max
		"essence":
			return meta_mode
		"boon":
			return not boons.has(String(o["id"])) and wave_index >= int(o.get("min_wave", 1))
	return true


func draft_pick(i: int) -> bool:
	if phase != "prep" or i < 0 or i >= draft.size():
		return false
	var o: Dictionary = draft[i]
	match String(o["type"]):
		"beast":
			var kind: String = String(o["kind"])
			var spot: Dictionary = find_spot(String(B[kind].get("spot", "front")))
			if spot.is_empty():
				return false
			var nc: Dictionary = _new_creature(kind, spot)
			creatures.append(nc)
			_note_seen(kind)
		"souls":
			souls += int(o["amount"])
		"door":
			door_hp = minf(door_max, door_hp + door_max * float(o["amount"]))
		"essence":
			_gain_essence(int(o["amount"]))
		"boon":
			boons.append(String(o["id"]))
			_invalidate()
			var nm: float = float(B["door"]["hp"]) * (1.0 + fmul("door.hp"))
			door_hp += nm - door_max
			door_max = nm
			refresh_creatures()
	events.append({"t": "draft_pick", "id": o["id"]})
	draft.clear()
	return true


func _gain_essence(n: int) -> void:
	n = int(round(float(n) * (1.0 + float(B["wrath"]["essence"]) * float(wrath))))
	essence += n
	events.append({"t": "essence", "n": n})


func currency() -> int:
	return essence if meta_mode else souls


func skill_rank(id: String) -> int:
	return int(skills.get(id, 0))


func skill_cost(id: String) -> int:
	var nd: Dictionary = SK[id]
	var r: int = skill_rank(id)
	if r >= int(nd["max"]):
		return -1
	var base: int = int(nd["cost_base"]) + int(nd["cost_step"]) * r
	if not meta_mode:
		return base
	# inflación: cada rango ya comprado encarece el siguiente (el árbol no se agota en 3 partidas)
	return int(round(float(base) * (1.0 + float(B["meta"].get("inflation", 0.0)) * float(skill_points_spent()))))


# "max" | "route" | "locked" | "poor" | "ok"
func skill_state(id: String) -> String:
	var nd: Dictionary = SK[id]
	if skill_rank(id) >= int(nd["max"]):
		return "max"
	for b in BRANCHES:
		if not meta_mode and b["id"] == nd["branch"] and String(b["route"]) != "" and route != String(b["route"]):
			return "route"
	for r in nd["req"]:
		if skill_rank(r["id"]) < int(r["rank"]):
			return "locked"
	if currency() < skill_cost(id):
		return "poor"
	return "ok"


func can_skill(id: String) -> bool:
	var ok_phase: bool = phase == "prep" or (meta_mode and (phase == "victory" or phase == "defeat"))
	return ok_phase and SK.has(id) and skill_state(id) == "ok"


func buy_skill(id: String) -> bool:
	if not can_skill(id):
		return false
	if meta_mode:
		essence -= skill_cost(id)
	else:
		souls -= skill_cost(id)
	skills[id] = skill_rank(id) + 1
	_invalidate()
	var nm: float = float(B["door"]["hp"]) * (1.0 + fmul("door.hp"))
	door_hp += nm - door_max
	door_max = nm
	refresh_creatures()
	events.append({"t": "skill", "id": id, "rank": skill_rank(id)})
	return true


func skill_points_spent() -> int:
	var n: int = 0
	for id in skills:
		n += int(skills[id])
	return n
