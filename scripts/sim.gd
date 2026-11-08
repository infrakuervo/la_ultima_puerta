extends RefCounted
## Lógica pura de La Última Puerta: sin dibujo ni audio.
## La vista (main.gd) lee el estado y consume `events`; los tests lo manejan directamente.
## Todos los números salen de res://data/balance.json y res://data/waves.json.

const TICK: float = 1.0 / 30.0

var B: Dictionary = {}
var WAVES: Array = []
var ROUTES: Dictionary = {}
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
var up_brasa: bool = false
var up_rayo: bool = false
var kills: int = 0
var seen_forms: Array = []       # formas vistas (bestiario); la vista lo persiste
var message: String = ""


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	B = load_json("res://data/balance.json")
	var w: Dictionary = load_json("res://data/waves.json")
	WAVES = w["waves"]
	ROUTES = w["routes"]
	reset()


static func load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return {}
	return JSON.parse_string(f.get_as_text())


func reset() -> void:
	phase = "prep"
	wave_index = 0
	defeat_wave = 0
	door_max = float(B["door"]["hp"])
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
	up_brasa = false
	up_rayo = false
	kills = 0
	wave_time = 0.0
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
	return int(B["economy"]["costs"][item])


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


func level_cost(c: Dictionary) -> int:
	var costs: Array = B["economy"]["level_costs"]
	var i: int = int(c["level"]) - 1
	if i < 0 or i >= costs.size():
		return -1
	return int(costs[i])


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
	c["max_hp"] = float(B[c["kind"]]["hp"]) * stat_mult(c)
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
		"brasa_radio":
			return not up_brasa
		"rayo_cadena":
			return not up_rayo
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
		"brasa_radio":
			up_brasa = true
		"rayo_cadena":
			up_rayo = true
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
	t["max_hp"] = float(st["hp"]) * stat_mult(t)
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
	if phase != "prep":
		return false
	spawn_queue = _build_spawns(WAVES[wave_index])
	enemies.clear()
	zones.clear()
	phase = "combat"
	wave_time = 0.0
	brasa_cd = 0.0
	rayo_cd = 0.0
	pending_brasas.clear()
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
		var gap: float = float(g.get("gap", 1.0))
		var d: float = float(g.get("delay", 0.0))
		for i in n:
			q.append({"t": d + gap * i, "lane": int(g["lane"]), "kind": kind})
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


func _new_creature(kind: String, spot: Dictionary) -> Dictionary:
	var st: Dictionary = B[kind]
	var c: Dictionary = {
		"id": next_id, "kind": kind, "name": label(kind), "named": false, "level": 1,
		"lane": int(spot["lane"]), "home_lane": int(spot["lane"]),
		"x": float(spot["x"]), "home_x": float(spot["x"]),
		"hp": float(st["hp"]), "max_hp": float(st["hp"]),
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
		"hp": float(st["hp"]), "max_hp": float(st["hp"]),
		"cd": rng.randf() * 0.6, "held": 0.0, "stun": 0.0,
		"burn_t": 0.0, "burn_dps": 0.0,
		"pull_t": 0.0, "pull_x": 0.0, "pull_speed": 0.0, "fed": false,
		"marked": false, "heal_t": float(st.get("heal_cd", 2.0)), "bell_t": float(st.get("bell_cd", 4.0)) * 0.7,
		"dead": false, "bump": rng.randf(), "yo": rng.randf_range(-30.0, 30.0),
	}
	next_id += 1
	enemies.append(e)


func damage_enemy(e: Dictionary, amount: float, src: int = -1, armored: bool = true) -> void:
	if e["dead"]:
		return
	var st: Dictionary = B["enemies"][e["kind"]]
	if src >= 0:
		var attacker: Dictionary = creature_by_id(src)
		if not attacker.is_empty():
			amount *= stat_mult(attacker)
	var mult: float = float(st.get("armor", 1.0)) if armored else 1.0
	e["hp"] -= amount * mult
	if armored:
		events.append({"t": "hit", "x": e["x"], "lane": e["lane"]})
	if e["hp"] <= 0.0:
		e["dead"] = true
		souls += int(st["reward"])
		kills += 1
		var c: Dictionary = creature_by_id(src)
		if not c.is_empty():
			c["kills"] += 1
		events.append({"t": "kill", "x": e["x"], "lane": e["lane"], "reward": int(st["reward"]), "id": e["id"]})


func damage_creature(c: Dictionary, amount: float) -> void:
	if c["dead"] or c["fallen"] or c["air"]:
		return
	c["hp"] -= amount
	events.append({"t": "creature_hit", "id": c["id"]})
	if c["hp"] <= 0.0:
		c["hp"] = 0.0
		if c["named"]:
			c["fallen"] = true
		else:
			c["dead"] = true
		events.append({"t": "creature_down", "id": c["id"], "named": c["named"]})


func _update_zones(dt: float) -> void:
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
				e["burn_dps"] = maxf(e["burn_dps"], float(B["horno"]["burn_dps"]))
	zones = keep


func brasa_radius() -> float:
	var c: Dictionary = B["spells"]["brasa"]
	return float(c["radius_up"]) if up_brasa else float(c["radius"])


func cast_brasa(p: Vector2) -> bool:
	if phase != "combat" or brasa_cd > 0.0:
		return false
	var c: Dictionary = B["spells"]["brasa"]
	brasa_cd = float(c["cd"])
	var r: float = brasa_radius()
	pending_brasas.append({"t": float(c["delay"]), "p": p, "r": r})
	events.append({"t": "brasa_cast", "p": p, "r": r, "delay": float(c["delay"])})
	return true


func rayo_target(p: Vector2) -> Dictionary:
	var c: Dictionary = B["spells"]["rayo"]
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


func cast_rayo(p: Vector2) -> bool:
	if phase != "combat" or rayo_cd > 0.0:
		return false
	var tgt: Dictionary = rayo_target(p)
	if tgt.is_empty():
		return false
	var c: Dictionary = B["spells"]["rayo"]
	rayo_cd = float(c["cd"])
	var tp: Vector2 = epos(tgt)
	damage_enemy(tgt, float(c["dmg"]), -1)
	events.append({"t": "rayo", "from": demon_pos(), "to": tp, "target": tgt["id"]})
	if up_rayo:
		var second: Dictionary = {}
		var sd: float = float(c["chain_range"])
		for e in enemies:
			if e["dead"] or e["id"] == tgt["id"]:
				continue
			var d: float = epos(e).distance_to(tp)
			if d <= sd:
				sd = d
				second = e
		if not second.is_empty():
			damage_enemy(second, float(c["dmg"]) * float(c["chain_frac"]), -1)
			events.append({"t": "rayo_chain", "from": tp, "to": epos(second), "target": second["id"]})
	return true


func _update_spells(dt: float) -> void:
	brasa_cd = maxf(0.0, brasa_cd - dt)
	rayo_cd = maxf(0.0, rayo_cd - dt)
	var c: Dictionary = B["spells"]["brasa"]
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
				damage_enemy(e, float(c["dmg"]), -1)
				if not e["dead"]:
					e["burn_t"] = maxf(e["burn_t"], float(c["burn_time"]))
					e["burn_dps"] = maxf(e["burn_dps"], float(c["burn_dps"]))
		events.append({"t": "brasa_land", "p": b["p"], "r": b["r"], "hits": hits})
	pending_brasas = keep


# --- Criaturas ---------------------------------------------------------------

func _update_creature(c: Dictionary, dt: float) -> void:
	if c["dead"] or c["fallen"]:
		return
	c["cd"] = maxf(0.0, c["cd"] - dt)
	c["presa_cd"] = maxf(0.0, c["presa_cd"] - dt)
	c["skill_cd"] = maxf(0.0, c["skill_cd"] - dt)
	if c["stun"] > 0.0:
		c["stun"] -= dt
		return
	match c["kind"]:
		"sabueso":
			_ai_sabueso(c, dt)
		"horno":
			_ai_horno(c, dt)
		"trueno":
			_ai_trueno(c, dt)
		"ojo":
			_ai_ojo(c)


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


func _ai_sabueso(c: Dictionary, dt: float) -> void:
	var st: Dictionary = B["sabueso"]
	if c["windup"] > 0.0:
		c["windup"] -= dt
		if c["windup"] <= 0.0:
			var t: Dictionary = enemy_by_id(int(c["target"]))
			if not t.is_empty() and not t["dead"]:
				var hold: float = float(st["presa_time"])
				if _is_hero(t["kind"]):
					hold *= 0.5
				t["held"] = hold
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


func _ai_horno(c: Dictionary, dt: float) -> void:
	var st: Dictionary = B["horno"]
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
	var st: Dictionary = B["horno"]
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
	c["skill_cd"] = float(B["horno"]["inhale_cd"])
	c["hambre"] = 0
	for e in enemies:
		e["fed"] = false


func _support_priority(kind: String) -> float:
	if kind == "clerigo":
		return 2.0
	if kind == "ballestero":
		return 1.0
	return 0.0


func _trueno_pick_target(c: Dictionary) -> Dictionary:
	var st: Dictionary = B["trueno"]
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
	var st: Dictionary = B["trueno"]
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
	var st: Dictionary = B["trueno"]
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
	var st: Dictionary = B["ojo"]
	var with_horno: bool = has_kind("horno")
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
	var st: Dictionary = B["ojo"]
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
	var st: Dictionary = B["ojo"]
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
	door_hp -= amount
	events.append({"t": "door_hit", "lane": e["lane"], "x": e["x"], "amount": amount})


func _update_enemy(e: Dictionary, dt: float) -> void:
	if e["dead"]:
		return
	var st: Dictionary = B["enemies"][e["kind"]]
	e["cd"] = maxf(0.0, e["cd"] - dt)
	if e["burn_t"] > 0.0:
		e["burn_t"] -= dt
		damage_enemy(e, float(e["burn_dps"]) * dt, -1, false)
		if e["dead"]:
			return
	if e["held"] > 0.0:
		e["held"] -= dt
	if e["stun"] > 0.0:
		e["stun"] -= dt
	if st.get("support", false):
		e["heal_t"] -= dt
		if e["heal_t"] <= 0.0:
			e["heal_t"] = float(st["heal_cd"])
			for a in enemies:
				if a["dead"] or a["lane"] != e["lane"]:
					continue
				if absf(a["x"] - e["x"]) <= float(st["heal_radius"]):
					a["hp"] = minf(a["max_hp"], a["hp"] + float(st["heal"]))
			events.append({"t": "heal", "x": e["x"], "lane": e["lane"]})
	if st.get("bell", false) and e["stun"] <= 0.0:
		e["bell_t"] -= dt
		if e["bell_t"] <= 0.0:
			e["bell_t"] = float(st["bell_cd"])
			var front: Dictionary = _frontmost_creature(int(e["lane"]))
			if not front.is_empty():
				front["stun"] = float(st["stun"])
				events.append({"t": "bell", "lane": e["lane"], "id": front["id"], "x": e["x"]})
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
	if st.get("ranged", false):
		var r: float = float(st["range"])
		var tgt: Dictionary = _rearmost_creature_in_range(e, r)
		if not tgt.is_empty():
			if e["cd"] <= 0.0:
				e["cd"] = float(st["cd"])
				damage_creature(tgt, float(st["dmg"]))
				events.append({"t": "shot", "x": e["x"], "lane": e["lane"], "tx": tgt["x"]})
			return
		if e["x"] - door_x <= r:
			if e["cd"] <= 0.0:
				e["cd"] = float(st["cd"])
				_hit_door(float(st["door_dmg"]), e)
			return
	else:
		var blocker: Dictionary = _blocker(e, float(st["reach"]))
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
	elif _blocked_by_ally(e, 20.0):
		return
	e["x"] -= float(st["speed"]) * dt


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
	souls += int(B["economy"]["wave_bonus"])
	events.append({"t": "wave_clear", "wave": cleared})
	for c in creatures:
		if c["fallen"]:
			c["fallen"] = false
			c["scars"] += 1
			events.append({"t": "revived", "id": c["id"]})
		_reset_combat_state(c)
	zones.clear()
	pending_brasas.clear()
	wave_index += 1
	if wave_index >= WAVES.size():
		phase = "victory"
		events.append({"t": "victory"})
		return
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
