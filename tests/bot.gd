extends RefCounted
## Jugador automático «torpe», parecido a una persona en su primera partida:
## - reacciona tarde: decide cada `think` s y lanza con `delay` s de retraso sobre la posición vieja;
## - apunta con error (ruido gaussiano de `aim_err` px) y no siempre se adelanta al avance;
## - a veces se distrae (`lapse`) y deja pasar el hechizo;
## - tiene que cambiar de hechizo (cuesta `switch` s), como con el ratón;
## - entre oleadas toma decisiones medianas: elige en el draft con preferencia moderada,
##   compra lo que puede de vez en cuando y coloca las bestias en su sitio por defecto.
## Se usa en tests/suite.gd (comprobación rápida) y en tools/balance.tscn (informe largo).

const Sim = preload("res://scripts/sim.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var think: float = 0.45
var delay: float = 0.3
var aim_err: float = 38.0
var lead: float = 0.5        # fracción del adelanto ideal
var lapse: float = 0.18
var switch: float = 0.4
var skill_level: float = 0.0  # 0 = torpe; 1 = hábil (para comparar)

var _t: float = 0.0
var _spell: String = "brasa"
var _busy: float = 0.0
var _queued: Dictionary = {}


func _init(seed_v: int = 1, level: float = 0.0) -> void:
	rng.seed = seed_v * 7919 + 13
	skill_level = level
	think = lerpf(0.45, 0.15, level)
	delay = lerpf(0.3, 0.12, level)
	aim_err = lerpf(38.0, 12.0, level)
	lead = lerpf(0.5, 0.95, level)
	lapse = lerpf(0.18, 0.03, level)
	switch = lerpf(0.4, 0.2, level)


func _gauss() -> float:
	return clampf(rng.randfn(0.0, 1.0), -2.5, 2.5)


# --- combate -------------------------------------------------------------------

func combat_tick(s, dt: float) -> void:
	if s.phase != "combat":
		return
	_busy = maxf(0.0, _busy - dt)
	if not _queued.is_empty():
		_queued["t"] -= dt
		if _queued["t"] <= 0.0:
			if _queued["spell"] == "brasa":
				s.cast_brasa(_queued["p"])
			else:
				s.cast_rayo(_queued["p"])
			_queued = {}
		return
	_t -= dt
	if _t > 0.0 or _busy > 0.0:
		return
	_t = think * rng.randf_range(0.7, 1.3)
	if s.enemies.is_empty():
		return
	if rng.randf() < lapse:
		_t += rng.randf_range(0.3, 1.2)
		return
	# ¿qué hechizo quiere? Brasa si hay grupo y está lista; si no, Rayo.
	var want: String = ""
	var target: Vector2 = Vector2.ZERO
	if s.brasa_cd <= 0.0:
		var bp: Dictionary = _brasa_pick(s)
		if not bp.is_empty() and float(bp["score"]) >= 2.0:
			want = "brasa"
			target = bp["p"]
	if want == "" and s.rayo_cd <= 0.0:
		var rp: Dictionary = _rayo_pick(s)
		if not rp.is_empty():
			want = "rayo"
			target = rp["p"]
	if want == "":
		return
	if want != _spell:
		_spell = want
		_busy = switch
		return
	var err: Vector2 = Vector2(_gauss(), _gauss() * 0.7) * aim_err
	_queued = {"spell": want, "p": target + err, "t": delay}


func _brasa_pick(s) -> Dictionary:
	var r: float = s.brasa_radius()
	var dl: float = float(s._stats("brasa")["delay"])
	var best: Dictionary = {}
	var best_score: float = 0.0
	for e in s.enemies:
		var st: Dictionary = s.B["enemies"][e["kind"]]
		var p: Vector2 = s.epos(e) + Vector2(-float(st["speed"]) * (dl + delay) * lead, 0.0)
		var score: float = 0.0
		for o in s.enemies:
			if s.epos(o).distance_to(p) <= r:
				score += 1.0
		if score > best_score:
			best_score = score
			best = {"p": p, "score": score}
	return best


func _rayo_pick(s) -> Dictionary:
	var origin: Vector2 = s.demon_pos()
	var best: Dictionary = {}
	var best_sc: float = -1e9
	for e in s.enemies:
		var ep: Vector2 = s.epos(e)
		if ep.distance_to(origin) > float(s._stats("rayo")["range"]):
			continue
		var kind: String = e["kind"]
		var sc: float = 1000.0 - ep.x + rng.randf_range(0.0, 300.0)
		var st: Dictionary = s.B["enemies"][kind]
		# Una persona mediana reconoce a los apoyos con farol la mitad de las veces.
		if st.get("support", false) and rng.randf() < 0.5 + 0.4 * skill_level:
			sc += 1500.0
		if st.get("hero", false) or st.get("boss", false):
			sc += 600.0
		if sc > best_sc:
			best_sc = sc
			best = {"p": ep}
	return best


# --- entre oleadas ---------------------------------------------------------------

const DRAFT_PREF: Dictionary = {"alacran": 3.0, "sapo": 2.5, "manta": 2.5, "gargola": 2.8, "enjambre": 2.4, "garfio": 2.4, "sabueso": 2.0, "souls": 1.5, "door": 1.0, "essence": 0.6}


func prep(s) -> void:
	# draft: preferencia moderada con ruido; repara la Puerta si está muy tocada.
	if not s.draft.is_empty():
		var bi: int = 0
		var bs: float = -1.0
		for i in s.draft.size():
			var o: Dictionary = s.draft[i]
			var key: String = String(o["kind"]) if String(o["type"]) == "beast" else String(o["type"])
			var sc: float = float(DRAFT_PREF.get(key, 1.5)) + rng.randf_range(0.0, 2.0)
			if OS.get_environment("BAL_BAN").split(",").has(key):
				sc -= 100.0
			if String(o["type"]) == "door" and s.door_hp < s.door_max * 0.5:
				sc += 3.0
			if sc > bs:
				bs = sc
				bi = i
		s.draft_pick(bi)
	# compras: no siempre en el mejor momento
	if rng.randf() < 0.7 and s.can_buy("ojo") and s.wave_index >= 1:
		s.buy("ojo")
	if rng.randf() < 0.6 and s.can_buy("sabueso"):
		s.buy("sabueso")
	var t: Dictionary = s.named_creature()
	if not t.is_empty() and rng.randf() < 0.6 and s.can_level(int(t["id"])):
		s.level_up(int(t["id"]))
	for c in s.creatures:
		if not c["named"] and rng.randf() < 0.25 and s.can_level(int(c["id"])):
			s.level_up(int(c["id"]))


const META_PRIORITY: Array = [
	"brasa_radio", "rayo_cadena", "beast_hp", "brasa_cd", "brasa_dmg", "rayo_dmg", "door_hp", "beast_dmg",
	"brasa_radio", "brasa_cd", "rayo_cd", "brasa_dmg", "beast_hp", "beast_dmg", "brasa_delay", "rayo_dmg",
]


## Compra en el árbol permanente: primero una lista corta y luego lo más barato disponible.
func buy_meta(s) -> void:
	var guard: int = 0
	while guard < 200:
		guard += 1
		var bought: bool = false
		for id in META_PRIORITY:
			if s.SK.has(id) and s.can_skill(id):
				s.buy_skill(id)
				bought = true
				break
		if not bought:
			var cheapest: String = ""
			var cc: int = 1 << 30
			for id2 in s.SK_ORDER:
				if s.can_skill(id2) and s.skill_cost(id2) < cc:
					cc = s.skill_cost(id2)
					cheapest = id2
			if cheapest == "":
				return
			s.buy_skill(cheapest)


## Juega una partida entera con el árbol que ya tenga `s` (modo permanente y draft activos).
func play(s, route: String = "") -> Dictionary:
	if route == "":
		route = "verdugo" if rng.randf() < 0.5 else "inquisidor"
	var guard: int = 0
	var ticks: int = 0
	var alive: Array = []
	while s.phase != "victory" and s.phase != "defeat" and guard < 600000:
		guard += 1
		match s.phase:
			"prep":
				prep(s)
				alive.append("%d/%d" % [s.creatures.size(), int(s.door_hp)])
				if not s.start_wave():
					s.draft.clear()
					s.start_wave()
			"route":
				s.choose_route(route)
			"forge":
				s.give_relic()
			"combat":
				combat_tick(s, Sim.TICK)
				s.step(Sim.TICK)
				s.events.clear()
				ticks += 1
				if ticks > 30 * 60 * 30:
					break
	return {"phase": s.phase, "wave": s.wave_index + (1 if s.phase != "victory" else 0), "door": int(s.door_hp), "route": route, "seconds": ticks / 30, "alive": alive}
