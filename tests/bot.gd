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
		if e["burn_t"] > 0.0 and s.fadd("special.rayo_arc") > 0.0:
			sc += 500.0   # con Arco voltaico apunta a los que arden: desde ahí salta
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
	# encargo: uno al azar la mitad de las veces
	if not s.contract_offer.is_empty() and s.wave_index == 0 and rng.randf() < 0.5:
		s.choose_contract(String(s.contract_offer[rng.randi() % s.contract_offer.size()]))
	# augurio: lo coge al azar un 60% de las veces (BAL_AUGUR=0 nunca, =1 siempre)
	if not s.augur_offer.is_empty():
		var rate: float = float(OS.get_environment("BAL_AUGUR")) if OS.has_environment("BAL_AUGUR") else 0.6
		if rng.randf() < rate:
			s.choose_augur(String(s.augur_offer[rng.randi() % s.augur_offer.size()]))


const META_PRIORITY: Array = [
	"brasa_radio", "rayo_cadena", "beast_hp", "brasa_cd", "brasa_dmg", "rayo_dmg", "door_hp", "beast_dmg",
	"brasa_radio", "brasa_cd", "rayo_cd", "brasa_dmg", "beast_hp", "beast_dmg", "brasa_delay", "rayo_dmg",
]

## Estilos de compra en el árbol (para comparar builds con tools/balance.tscn):
## - order: lista de deseos; un id repetido pide un rango más. Si lo siguiente es una piedra angular
##   y no llega la esencia, ahorra en vez de gastar en otra cosa.
## - branches: ramas donde gasta lo que sobra (lo más barato primero); luego, en cualquiera.
## - keys / paths: piedras angulares y caminos excluyentes que acepta. El resto no lo compra nunca
##   (una piedra angular tiene contrapartida: no se coge por ser barata).
## - route: heraldo que prefiere (su rama de ruta), el 80% de las veces.
const STYLES: Dictionary = {
	"mixto": {
		"order": META_PRIORITY,
		"branches": [],
		"keys": [],
		"paths": ["brasa_ascuas", "rayo_chispa", "door_baluarte", "beast_horda", "sab_cepo", "horno_boca", "trueno_meteoro", "ojo_vigia", "abi_guardia", "inq_cadenas"],
		"route": "",
	},
	"fuego": {
		"order": ["brasa_radio", "rayo_cadena", "brasa_cd", "brasa_dmg", "rayo_dmg", "brasa_radio", "brasa_dmg", "brasa_cd", "beast_hp", "door_hp",
			"brasa_dmg", "brasa_burn", "brasa_infierno", "brasa_tierra", "rayo_dmg", "rayo_dmg", "rayo_arco", "rayo_cd", "rayo_cd",
			"brasa_delay", "brasa_stun", "brasa_burn", "brasa_echo", "brasa_cometa", "brasa_cometa",
			"horno_hp", "horno_spit", "horno_spit", "horno_burn", "horno_burn", "horno_ceniza", "inq_trofeos", "inq_hereje", "inq_sellos", "inq_sordo", "inq_velo", "inq_notario", "inq_profeta", "inq_fuego"],
		"branches": ["brasa", "rayo", "horno", "inquisicion"],
		"keys": ["brasa_tierra", "rayo_arco", "horno_ceniza"],
		"paths": ["brasa_cometa", "rayo_verdugo", "door_baluarte", "beast_alfa", "sab_cepo", "horno_fragua", "trueno_meteoro", "ojo_vigia", "abi_plaga", "inq_fuego"],
		"route": "verdugo",
	},
	"manada": {
		"order": ["beast_hp", "brasa_radio", "beast_dmg", "sab_hp", "rayo_cadena", "beast_hp", "door_hp", "beast_dmg", "sab_hp", "sab_camada",
			"sab_presa_cd", "sab_dmg", "beast_hp", "beast_dmg", "beast_cd", "beast_cd", "beast_speed", "beast_leash", "beast_jauria",
			"beast_pack", "beast_dmg", "beast_scar", "beast_horda", "beast_horda", "door_hp", "door_regen", "door_espinas",
			"sab_presa_time", "sab_presa_time", "sab_dmg", "sab_desgarro", "sab_range", "sab_leash", "sab_carnicero",
			"abi_llamada", "abi_gargola_hp", "abi_enjambre_burn", "abi_garfio_cd", "abi_garfio_stun", "abi_guardia"],
		"branches": ["bestias", "jauria", "demonio", "trueno", "abismo"],
		"keys": ["sab_camada", "door_espinas", "trueno_errante"],
		"paths": ["brasa_ascuas", "rayo_chispa", "eco_mercader", "beast_horda", "sab_carnicero", "horno_boca", "trueno_relampago", "ojo_parpadeo", "abi_guardia", "inq_cadenas"],
		"route": "inquisidor",
	},
}

var style: String = "mixto"


func _allowed(s, id: String, st: Dictionary) -> bool:
	var nd: Dictionary = s.SK[id]
	if bool(nd.get("keystone", false)):
		return st["keys"].has(id)
	if nd.has("excl"):
		return st["paths"].has(id)
	return true


func _cheapest(s, st: Dictionary, branches: Array) -> String:
	var best: String = ""
	var cc: int = 1 << 30
	for id in s.SK_ORDER:
		if not branches.is_empty() and not branches.has(String(s.SK[id]["branch"])):
			continue
		if s.can_skill(id) and _allowed(s, id, st) and s.skill_cost(id) < cc:
			cc = s.skill_cost(id)
			best = id
	return best


## Compra en el árbol permanente según el estilo: lista de deseos, luego lo más barato de sus ramas
## y por último lo más barato de cualquiera.
func buy_meta(s) -> void:
	var st: Dictionary = STYLES.get(style, STYLES["mixto"])
	var guard: int = 0
	while guard < 400:
		guard += 1
		var pick: String = ""
		var want: Dictionary = {}
		for id in st["order"]:
			if not s.SK.has(id):
				continue
			want[id] = int(want.get(id, 0)) + 1
			if s.skill_rank(id) >= int(want[id]):
				continue
			if s.can_skill(id):
				pick = id
				break
			if bool(s.SK[id].get("keystone", false)) and s.skill_state(id) == "poor":
				return   # ahorra para la piedra angular
		if pick == "" and not st["branches"].is_empty():
			pick = _cheapest(s, st, st["branches"])
		if pick == "":
			pick = _cheapest(s, st, [])
		if pick == "":
			return
		s.buy_skill(pick)


## Juega una partida entera con el árbol que ya tenga `s` (modo permanente y draft activos).
func play(s, route: String = "") -> Dictionary:
	if route == "":
		route = "verdugo" if rng.randf() < 0.5 else "inquisidor"
		var pref: String = String(STYLES.get(style, {}).get("route", ""))
		if pref != "" and s.skill_points_spent() > 0 and rng.randf() < 0.8:
			route = pref
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
				if ticks > 30 * 60 * (120 if s.is_endless() else 30):
					break
	return {"phase": s.phase, "wave": s.wave_index + (1 if s.phase != "victory" else 0), "door": int(s.door_hp), "route": route, "seconds": ticks / 30, "alive": alive}
