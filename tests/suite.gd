extends Node
## Suite de pruebas (nodo). Se lanza con tests/run_tests.gd (línea de comandos) o con tests/run_scene.tscn (editor).
## Sale con código 0 si todo pasa y 1 si algo falla. También imprime un informe de equilibrio.

const Sim = preload("res://scripts/sim.gd")
const Bot = preload("res://tests/bot.gd")
const Anim = preload("res://scripts/anim.gd")

var failures: int = 0
var checks: int = 0


func run() -> void:
	# Se espera un fotograma para que el árbol de escenas esté listo (_ready de Main).
	await get_tree().process_frame
	test_data()
	test_basic_combat()
	test_presa()
	test_spells()
	test_levels()
	test_fallen_returns_with_scar()
	test_route_and_forge_flow()
	test_horno()
	test_trueno_leaves_hole()
	test_ojo_chain_and_mark()
	test_ojo_loan()
	test_economy()
	test_elites()
	test_meta()
	test_beasts()
	test_draft()
	test_bugfixes()
	test_content()
	test_skills()
	test_full_runs()
	test_clumsy_bot()
	test_anim()
	test_inflation()
	test_procedural()
	test_boons()
	test_endless()
	test_logros()
	test_music()
	test_contracts()
	test_terrain()
	test_save_run()
	await test_ui_smoke()
	print("")
	print("Comprobaciones: %d, fallos: %d" % [checks, failures])
	print("FIN_SUITE fallos=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok    ", msg)
	else:
		failures += 1
		print("  FALLO ", msg)


# --- utilidades ---------------------------------------------------------------

func new_sim(seed_v: int = 7):
	return Sim.new(seed_v)


func to_combat(s) -> void:
	# Pone la simulación en combate sin oleada propia: una entrada lejana evita que termine.
	s.phase = "combat"
	s.enemies.clear()
	s.zones.clear()
	s.spawn_queue = [{"t": 99999.0, "lane": 0, "kind": "campesino"}]
	s.wave_time = 0.0
	for c in s.creatures:
		s._reset_combat_state(c)


func add_enemy(s, kind: String, lane: int, x: float) -> Dictionary:
	s._spawn_enemy(kind, lane)
	var e: Dictionary = s.enemies[s.enemies.size() - 1]
	e["x"] = x
	e["cd"] = 0.0
	return e


func run_ticks(s, n: int) -> Array:
	var names: Array = []
	for i in n:
		s.step(Sim.TICK)
		for ev in s.events:
			names.append(String(ev["t"]))
		s.events.clear()
	return names


func mutate_tizon(s, route: String) -> void:
	s.route = route
	s.phase = "forge"
	s.give_relic()
	s.events.clear()


# --- pruebas ------------------------------------------------------------------

func test_data() -> void:
	print("Datos")
	var s = new_sim()
	check(s.wave_count() == 6, "hay seis oleadas")
	check(s.B["zones"].has("front") and s.B["zones"].has("rear"), "hay zonas de vanguardia y retaguardia")
	check(s.ROUTES.has("verdugo") and s.ROUTES.has("inquisidor"), "hay dos rutas")
	check(s.named_creature()["name"] == "Tizón", "Tizón empieza en la partida")
	check(int(s.preview_totals(2).get("campesino", 0)) == 14, "la oleada 3 trae 14 campesinos")
	check(not s.preview(2)[3].is_empty(), "la oleada 3 llega por frentes sorteados")


func test_basic_combat() -> void:
	print("Combate básico (oleada 1)")
	var s = new_sim()
	check(s.start_wave(), "se puede iniciar la oleada 1")
	var guard: int = 0
	while s.phase == "combat" and guard < 30 * 120:
		bot_cast(s)
		s.step(Sim.TICK)
		s.events.clear()
		guard += 1
	check(s.phase == "prep", "la oleada 1 termina y vuelve a preparación (fase %s)" % s.phase)
	check(s.wave_index == 1, "avanza a la oleada 2")
	check(s.door_hp > 0.0, "la Puerta sigue en pie (%d)" % int(s.door_hp))
	check(s.souls > 40, "se ganan almas (%d)" % s.souls)
	check(s.kills == 4, "caen los 4 campesinos")


func test_presa() -> void:
	print("Presa de Tizón")
	var s = new_sim()
	to_combat(s)
	var e: Dictionary = add_enemy(s, "escudero", 1, 560.0)
	var seen: Array = run_ticks(s, 60)
	check(seen.has("presa_windup") and seen.has("presa"), "Tizón prepara y ejecuta la Presa")
	check(seen.has("bite"), "Tizón muerde")


func test_spells() -> void:
	print("Hechizos del demonio")
	var s = new_sim()
	check(not s.cast_brasa(Vector2(500, 380)), "no se lanza fuera del combate")
	to_combat(s)
	var a: Dictionary = add_enemy(s, "campesino", 0, 700.0)
	var b: Dictionary = add_enemy(s, "campesino", 0, 740.0)
	a["yo"] = 0.0
	b["yo"] = 0.0
	var far: Dictionary = add_enemy(s, "campesino", 2, 700.0)
	far["yo"] = 0.0
	for q in [a, b, far]:
		q["stun"] = 10.0   # quietos: la Brasa tarda en caer y los enemigos andan
	var hp_a: float = float(a["hp"])
	check(s.cast_brasa(Vector2(720, s.lane_y(0))), "se lanza la Brasa")
	check(not s.cast_brasa(Vector2(720, s.lane_y(0))), "la Brasa respeta su enfriamiento")
	check(float(a["hp"]) == hp_a, "la Brasa tarda en caer: aún no hace daño")
	var seen: Array = run_ticks(s, 60)
	check(seen.has("brasa_land"), "la Brasa cae")
	check(float(a["hp"]) < hp_a and float(b["hp"]) < hp_a + 1.0, "la Brasa daña en área")
	check(float(far["hp"]) == float(far["max_hp"]), "la Brasa no toca a quien está fuera del círculo")
	check(float(a["burn_t"]) > 0.0 or a["dead"], "la Brasa prende a los alcanzados")
	# radio mayor con la mejora
	var r0: float = s.brasa_radius()
	s.souls = 100
	check(s.phase == "combat" and not s.buy_skill("brasa_radio"), "no se compran habilidades en combate")
	s.phase = "prep"
	check(s.buy_skill("brasa_radio"), "se compra el radio de Brasa")
	s.phase = "combat"
	check(s.brasa_radius() > r0, "la mejora aumenta el radio de la Brasa")
	# Rayo
	var s2 = new_sim()
	to_combat(s2)
	var t1: Dictionary = add_enemy(s2, "escudero", 1, 600.0)
	t1["yo"] = 0.0
	var t2: Dictionary = add_enemy(s2, "escudero", 1, 660.0)
	t2["yo"] = 0.0
	var pt: Vector2 = s2.epos(t1)
	var h1: float = float(t1["hp"])
	check(s2.cast_rayo(pt + Vector2(10, 0)), "el Rayo golpea a un enemigo cerca del cursor")
	check(float(t1["hp"]) < h1, "el Rayo hace daño de inmediato")
	check(float(t2["hp"]) == float(t2["max_hp"]), "sin la mejora no salta")
	check(not s2.cast_rayo(pt), "el Rayo respeta su enfriamiento")
	check(not s2.cast_rayo(Vector2(1200, 100)), "sin objetivo cerca no se lanza ni gasta enfriamiento")
	var s3 = new_sim()
	s3.skills["rayo_cadena"] = 1
	s3._invalidate()
	to_combat(s3)
	var c1: Dictionary = add_enemy(s3, "escudero", 1, 600.0)
	c1["yo"] = 0.0
	var c2: Dictionary = add_enemy(s3, "escudero", 1, 660.0)
	c2["yo"] = 0.0
	s3.cast_rayo(s3.epos(c1))
	check(float(c2["hp"]) < float(c2["max_hp"]), "con la mejora el Rayo salta a un segundo blanco")
	var s4 = new_sim()
	to_combat(s4)
	var out: Dictionary = add_enemy(s4, "campesino", 1, 1100.0)
	out["yo"] = 0.0
	check(not s4.cast_rayo(s4.epos(out)), "el Rayo tiene alcance limitado")


func test_levels() -> void:
	print("Subir estadísticas")
	var s = new_sim()
	s.souls = 200
	var t: Dictionary = s.named_creature()
	var tid: int = int(t["id"])
	check(s.level_up(tid), "se sube a Tizón de nivel")
	check(int(t["level"]) == 2 and s.souls == 170, "cuesta 30 almas")
	check(float(t["max_hp"]) > float(s.B["sabueso"]["hp"]), "sube su vida máxima")
	check(s.level_up(tid) and int(t["level"]) == 3, "se sube al nivel 3")
	check(not s.level_up(tid), "el nivel 3 es el máximo")
	mutate_tizon(s, "verdugo")
	check(float(t["max_hp"]) > float(s.B["horno"]["hp"]), "la mutación conserva el nivel")
	to_combat(s)
	check(not s.level_up(tid), "no se sube de nivel en combate")
	var e: Dictionary = add_enemy(s, "ballestero", 1, 600.0)
	var base: float = float(e["hp"])
	s.damage_enemy(e, 10.0, tid, false)
	check(base - float(e["hp"]) > 10.0, "el daño de Tizón crece con el nivel")


func test_fallen_returns_with_scar() -> void:
	print("Vínculo: Tizón vuelve con cicatriz")
	var s = new_sim()
	to_combat(s)
	var t: Dictionary = s.named_creature()
	var tid: int = int(t["id"])
	s.damage_creature(t, 9999.0)
	check(t["fallen"] and not t["dead"], "Tizón cae pero no muere")
	s.enemies.clear()
	s.spawn_queue.clear()
	var seen: Array = run_ticks(s, 2)
	var t2: Dictionary = s.named_creature()
	check(seen.has("revived"), "Tizón vuelve gratis al terminar la oleada")
	check(int(t2["id"]) == tid and t2["name"] == "Tizón", "conserva identidad y nombre")
	check(int(t2["scars"]) == 1, "gana una cicatriz")
	check(not t2["fallen"] and t2["hp"] == t2["max_hp"], "vuelve entero")
	# Una criatura sin nombre muere de verdad.
	var s2 = new_sim()
	s2.souls = 500
	s2.buy("sabueso")
	to_combat(s2)
	var other: Dictionary = {}
	for c in s2.creatures:
		if not c["named"]:
			other = c
	s2.damage_creature(other, 9999.0)
	s2.enemies.clear()
	s2.spawn_queue.clear()
	run_ticks(s2, 2)
	check(s2.creatures.size() == 1, "una criatura sin nombre no vuelve")


func test_route_and_forge_flow() -> void:
	print("Ruta y reliquia")
	for r in ["verdugo", "inquisidor"]:
		var s = new_sim()
		s.souls = 300
		s.wave_index = 3
		s.phase = "combat"
		s.enemies.clear()
		s.spawn_queue.clear()
		run_ticks(s, 2)
		check(s.phase == "route", "[%s] tras la oleada 4 se elige ruta" % r)
		check(s.choose_route(r), "[%s] se elige la ruta" % r)
		check(s.phase == "prep" and s.wave_index == 4, "[%s] oleada 5 en preparación" % r)
		var want: String = r
		check(int(s.preview_totals(4).get(want, 0)) == 1, "[%s] la oleada 5 muestra a %s" % [r, want])
		s.start_wave()
		s.enemies.clear()
		s.spawn_queue.clear()
		run_ticks(s, 2)
		check(s.phase == "forge", "[%s] tras el héroe llega la reliquia" % r)
		check(s.give_relic(), "[%s] se entrega la reliquia" % r)
		var t: Dictionary = s.named_creature()
		check(t["kind"] == String(s.ROUTES[r]["form"]) and t["name"] == "Tizón", "[%s] Tizón muta y conserva el nombre" % r)
		check(s.seen_forms.has(String(s.ROUTES[r]["form"])), "[%s] el bestiario anota la forma" % r)
		check(s.phase == "prep" and s.wave_index == 5, "[%s] oleada 6 en preparación" % r)
		check(s.has_kind("ojo"), "[%s] la oleada 6 presta un Ojo de Latón" % r)


func test_horno() -> void:
	print("Horno de Fosas")
	var s = new_sim()
	mutate_tizon(s, "verdugo")
	to_combat(s)
	var t: Dictionary = s.named_creature()
	var lane: int = int(t["lane"])
	var es: Array = []
	for i in 3:
		es.append(add_enemy(s, "campesino", lane, 700.0 + i * 30.0))
	var seen: Array = run_ticks(s, 30 * 8)
	check(seen.has("horno_inhale"), "el Horno inhala")
	check(seen.has("horno_spit"), "el Horno escupe fuego")
	check(s.kills >= 2, "la llamarada mata o quema a varios (%d bajas)" % s.kills)


func test_trueno_leaves_hole() -> void:
	print("Sabueso del Trueno")
	var s = new_sim()
	mutate_tizon(s, "inquisidor")
	to_combat(s)
	var t: Dictionary = s.named_creature()
	var home_x: float = float(t["home_x"])
	var support: Dictionary = add_enemy(s, "clerigo", 2, 900.0)
	support["hp"] = 9999.0
	support["max_hp"] = 9999.0
	var shield: Dictionary = add_enemy(s, "escudero", 1, 660.0)
	shield["hp"] = 9999.0
	shield["max_hp"] = 9999.0
	var jumped: bool = false
	var away_min_x: float = 99999.0
	var landed: bool = false
	for i in 30 * 9:
		s.step(Sim.TICK)
		for ev in s.events:
			if ev["t"] == "trueno_jump":
				jumped = true
			if ev["t"] == "trueno_land":
				landed = true
		s.events.clear()
		if t["state"] != "home" and not shield.is_empty():
			away_min_x = minf(away_min_x, float(shield["x"]))
		shield["hp"] = 9999.0
		support["hp"] = 9999.0
	check(jumped, "el Trueno salta hacia el apoyo")
	check(landed, "aterriza y descarga")
	check(away_min_x < home_x - 20.0, "mientras está fuera el escudero se cuela por el hueco (x mínima %d, casilla %d)" % [int(away_min_x), int(home_x)])
	check(t["state"] == "home" or t["state"] == "return" or t["state"] == "rear", "el Trueno acaba volviendo (estado %s)" % t["state"])


func test_ojo_chain_and_mark() -> void:
	print("Ojo de Latón")
	var s = new_sim()
	mutate_tizon(s, "verdugo")
	s.souls = 500
	s.buy("ojo")
	to_combat(s)
	var lane: int = 1
	for i in 3:
		var e: Dictionary = add_enemy(s, "escudero", lane, 560.0 + i * 25.0)
		e["burn_t"] = 8.0
		e["burn_dps"] = 0.0
		e["hp"] = 5000.0
		e["max_hp"] = 5000.0
	var seen: Array = run_ticks(s, 60)
	check(seen.has("ojo_shot"), "el Ojo dispara")
	check(seen.has("ojo_chain"), "el Ojo encadena sobre enemigos en llamas (combo con el Horno)")
	var s2 = new_sim()
	mutate_tizon(s2, "inquisidor")
	s2.souls = 500
	s2.buy("ojo")
	to_combat(s2)
	var sup: Dictionary = add_enemy(s2, "ballestero", 1, 900.0)
	sup["hp"] = 5000.0
	sup["max_hp"] = 5000.0
	var seen2: Array = run_ticks(s2, 60)
	check(seen2.has("ojo_mark"), "el Ojo marca el objetivo del Trueno")
	check(bool(sup["marked"]), "el objetivo queda marcado")


func test_ojo_loan() -> void:
	print("Préstamo del Ojo")
	var s = new_sim()
	s.souls = 0
	mutate_tizon(s, "verdugo")
	s.wave_index = 5
	s._prepare_next()
	var found: bool = false
	for c in s.creatures:
		if c["kind"] == "ojo" and c["loaned"]:
			found = true
	check(found, "la oleada 6 presta un Ojo")
	s.souls = 100
	check(s.can_buy("ojo"), "se puede quedar el Ojo pagándolo")
	s.buy("ojo")
	var still_loaned: bool = false
	for c2 in s.creatures:
		if c2["kind"] == "ojo" and c2["loaned"]:
			still_loaned = true
	check(not still_loaned, "pagar convierte el préstamo en compra")


func test_economy() -> void:
	print("Economía y colocación")
	var s = new_sim()
	check(s.souls == 40, "se empieza con 40 almas")
	check(s.buy("sabueso") and s.souls == 0, "se recluta un Sabueso por 40")
	check(not s.can_buy("ojo"), "sin almas no se compra")
	var t: Dictionary = s.named_creature()
	check(s.place_at(int(t["id"]), 330.0, 1), "se puede colocar a Tizón en la retaguardia")
	check(float(t["home_x"]) == 330.0 and int(t["home_lane"]) == 1, "ocupa el sitio elegido")
	var other: Dictionary = {}
	for c in s.creatures:
		if not c["named"]:
			other = c
	check(not s.place_at(int(other["id"]), 340.0, 1), "no caben dos bestias encimadas")
	check(not s.place_at(int(t["id"]), 500.0, 7), "carril inexistente rechazado")
	check(s.place_at(int(t["id"]), 50.0, 2) and float(t["home_x"]) == s.zone_min_x(), "fuera de zona se ajusta al borde")
	s.start_wave()
	check(not s.place_at(int(t["id"]), 500.0, 1), "no se recoloca en combate")
	var s2 = new_sim()
	s2.souls = 500
	check(not s2.can_buy("brasa_radio"), "las mejoras de hechizo ya no son compras sueltas")


# --- partidas completas -------------------------------------------------------

func dump(s) -> String:
	var out: Array = []
	out.append("fase=%s oleada=%d t=%.1f puerta=%d almas=%d" % [s.phase, s.wave_index + 1, s.wave_time, int(s.door_hp), s.souls])
	for c in s.creatures:
		out.append("  criatura %s %s carril=%d x=%d hp=%d/%d estado=%s fallen=%s dead=%s stun=%.1f" % [c["name"], c["kind"], c["lane"], int(c["x"]), int(c["hp"]), int(c["max_hp"]), c["state"], str(c["fallen"]), str(c["dead"]), c["stun"]])
	for e in s.enemies:
		out.append("  enemigo %s carril=%d x=%d hp=%d/%d held=%.1f stun=%.1f" % [e["kind"], e["lane"], int(e["x"]), int(e["hp"]), int(e["max_hp"]), e["held"], e["stun"]])
	out.append("  pendientes por entrar: %d" % s.spawn_queue.size())
	return "\n".join(out)


## Política de colocación del jugador automático: lo fuerte va al carril más cargado de la
## próxima oleada, y el Ojo detrás de él. Las bestias de melé van delante, los Ojos detrás.
## Política de colocación del jugador automático: bestias de melé en la vanguardia repartidas
## por los tres carriles (los frentes se sortean), el Ojo en la retaguardia.
func arrange(s) -> void:
	var front: Array = []
	var ojos: Array = []
	for c in s.creatures:
		if c["dead"]:
			continue
		if c["kind"] == "ojo":
			ojos.append(c)
		else:
			front.append(c)
	front.sort_custom(func(a, b): return (0 if a["named"] else 1) < (0 if b["named"] else 1))
	var lanes: Array = [1, 0, 2]
	for i in front.size():
		s.place_at(int(front[i]["id"]), 620.0 - float(i / 3) * 62.0, lanes[i % 3])
	for j in ojos.size():
		s.place_at(int(ojos[j]["id"]), 360.0 - float(j / 3) * 62.0, lanes[j % 3])


## Jugador automático con el ratón: Brasa sobre el grupo más denso (adelantándose al avance)
## y Rayo sobre apoyos, héroes o lo más cercano a la Puerta. Reacciona en cada tick.
func bot_cast(s) -> void:
	if s.phase != "combat" or s.enemies.is_empty():
		return
	if s.brasa_cd <= 0.0:
		var r: float = s.brasa_radius()
		var best_score: float = 0.0
		var best_p: Vector2 = Vector2.ZERO
		for e in s.enemies:
			var st: Dictionary = s.B["enemies"][e["kind"]]
			var p: Vector2 = s.epos(e) + Vector2(-float(st["speed"]) * 0.4, 0.0)
			var score: float = 0.0
			for o in s.enemies:
				if s.epos(o).distance_to(p) <= r:
					score += 1.0 + (2.0 if bool(s.B["enemies"][o["kind"]].get("hero", false)) else 0.0)
			if score > best_score:
				best_score = score
				best_p = p
		if best_score >= 2.0:
			s.cast_brasa(best_p)
	if s.rayo_cd <= 0.0:
		var pick: Dictionary = {}
		var pick_score: float = -1.0
		var origin: Vector2 = s.demon_pos()
		for e2 in s.enemies:
			var ep: Vector2 = s.epos(e2)
			if ep.distance_to(origin) > float(s.B["spells"]["rayo"]["range"]):
				continue
			var kind: String = e2["kind"]
			var sc: float = 1000.0 - ep.x
			if bool(s.B["enemies"][kind].get("elite", false)):
				sc += 1800.0
			if kind == "clerigo" or kind == "lumbrero":
				sc += 3000.0
			elif kind == "ballestero":
				sc += 2000.0
			elif bool(s.B["enemies"][kind].get("hero", false)):
				sc += 1500.0
			if sc > pick_score:
				pick_score = sc
				pick = e2
		if not pick.is_empty():
			s.cast_rayo(s.epos(pick))


const SKILL_PRIORITY: Array = [
	"rayo_cadena", "brasa_radio", "brasa_cd", "brasa_dmg", "beast_hp", "rayo_dmg", "brasa_cd", "beast_dmg",
	"brasa_radio", "rayo_cd", "brasa_dmg", "brasa_delay", "beast_hp", "beast_dmg", "rayo_dmg", "brasa_cd",
	"brasa_delay", "rayo_cd", "brasa_radio", "beast_hp", "beast_dmg", "brasa_dmg", "door_hp", "eco_reward",
]
const SKILL_ROUTE: Dictionary = {
	"verdugo": ["horno_hp", "horno_spit", "horno_inhale_cd", "horno_spit", "horno_burn"],
	"inquisidor": ["trueno_hp", "trueno_land", "trueno_cd", "trueno_land", "trueno_chain"],
}


func buy_skills(s, route: String) -> void:
	var order: Array = SKILL_PRIORITY.duplicate()
	if s.route == route:
		order = SKILL_ROUTE[route] + order
	for id in order:
		if s.can_skill(id):
			s.buy_skill(id)


func autoplay(route: String, invulnerable: bool, seed_v: int) -> Dictionary:
	var s = new_sim(seed_v)
	var total: int = 0
	var stalled: bool = false
	var wave_ticks: int = 0
	var guard: int = 0
	while s.phase != "victory" and s.phase != "defeat" and guard < 400000:
		guard += 1
		match s.phase:
			"prep":
				var n_sab: int = 0
				for c in s.creatures:
					if c["kind"] == "sabueso" and not c["named"]:
						n_sab += 1
				if s.wave_index >= 1 and n_sab < 1 and s.can_buy("sabueso"):
					s.buy("sabueso")
				if s.wave_index >= 2 and s.can_buy("ojo"):
					s.buy("ojo")
				buy_skills(s, route)
				for c2 in s.creatures:
					if c2["named"] and s.wave_index >= 3 and s.can_level(int(c2["id"])):
						s.level_up(int(c2["id"]))
				if s.wave_index >= 4 and n_sab < 2 and s.can_buy("sabueso"):
					s.buy("sabueso")
				arrange(s)
				s.start_wave()
				wave_ticks = 0
			"route":
				s.choose_route(route)
			"forge":
				s.give_relic()
			"combat":
				bot_cast(s)
				s.step(Sim.TICK)
				s.events.clear()
				total += 1
				wave_ticks += 1
				if invulnerable:
					s.door_hp = s.door_max
				if wave_ticks > 30 * 300:
					stalled = true
					break
	if stalled:
		print("  --- estado al atascarse ---")
		print(dump(s))
	return {"phase": s.phase, "wave": s.wave_index + 1, "door": int(s.door_hp), "souls": s.souls,
		"seconds": total / 30, "stalled": stalled, "dump": dump(s), "kills": s.kills, "epitaph": s.epitaph()}


func test_elites() -> void:
	print("Élites")
	# todas tienen sprite y etiqueta
	var s0 = new_sim()
	var all_ok: bool = true
	for k in ["capataz", "muro", "tirador", "lumbrero", "tajo", "campana"]:
		if not s0.B["enemies"].has(k) or not s0.B["labels"].has(k) or not FileAccess.file_exists("res://art/sprites/%s.png" % String(s0.B["enemies"][k]["sprite"])):
			all_ok = false
	check(all_ok, "las seis élites existen con etiqueta y sprite")
	# Capataz: acelera a la turba cercana
	var s = new_sim()
	to_combat(s)
	s.creatures.clear()
	var a: Dictionary = add_enemy(s, "campesino", 1, 700.0)
	a["yo"] = 0.0
	var x0: float = a["x"]
	run_ticks(s, 30)
	var plain: float = x0 - float(a["x"])
	var s2 = new_sim()
	to_combat(s2)
	s2.creatures.clear()
	var a2: Dictionary = add_enemy(s2, "campesino", 1, 700.0)
	a2["yo"] = 0.0
	var cap: Dictionary = add_enemy(s2, "capataz", 1, 760.0)
	cap["yo"] = 0.0
	run_ticks(s2, 30)
	check(x0 - float(a2["x"]) > plain * 1.2, "el Capataz acelera al campesino cercano (%.0f contra %.0f px)" % [x0 - float(a2["x"]), plain])
	# Muro: cubre al aliado de detrás
	var s3 = new_sim()
	to_combat(s3)
	var back: Dictionary = add_enemy(s3, "campesino", 1, 640.0)
	back["yo"] = 0.0
	var h0: float = float(back["hp"])
	s3.damage_enemy(back, 20.0, -1)
	var loss_open: float = h0 - float(back["hp"])
	back["hp"] = h0
	var wall: Dictionary = add_enemy(s3, "muro", 1, 580.0)
	wall["yo"] = 0.0
	s3.damage_enemy(back, 20.0, -1)
	check(h0 - float(back["hp"]) < loss_open * 0.8, "el Muro de Marfil reduce el daño al aliado de detrás")
	# Tirador: avisa y atraviesa la fila
	var s4 = new_sim()
	to_combat(s4)
	s4.creatures.clear()
	var c1: Dictionary = s4._new_creature("sabueso", {"x": 500.0, "lane": 1})
	var c2: Dictionary = s4._new_creature("sabueso", {"x": 420.0, "lane": 1})
	s4.creatures.append(c1)
	s4.creatures.append(c2)
	c1["stun"] = 99.0
	c2["stun"] = 99.0
	var tir: Dictionary = add_enemy(s4, "tirador", 1, 760.0)
	tir["yo"] = 0.0
	var hp1: float = float(c1["hp"])
	var hp2: float = float(c2["hp"])
	var seen4: Array = run_ticks(s4, 20)
	check(seen4.has("aim") and float(c1["hp"]) == hp1, "el Tirador avisa antes de disparar")
	seen4 = run_ticks(s4, 40)
	check(seen4.has("tirador_shot") and float(c1["hp"]) < hp1 and float(c2["hp"]) < hp2, "el virote atraviesa a las dos criaturas de la fila")
	# Lumbrero: cura a varios en un pulso
	var s5 = new_sim()
	to_combat(s5)
	s5.creatures.clear()
	var w1: Dictionary = add_enemy(s5, "escudero", 0, 700.0)
	var w2: Dictionary = add_enemy(s5, "escudero", 2, 720.0)
	w1["yo"] = 0.0
	w2["yo"] = 0.0
	w1["hp"] = 50.0
	w2["hp"] = 50.0
	var lum: Dictionary = add_enemy(s5, "lumbrero", 1, 760.0)
	lum["yo"] = 0.0
	lum["heal_t"] = 0.1
	run_ticks(s5, 10)
	check(float(w1["hp"]) > 60.0 and float(w2["hp"]) > 60.0, "el Lumbrero cura a varios aliados de filas distintas")
	# Tajo: barrido con aviso
	var s6 = new_sim()
	to_combat(s6)
	s6.creatures.clear()
	var d1: Dictionary = s6._new_creature("sabueso", {"x": 500.0, "lane": 1})
	var d2: Dictionary = s6._new_creature("sabueso", {"x": 500.0, "lane": 0})
	d2["lane"] = 0
	s6.creatures.append(d1)
	s6.creatures.append(d2)
	d1["stun"] = 99.0
	d2["stun"] = 99.0
	var tj: Dictionary = add_enemy(s6, "tajo", 1, 535.0)
	tj["yo"] = 0.0
	tj["sweep_cd_t"] = 0.0
	var seen6: Array = run_ticks(s6, 10)
	check(seen6.has("sweep_wind"), "el Verdugo del Tajo Negro levanta el hacha antes de barrer")
	seen6 += run_ticks(s6, 40)
	check(seen6.has("sweep") and float(d1["hp"]) < float(d1["max_hp"]), "el barrido hiere a la criatura del frente")
	# Campana: interrumpe a las criaturas cercanas
	var s7 = new_sim()
	to_combat(s7)
	s7.creatures.clear()
	var k1: Dictionary = s7._new_creature("sabueso", {"x": 500.0, "lane": 1})
	s7.creatures.append(k1)
	k1["windup"] = 0.3
	var cam: Dictionary = add_enemy(s7, "campana", 1, 700.0)
	cam["yo"] = 0.0
	cam["ring_t"] = 0.05
	run_ticks(s7, 3)
	check(float(k1["stun"]) > 1.0 and float(k1["windup"]) == 0.0, "el repique aturde e interrumpe a las criaturas cercanas")
	# oleadas con élites y vista previa
	var s8 = new_sim()
	var pv: Dictionary = s8.preview_totals(3)
	check(pv.has("muro") and pv.has("tirador"), "la oleada 4 anuncia al Muro y al Tirador")


func test_skills() -> void:
	print("Árbol de habilidades")
	var s = new_sim()
	check(s.SK.size() >= 60, "el árbol tiene muchos nodos (%d)" % s.SK.size())
	var ok_req: bool = true
	var ok_rank: bool = true
	for id in s.SK:
		var nd: Dictionary = s.SK[id]
		for r in nd["req"]:
			if not s.SK.has(r["id"]) or int(r["rank"]) > int(s.SK[r["id"]]["max"]):
				ok_req = false
		if int(nd["max"]) < 1 or int(nd["cost_base"]) < 1:
			ok_rank = false
	check(ok_req, "todos los requisitos apuntan a nodos y rangos que existen")
	check(ok_rank, "todos los nodos tienen rangos y coste válidos")
	s.souls = 500
	check(s.skill_state("brasa_dmg") == "locked", "un nodo sin su requisito está bloqueado")
	check(not s.buy_skill("brasa_dmg"), "no se compra un nodo bloqueado")
	var c0: int = s.skill_cost("brasa_radio")
	var before: int = s.souls
	check(s.buy_skill("brasa_radio") and s.souls == before - c0, "se compra un nodo y se cobra su coste")
	check(s.skill_cost("brasa_radio") > c0, "cada rango cuesta más")
	check(s.skill_state("brasa_dmg") == "ok", "el requisito desbloquea el nodo siguiente")
	for i in 5:
		s.buy_skill("brasa_radio")
	check(s.skill_rank("brasa_radio") == 5 and s.skill_state("brasa_radio") == "max", "se llega al rango máximo")
	check(not s.buy_skill("brasa_radio"), "no se pasa del máximo")
	var p: Vector2 = Vector2(600, 380)
	var s1 = new_sim()
	s1.skills["brasa_dmg"] = 0
	var d0: float = float(s1._stats("brasa")["dmg"])
	s1.souls = 500
	s1.buy_skill("brasa_radio")
	s1.buy_skill("brasa_dmg")
	check(float(s1._stats("brasa")["dmg"]) > d0, "Brasa ardiente sube el daño de la Brasa")
	s1.buy_skill("brasa_cd")
	check(float(s1._stats("brasa")["cd"]) < float(s1.B["spells"]["brasa"]["cd"]), "Fuego presto baja el enfriamiento")
	var s2 = new_sim()
	s2.souls = 500
	var tz: Dictionary = s2.named_creature()
	var hp0: float = float(tz["max_hp"])
	s2.buy_skill("beast_hp")
	check(float(tz["max_hp"]) > hp0, "Piel dura sube la vida de Tizón al momento")
	var dm0: float = s2.dmg_mult(tz)
	s2.buy_skill("beast_dmg")
	check(s2.dmg_mult(tz) > dm0, "Colmillos sube el daño de las bestias")
	var door0: float = s2.door_max
	s2.buy_skill("door_hp")
	check(s2.door_max > door0 and s2.door_hp > door0, "Puerta reforzada sube su vida")
	s2.buy_skill("eco_reward")
	to_combat(s2)
	var e: Dictionary = add_enemy(s2, "campesino", 1, 600.0)
	var so: int = s2.souls
	s2.damage_enemy(e, 9999.0, -1)
	check(s2.souls - so > int(s2.B["enemies"]["campesino"]["reward"]) - 1, "Cosecha de almas no reduce la recompensa")
	var s3 = new_sim()
	s3.souls = 500
	check(s3.skill_state("horno_hp") == "route", "las ramas de ruta están cerradas hasta elegir ruta")
	s3.route = "verdugo"
	check(s3.skill_state("horno_hp") == "ok" and s3.skill_state("trueno_hp") == "route", "solo se abre la rama de la ruta elegida")
	var tzn: Dictionary = s3.named_creature()
	tzn["kind"] = "horno"
	s3.buy_skill("horno_hp")
	s3.buy_skill("horno_spit")
	check(float(s3._stats("horno")["spit_dmg"]) > float(s3.B["horno"]["spit_dmg"]), "Llamarada sube el daño del Horno")
	s3.buy_skill("horno_inhale_cd")
	s3.buy_skill("horno_inhale_cd")
	s3.buy_skill("horno_inhale_max")
	check(int(s3._stats("horno")["inhale_max"]) == int(s3.B["horno"]["inhale_max"]) + 1, "Boca grande suma un enemigo a la inhalación")
	var s4 = new_sim()
	s4.souls = 500
	s4.buy_skill("rayo_cadena")
	s4.buy_skill("rayo_chain_n")
	check(s4.skill_state("rayo_chain_n") == "locked", "Cadena larga exige Rayo cargado")
	s4.buy_skill("rayo_dmg")
	s4.buy_skill("rayo_dmg")
	check(s4.buy_skill("rayo_chain_n"), "con Rayo cargado 2 se abre Cadena larga")
	to_combat(s4)
	var r1: Dictionary = add_enemy(s4, "escudero", 1, 600.0)
	var r2: Dictionary = add_enemy(s4, "escudero", 1, 650.0)
	var r3: Dictionary = add_enemy(s4, "escudero", 1, 700.0)
	for q in [r1, r2, r3]:
		q["yo"] = 0.0
	s4.cast_rayo(s4.epos(r1))
	check(float(r3["hp"]) < float(r3["max_hp"]), "la cadena larga alcanza un tercer blanco")
	var s5 = new_sim()
	s5.souls = 900
	var lv: Dictionary = s5.named_creature()
	s5.level_up(int(lv["id"]))
	s5.level_up(int(lv["id"]))
	check(not s5.can_level(int(lv["id"])), "sin la habilidad el nivel 3 es el máximo")
	s5.buy_skill("door_hp")
	s5.buy_skill("eco_reward")
	s5.buy_skill("eco_level")
	s5.buy_skill("eco_level")
	check(s5.buy_skill("eco_cap") or s5.skill_state("eco_cap") != "locked", "Más allá del límite se desbloquea con Maestro de la cría")
	check(s5.can_level(int(lv["id"])), "con Más allá del límite se puede subir al nivel 4")


func test_full_runs() -> void:
	print("Partidas completas automáticas")
	for r in ["verdugo", "inquisidor"]:
		var res: Dictionary = autoplay(r, true, 11)
		check(not res["stalled"], "[%s] ninguna oleada se atasca (Puerta invulnerable)" % r)
		check(res["phase"] == "victory", "[%s] se llega a la victoria (%s)" % [r, str(res)])
	print("")
	print("Informe de equilibrio (Puerta real, política automática simple, 5 semillas):")
	for r2 in ["verdugo", "inquisidor"]:
		var wins: int = 0
		var lines: Array = []
		for sd in 5:
			var res2: Dictionary = autoplay(r2, false, 100 + sd)
			if res2["phase"] == "victory":
				wins += 1
			if sd == 0 and res2["phase"] != "victory":
				print("  --- estado final ruta %s semilla 100 ---" % r2)
				print(res2["dump"])
			lines.append("    semilla %d: %s en oleada %d, Puerta %d, %d s, %s" % [100 + sd, res2["phase"], res2["wave"], res2["door"], res2["seconds"], res2["epitaph"]])
		print("  ruta %s: %d/5 victorias" % [r2, wins])
		for ln in lines:
			print(ln)


func test_clumsy_bot() -> void:
	print("Bot torpe (primera partida, árbol vacío, draft activo)")
	var wins: int = 0
	var n: int = 12
	var lost_early: int = 0
	for i in n:
		var s = Sim.new(1000 + i)
		s.meta_mode = true
		s.draft_enabled = true
		s.essence = 0
		s.reset()
		var r: Dictionary = Bot.new(1000 + i, 0.0).play(s)
		if r["phase"] == "victory":
			wins += 1
		elif int(r["wave"]) <= 3:
			lost_early += 1
	check(wins >= 3 and wins <= 10, "el bot torpe gana a veces, no siempre (%d/%d)" % [wins, n])
	check(lost_early == 0, "nadie pierde en las tres primeras oleadas (%d)" % lost_early)


# --- interfaz con el ratón ----------------------------------------------------

func test_ui_smoke() -> void:
	print("Interfaz (ratón)")
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "la escena principal carga")
	if packed == null:
		return
	Engine.set_meta("sin_persistencia", true)
	var m = packed.instantiate()
	var script_ok: bool = m.get_script() != null and m.has_method("_buttons")
	check(script_ok, "el script de la vista compila")
	if not script_ok:
		return
	get_tree().root.add_child(m)
	await get_tree().process_frame
	check(m.sim != null, "la vista crea la simulación")
	check(m.intro_layer == null, "en las pruebas no sale la intro en vídeo")
	check(ResourceLoader.exists(m.INTRO_PATH), "el vídeo de la intro existe")
	m._on_press(Vector2(1130, 660))
	check(m.sim.phase == "combat", "el botón Iniciar oleada arranca la oleada con el ratón")
	m._on_press(Vector2(1100, 660))
	m._on_release(Vector2(1100, 660))
	check(m.sim.brasa_cd == 0.0, "pulsar el panel inferior no lanza hechizos")
	m._on_press(Vector2(640, 380))
	m._on_release(Vector2(640, 380))
	check(m.sim.brasa_cd > 0.0, "clic en la arena lanza la Brasa")
	m._process(1.0 / 30.0)
	check(m.demon_anim.clip == "brasa", "al lanzar la Brasa el demonio reproduce su clip")
	m.demon_anim.play("rayo")
	m._on_event({"t": "door_hit", "lane": 1, "amount": 1})
	check(m.demon_anim.clip == "rayo", "un golpe a la Puerta no corta un lanzamiento")
	m._on_press(Vector2(95, 660))
	m._on_press(Vector2(255, 660))
	check(m.spell == "rayo", "el botón Rayo cambia de hechizo")
	var guard: int = 0
	while m.sim.phase == "combat" and guard < 30 * 120:
		bot_cast(m.sim)
		m._process(1.0 / 30.0)
		guard += 1
	check(m.sim.phase == "prep" and m.sim.wave_index == 1, "la vista avanza la oleada 1")
	m.sim.souls = 300
	m._on_press(Vector2(95, 660))
	check(m.sim.creatures.size() == 2, "el botón Sabueso recluta")
	var t: Dictionary = m.sim.named_creature()
	var from_p: Vector2 = m._creature_pos(t) + Vector2(10, -20)
	m._on_press(from_p)
	check(m.selected_id == int(t["id"]), "clic en una bestia la selecciona")
	m._on_press(Vector2(575, 660))
	check(int(t["level"]) == 2, "el botón Subir nivel sube a la bestia seleccionada")
	m._on_release(Vector2(330, m._lane_y(1)))
	check(float(t["home_x"]) == 330.0 and int(t["home_lane"]) == 1, "arrastrar con el ratón recoloca a Tizón en la retaguardia (x %d)" % int(t["home_x"]))
	m._on_press(Vector2(415, 660))
	check(m.show_tree, "el botón Árbol abre el árbol de habilidades")
	m.sim.souls = 300
	var nr: Rect2 = m._node_rect("brasa_radio")
	m._on_press(nr.get_center())
	check(m.sim.skill_rank("brasa_radio") == 1, "clic en un nodo compra un rango")
	m._on_press(m._node_rect("brasa_burn").get_center())
	check(m.sim.skill_rank("brasa_burn") == 0, "clic en un nodo bloqueado no compra")
	m._on_press(Vector2(300, 400))
	check(m.show_tree, "clic fuera de los nodos no cierra ni coloca nada")
	m._on_press(Vector2(640, 660))
	check(not m.show_tree, "el botón Cerrar árbol lo cierra")
	# menú y opciones
	m.menu.toggle(m)
	check(m.menu.open, "Esc abre el menú")
	var phase_before: String = m.sim.phase
	m._process(0.5)
	check(m.sim.phase == phase_before, "con el menú abierto el juego no avanza")
	m.menu.panel = "options"
	var v0: float = float(m.menu.opts["volumen"])
	for b in m.menu.buttons(m):
		if b["id"] == "vol-":
			m._input(_click(b["rect"].get_center()))
	check(float(m.menu.opts["volumen"]) < v0, "el botón − baja el volumen")
	var intro0: bool = bool(m.menu.opts["intro"])
	for bi in m.menu.buttons(m):
		if bi["id"] == "intro":
			m._input(_click(bi["rect"].get_center()))
	check(bool(m.menu.opts["intro"]) != intro0, "Opciones permite quitar el vídeo de inicio")
	m.menu.panel = "main"
	for b2 in m.menu.buttons(m):
		if b2["id"] == "continue":
			m._input(_click(b2["rect"].get_center()))
	check(not m.menu.open, "Continuar vuelve a la partida")
	m.sim.remix_enabled = true
	m.start_challenge()
	var wa: String = str(m.sim.WAVES)
	check(m.sim.week_augur != "" and m.record_key().begins_with("reto:"), "el reto semanal fija augurio y récord propio")
	m._restart()
	check(str(m.sim.WAVES) == wa, "reiniciar el reto da las mismas oleadas")
	m.start_normal(0, 0)
	check(m.challenge.is_empty() and m.sim.week_augur == "", "una partida normal quita el reto")
	m.sim.remix_enabled = false
	m.sim.reset()
	m.show_tree = true
	m.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	m.show_tree = false
	m.queue_redraw()
	await get_tree().process_frame
	m.queue_free()




func _click(p: Vector2) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	return ev


func test_meta() -> void:
	print("Árbol permanente (esencia)")
	var s = new_sim()
	s.meta_mode = true
	s.reset()
	check(s.essence == 0, "sin partidas previas no hay esencia")
	s.essence = 500
	var souls0: int = s.souls
	var c: int = s.skill_cost("brasa_radio")
	check(s.buy_skill("brasa_radio") and s.essence == 500 - c and s.souls == souls0, "se paga con esencia, no con almas")
	var any_route_ok: bool = true
	for id in s.SK_ORDER:
		if s.skill_state(id) == "route":
			any_route_ok = false
	check(any_route_ok, "ningún nodo queda cerrado por ruta")
	s.reset()
	check(s.skill_rank("brasa_radio") == 1, "la mejora sobrevive a reiniciar la partida")
	check(s.essence == 500 - c, "la esencia sobrevive a reiniciar")
	s.start_wave()
	s.essence = 500
	check(not s.buy_skill("brasa_dmg"), "no se compra en combate")
	s.door_hp = 0.0
	s._check_end()
	check(s.phase == "defeat" and s.can_skill("brasa_dmg"), "tras caer la Puerta se puede comprar")
	var before: int = s.essence
	var s2 = new_sim()
	s2.meta_mode = true
	s2.reset()
	s2.start_wave()
	s2.enemies.clear()
	s2.spawn_queue.clear()
	s2._check_end()
	var want_e: int = int(s2.B["meta"]["wave_base"]) + int(s2.B["meta"]["wave_step"])
	check(s2.essence == want_e, "superar la oleada 1 da %d de esencia (%d)" % [want_e, s2.essence])
	check(before >= 0, "esencia coherente")


func spawn_beast(s, kind: String, lane: int, x: float) -> Dictionary:
	var c: Dictionary = s._new_creature(kind, {"x": x, "lane": lane})
	s.creatures.append(c)
	return c


func test_beasts() -> void:
	print("Bestias nuevas")
	for k in ["alacran", "sapo", "manta"]:
		var s0 = new_sim()
		check(s0.B.has(k) and s0.label(k) != k, "%s existe y tiene nombre" % k)
		check(FileAccess.file_exists("res://art/sprites/%s.png" % k), "%s tiene sprite" % k)
	# Alacrán
	var s = new_sim()
	s.creatures.clear()
	var a: Dictionary = spawn_beast(s, "alacran", 1, 520.0)
	to_combat(s)
	var e1: Dictionary = add_enemy(s, "escudero", 1, 560.0)
	e1["hp"] = 5000.0
	e1["max_hp"] = 5000.0
	var hp0: float = e1["hp"]
	var ev: Array = run_ticks(s, 60)
	check(ev.has("presa"), "el Alacrán agarra al enemigo")
	check(e1["held"] > 1.5 and e1["held"] <= 3.0, "lo sujeta unos 3 s (%.1f)" % e1["held"])
	check(hp0 - e1["hp"] >= 28.0, "la pinza hace daño al agarrar (%d)" % int(hp0 - e1["hp"]))
	# Sapo
	var s2 = new_sim()
	s2.creatures.clear()
	var sp: Dictionary = spawn_beast(s2, "sapo", 1, 300.0)
	to_combat(s2)
	var g1: Dictionary = add_enemy(s2, "campesino", 1, 600.0)
	var g2: Dictionary = add_enemy(s2, "campesino", 1, 630.0)
	for g in [g1, g2]:
		g["hp"] = 500.0
		g["max_hp"] = 500.0
		g["stun"] = 99.0
	var far: Dictionary = add_enemy(s2, "campesino", 0, 1100.0)
	far["stun"] = 99.0
	var ev2: Array = run_ticks(s2, 45)
	check(ev2.has("sapo_windup") and ev2.has("sapo_spit"), "el Sapo avisa y escupe")
	check(g1["hp"] < 500.0 and g2["hp"] < 500.0, "la brea daña a todo el grupo")
	check(far["hp"] == float(far["max_hp"]), "no toca a quien está lejos")
	check(g1["tar"] > 0.0 and not s2.tar_pools.is_empty(), "queda un charco y los alcanzados van pegajosos")
	g1["stun"] = 0.0
	var m0: float = s2._haste_mult(g1)
	check(m0 < 1.0, "la brea ralentiza (x%.2f)" % m0)
	# Manta
	var s3 = new_sim()
	s3.creatures.clear()
	var mt: Dictionary = spawn_beast(s3, "manta", 1, 330.0)
	to_combat(s3)
	var h1: Dictionary = add_enemy(s3, "escudero", 2, 500.0)
	var h2: Dictionary = add_enemy(s3, "escudero", 2, 560.0)
	var h3: Dictionary = add_enemy(s3, "escudero", 0, 520.0)
	for h in [h1, h2, h3]:
		h["hp"] = 500.0
		h["max_hp"] = 500.0
		h["stun"] = 0.0
	var air_seen: bool = false
	var evs: Array = []
	for i in 120:
		s3.step(Sim.TICK)
		for e in s3.events:
			evs.append(String(e["t"]))
		s3.events.clear()
		if mt["air"]:
			air_seen = true
		h1["x"] = 500.0
		h2["x"] = 560.0
		h3["x"] = 520.0
	check(evs.has("manta_dive") and evs.has("manta_glide"), "la Manta avisa y se lanza")
	check(air_seen, "es intocable mientras vuela")
	check(h1["hp"] < 500.0 and h2["hp"] < 500.0, "golpea a todos los del carril")
	check(h3["hp"] == 500.0, "no toca otros carriles")
	check(mt["state"] == "home" and mt["lane"] == 1 and not mt["air"], "vuelve a su sitio (%s)" % mt["state"])


func test_bugfixes() -> void:
	print("Fallos corregidos")
	# 1) El daño especial de las bestias nuevas aplica el multiplicador de nivel una sola vez.
	var s = new_sim()
	s.creatures.clear()
	var a: Dictionary = spawn_beast(s, "alacran", 1, 520.0)
	a["level"] = 3
	to_combat(s)
	var e1: Dictionary = add_enemy(s, "campesino", 1, 560.0)
	e1["hp"] = 5000.0
	e1["max_hp"] = 5000.0
	e1["stun"] = 99.0
	a["cd"] = 99.0
	var expect: float = float(s.B["alacran"]["grab_dmg"]) * s.dmg_mult(a)
	var hp0: float = e1["hp"]
	for i in 30:
		s.step(Sim.TICK)
		a["cd"] = 99.0
		if e1["held"] > 0.0:
			break
	check(absf((hp0 - e1["hp"]) - expect) < 0.5, "la pinza de un Alacrán nivel 3 hace %.0f (esperado %.0f)" % [hp0 - e1["hp"], expect])
	# 2) La brea sigue frenando junto a un Capataz (se combinan).
	var s2 = new_sim()
	to_combat(s2)
	var g: Dictionary = add_enemy(s2, "campesino", 1, 800.0)
	add_enemy(s2, "capataz", 1, 860.0)
	g["tar"] = 2.0
	var m: float = s2._haste_mult(g)
	var want: float = float(s2.B["sapo"]["slow"]) * float(s2.B["enemies"]["capataz"]["haste"])
	check(absf(m - want) < 0.01, "brea con Capataz: x%.2f (esperado x%.2f)" % [m, want])
	# 3) Un Lumbrero aturdido no cura.
	var s3 = new_sim()
	s3.creatures.clear()
	to_combat(s3)
	var lu: Dictionary = add_enemy(s3, "lumbrero", 1, 900.0)
	var hurt: Dictionary = add_enemy(s3, "escudero", 1, 950.0)
	hurt["hp"] = 10.0
	lu["heal_t"] = 0.1
	lu["stun"] = 5.0
	for i in 30:
		s3.step(Sim.TICK)
	check(hurt["hp"] == 10.0, "el Lumbrero aturdido no cura (vida %.0f)" % hurt["hp"])
	# 4) El Trueno y la marca del Ojo también eligen a las élites de apoyo y a distancia.
	var s4 = new_sim()
	check(s4._support_priority("lumbrero") > s4._support_priority("tirador") and s4._support_priority("tirador") > 0.0, "Lumbrero y Tirador cuentan como apoyo y tirador")


func test_content() -> void:
	print("Contenido nuevo: bestias, segundo asedio, Ira")
	var s0 = new_sim()
	check(s0.SIEGES.size() >= 2 and s0.SIEGES[1]["waves"].size() >= 8, "hay segundo asedio con 8 oleadas")
	var all_ok: bool = true
	for sg in s0.SIEGES:
		for w in sg["waves"]:
			for g in w["spawns"]:
				if String(g["kind"]) != "@hero" and not s0.B["enemies"].has(String(g["kind"])):
					all_ok = false
	check(all_ok, "todas las oleadas usan enemigos definidos")
	for k in ["gargola", "enjambre", "garfio"]:
		var inpool: bool = false
		for o in s0.B["draft"]["pool"]:
			if String(o.get("kind", "")) == k:
				inpool = true
		check(s0.B.has(k) and s0.label(k) != k and inpool, "%s existe, tiene nombre y está en el draft" % k)
	# Gárgola: se vuelve piedra, no recibe daño y devuelve una onda
	var s = new_sim()
	s.creatures.clear()
	var g: Dictionary = spawn_beast(s, "gargola", 1, 520.0)
	to_combat(s)
	g["hp"] = g["max_hp"] * (float(s.B["gargola"]["stone_at"]) - 0.1)
	var en: Dictionary = add_enemy(s, "escudero", 1, 556.0)
	en["hp"] = 2000.0
	en["max_hp"] = 2000.0
	var ev: Array = run_ticks(s, 3)
	check(g["state"] == "stone" and ev.has("stone"), "herida, la Gárgola se vuelve piedra")
	var hp_st: float = g["hp"]
	s.damage_creature(g, 50.0)
	check(g["hp"] == hp_st and float(g["stored"]) >= 50.0, "en piedra no pierde vida y guarda el daño")
	var e_hp: float = en["hp"]
	var ev2: Array = run_ticks(s, 80)
	var want_sh: float = float(s.B["gargola"]["shock_dmg"]) + 50.0 * float(s.B["gargola"]["shock_mult"])
	check(ev2.has("stone_break") and e_hp - en["hp"] >= want_sh * 0.6, "al romperse devuelve una onda (%.0f, onda %.0f)" % [e_hp - en["hp"], want_sh])
	# Enjambre: prende fuego a los más enteros
	var s2 = new_sim()
	s2.creatures.clear()
	spawn_beast(s2, "enjambre", 1, 300.0)
	to_combat(s2)
	var a1: Dictionary = add_enemy(s2, "escudero", 0, 700.0)
	var a2: Dictionary = add_enemy(s2, "campesino", 2, 650.0)
	for a in [a1, a2]:
		a["stun"] = 99.0
	var ev3: Array = run_ticks(s2, 3)
	check(ev3.has("swarm") and a1["burn_t"] > 0.0 and a2["burn_t"] > 0.0, "el Enjambre quema a dos enemigos de cualquier carril")
	# Garfio: arrastra a un apoyo lejano a su carril y delante
	var s3 = new_sim()
	s3.creatures.clear()
	var gf: Dictionary = spawn_beast(s3, "garfio", 1, 560.0)
	to_combat(s3)
	var cl: Dictionary = add_enemy(s3, "clerigo", 0, 1000.0)
	var cp: Dictionary = add_enemy(s3, "campesino", 1, 760.0)
	cp["stun"] = 99.0
	cl["stun"] = 0.0
	var ev4: Array = run_ticks(s3, 40)
	check(ev4.has("hook") and int(cl["lane"]) == 1 and float(cl["x"]) < 700.0, "el Garfio arrastra al clérigo a su carril (x %.0f)" % cl["x"])
	# Zapador: no se para ante las bestias y revienta en la Puerta
	var s4 = new_sim()
	s4.creatures.clear()
	spawn_beast(s4, "alacran", 1, 500.0)["cd"] = 999.0
	to_combat(s4)
	var z: Dictionary = add_enemy(s4, "zapador", 1, 700.0)
	z["hp"] = 9999.0
	z["max_hp"] = 9999.0
	var door0: float = s4.door_hp
	var ev5: Array = []
	for i in 30 * 12:
		s4.creatures[0]["presa_cd"] = 99.0
		s4.creatures[0]["cd"] = 99.0
		s4.step(Sim.TICK)
		for e in s4.events:
			ev5.append(String(e["t"]))
		s4.events.clear()
		if z["dead"]:
			break
	check(ev5.has("explode") and s4.door_hp <= door0 - float(s4.B["enemies"]["zapador"]["door_dmg"]) + 0.1, "el Zapador pasa entre las bestias y revienta en la Puerta")
	# Paladín: no arde
	var s5 = new_sim()
	to_combat(s5)
	var pal: Dictionary = add_enemy(s5, "paladin", 1, 900.0)
	pal["burn_t"] = 3.0
	pal["burn_dps"] = 50.0
	var php: float = pal["hp"]
	run_ticks(s5, 30)
	check(pal["hp"] == php, "el Paladín no arde")
	# Sacerdotisa: escudo que absorbe daño
	var s6 = new_sim()
	to_combat(s6)
	var sac: Dictionary = add_enemy(s6, "sacerdotisa", 1, 900.0)
	var esc: Dictionary = add_enemy(s6, "escudero", 1, 960.0)
	sac["shield_t"] = 0.05
	run_ticks(s6, 3)
	check(float(esc["shield"]) > 0.0, "la Sacerdotisa da escudo a los cercanos")
	var ehp: float = esc["hp"]
	s6.damage_enemy(esc, 10.0, -1)
	check(esc["hp"] == ehp, "el escudo absorbe el golpe")
	# Ariete: imparable
	var s7 = new_sim()
	to_combat(s7)
	var ar: Dictionary = add_enemy(s7, "ariete", 1, 900.0)
	ar["stun"] = 3.0
	ar["held"] = 3.0
	var ax: float = ar["x"]
	run_ticks(s7, 30)
	check(float(ar["x"]) < ax, "el Ariete no se deja aturdir ni agarrar")
	# Jefe: juicio sobre el carril con más bestias y escolta al sangrar
	var s8 = new_sim()
	s8.creatures.clear()
	var b1: Dictionary = spawn_beast(s8, "alacran", 2, 500.0)
	spawn_beast(s8, "sabueso", 2, 600.0)
	to_combat(s8)
	var boss: Dictionary = add_enemy(s8, "gran_maestre", 1, 1100.0)
	boss["judge_t"] = 0.05
	var bhp: float = b1["hp"]
	var ev8: Array = run_ticks(s8, 60)
	check(ev8.has("judgment_wind") and int(boss["judge_lane"]) == 2, "el Gran Maestre marca el carril con más bestias")
	check(ev8.has("judgment") and b1["hp"] < bhp, "el Juicio golpea a las bestias de ese carril")
	var n0: int = s8.enemies.size()
	s8.damage_enemy(boss, boss["max_hp"] * 0.3, -1)
	run_ticks(s8, 2)
	check(s8.enemies.size() > n0, "al bajar del 75% llama a su escolta")
	# Ira
	var s9 = new_sim()
	s9.set_siege(1, 2)
	s9.reset()
	check(s9.WAVES.size() == s9.SIEGES[1]["waves"].size() and s9.wrath == 2, "set_siege cambia oleadas e Ira")
	to_combat(s9)
	var w1: Dictionary = add_enemy(s9, "campesino", 1, 900.0)
	check(absf(float(w1["max_hp"]) - 30.0 * s9.wrath_hp()) < 0.01 and s9.wrath_hp() > 1.0, "con Ira los enemigos tienen más vida")
	s9.meta_mode = true
	var e0: int = s9.essence
	s9._gain_essence(100)
	check(s9.essence - e0 > 100, "con Ira se gana más esencia (%d)" % (s9.essence - e0))
	# el segundo asedio se puede jugar entero (Puerta invulnerable)
	var s10 = Sim.new(77)
	s10.set_siege(1, 0)
	s10.reset()
	var guard: int = 0
	var bot = Bot.new(77, 1.0)
	while s10.phase != "victory" and s10.phase != "defeat" and guard < 30 * 60 * 20:
		guard += 1
		match s10.phase:
			"prep":
				bot.prep(s10)
				s10.start_wave()
			"route":
				s10.choose_route("verdugo")
			"forge":
				s10.give_relic()
			"combat":
				bot.combat_tick(s10, Sim.TICK)
				s10.step(Sim.TICK)
				s10.events.clear()
				s10.door_hp = s10.door_max
	check(s10.phase == "victory", "el segundo asedio se completa sin atascos (%s, oleada %d)" % [s10.phase, s10.wave_index + 1])


func test_draft() -> void:
	print("Elección tras la oleada")
	var s = new_sim()
	s.draft_enabled = true
	s.door_hp = 100000.0
	s.door_max = 100000.0
	s.start_wave()
	for i in 4000:
		s.step(Sim.TICK)
		s.events.clear()
		for e in s.enemies.duplicate():
			s.damage_enemy(e, 99999.0)
		if s.phase != "combat":
			break
	check(s.phase == "prep" and s.draft.size() == 3, "tras la oleada se ofrecen 3 opciones (fase %s, oleada %d, opciones %d, almas %d)" % [s.phase, s.wave_index, s.draft.size(), s.souls])
	if s.draft.size() < 1:
		return
	var ids: Array = []
	for o in s.draft:
		ids.append(o["id"])
	var uniq: bool = true
	for i in ids.size():
		if ids.count(ids[i]) > 1:
			uniq = false
	check(uniq, "las tres son distintas")
	check(not s.start_wave(), "no se puede iniciar sin elegir")
	var n0: int = s.creatures.size()
	var souls0: int = s.souls
	var first: Dictionary = s.draft[0]
	check(s.draft_pick(0), "se elige una")
	check(s.draft.is_empty(), "la elección se consume")
	if first["type"] == "beast":
		check(s.creatures.size() == n0 + 1 and s.creatures[s.creatures.size() - 1]["kind"] == first["kind"], "la bestia entra en la partida")
	elif first["type"] == "souls":
		check(s.souls == souls0 + int(first["amount"]), "las almas se suman")
	check(s.start_wave(), "tras elegir se puede iniciar")
	var s2 = new_sim()
	s2.draft_enabled = false
	s2.start_wave()
	s2.door_hp = 100000.0
	s2.door_max = 100000.0
	for i in 4000:
		s2.step(Sim.TICK)
		s2.events.clear()
		for e in s2.enemies.duplicate():
			s2.damage_enemy(e, 99999.0)
		if s2.phase != "combat":
			break
	check(s2.draft.is_empty(), "sin el modo, no hay elección")


func test_inflation() -> void:
	print("Inflación del árbol")
	var s = new_sim()
	s.meta_mode = true
	s.essence = 5000
	var c0: int = s.skill_cost("brasa_radio")
	check(c0 == int(s.SK["brasa_radio"]["cost_base"]), "sin rangos comprados el coste es el de base")
	for i in 10:
		var bought: bool = false
		for id in s.SK_ORDER:
			if s.can_skill(id) and id != "brasa_radio":
				s.buy_skill(id)
				bought = true
				break
		if not bought:
			break
	check(s.skill_cost("brasa_radio") > c0, "cada rango comprado encarece los demás (%d -> %d)" % [c0, s.skill_cost("brasa_radio")])
	s.meta_mode = false
	check(s.skill_cost("brasa_radio") == c0, "sin modo permanente no hay inflación")


func test_procedural() -> void:
	print("Variedad por partida: remezcla y augurios")
	var a = new_sim(11)
	a.remix_enabled = true
	a.reset()
	var b = new_sim(12)
	b.remix_enabled = true
	b.reset()
	check(str(a.WAVES[0]) == str(a.SIEGES[0]["waves"][0]), "la primera oleada no se remezcla (tutorial)")
	var differ: bool = false
	for i in range(1, a.WAVES.size()):
		if str(a.WAVES[i]) != str(b.WAVES[i]):
			differ = true
	check(differ, "dos semillas dan oleadas distintas")
	check(str(a.SIEGES[0]["waves"][3]) != str(a.WAVES[3]) or str(b.SIEGES[0]["waves"][3]) != str(b.WAVES[3]), "la remezcla no toca los datos originales")
	var c = new_sim(11)
	c.remix_enabled = true
	c.reset()
	check(str(c.WAVES) == str(a.WAVES), "la misma semilla da la misma remezcla")
	var heroes: int = 0
	for g in a.WAVES[4]["spawns"]:
		if String(g["kind"]) == "@hero":
			heroes += 1
	check(heroes == 1, "el héroe sigue en su oleada")
	# augurios
	var s = new_sim(5)
	s.augurs_enabled = true
	s.reset()
	check(s.augur_offer.is_empty(), "no hay augurio antes de la primera oleada")
	to_combat(s)
	s.enemies.clear()
	s.spawn_queue.clear()
	run_ticks(s, 3)
	check(s.phase == "prep" and s.augur_offer.size() == 2, "tras la oleada 1 se ofrecen dos augurios")
	check(not s.choose_augur("no_existe"), "no se puede elegir un augurio no ofrecido")
	var n0: int = s._build_spawns(s.WAVES[s.wave_index]).size()
	s.augur = "marea"
	var n1: int = s._build_spawns(s.WAVES[s.wave_index]).size()
	check(n1 > n0, "Marea añade enemigos (%d -> %d)" % [n0, n1])
	s.augur = "niebla"
	s._front_lane = 2
	var lanes: Dictionary = {}
	for q in s._build_spawns(s.WAVES[s.wave_index]):
		lanes[int(q["lane"])] = true
	check(lanes.size() == 1 and lanes.has(2), "Niebla mete a todos por un frente")
	s.augur = "luna"
	s._spawn_enemy("campesino", 0)
	check(float(s.enemies[-1]["max_hp"]) > float(s.B["enemies"]["campesino"]["hp"]), "Luna de sangre da más vida")
	s.augur = ""
	check(s.augur_fx("enemy_hp") == 0.0, "Calma no cambia nada")


func test_boons() -> void:
	print("Dones de partida (draft con rareza)")
	var s = new_sim(3)
	s.draft_enabled = true
	var r0: float = s.brasa_radius()
	s.wave_index = 2
	s.draft = [{"id": "pacto_fuego", "type": "boon", "kind": "", "title": "", "desc": "", "amount": 0.0, "rarity": "rara", "icon": "fuego"}]
	check(s.draft_pick(0), "se puede elegir un don")
	check(s.brasa_radius() > r0, "Pacto de fuego ensancha la Brasa (%.0f -> %.0f)" % [r0, s.brasa_radius()])
	check(not s._draft_ok(s.draft_def("pacto_fuego")), "un don no se ofrece dos veces")
	var d0: float = s.door_max
	s.draft = [{"id": "muralla", "type": "boon", "kind": "", "title": "", "desc": "", "amount": 0.0, "rarity": "rara", "icon": "puerta"}]
	s.draft_pick(0)
	check(s.door_max > d0, "Muralla de huesos sube la vida de la Puerta")
	s.wave_index = 1
	check(not s._draft_ok(s.draft_def("eco_brasa")), "los dones épicos no salen tras la primera oleada")
	# resonancias: dos dones de la misma familia
	var bt0: float = float(s._stats("brasa")["burn_time"])
	check(s.active_sets().is_empty(), "un solo don de fuego no da resonancia")
	s.wave_index = 3
	s.draft = [{"id": "eco_brasa", "type": "boon", "kind": "", "title": "", "desc": "", "amount": 0.0, "rarity": "epica", "icon": "fuego"}]
	s.events.clear()
	s.draft_pick(0)
	check(s.active_sets().has("fuego") and float(s._stats("brasa")["burn_time"]) > bt0, "dos dones de fuego activan Infierno (la Brasa quema más)")
	var ev_set: bool = false
	for ev in s.events:
		ev_set = ev_set or String(ev["t"]) == "set"
	check(ev_set, "se avisa al activar una resonancia")
	var fam: Dictionary = s.boon_families()
	check(s._draft_weight(s.draft_def("tormenta"), fam, 1.8) < s._draft_weight(s.draft_def("furia"), fam, 1.8) * 2.0 + 0.01, "pesos del draft calculables")
	check(s._draft_weight(s.draft_def("sello"), fam, 1.8) > float(s.draft_def("sello")["weight"]), "los dones de una familia que ya llevas salen más")
	s.reset()
	check(s.boons.is_empty() and is_equal_approx(s.brasa_radius(), r0) and is_equal_approx(s.door_max, d0), "los dones se pierden al empezar otra partida")


func test_endless() -> void:
	print("La Grieta (sin fin) y reto semanal")
	var s = new_sim(9)
	var gi: int = s._siege_by_id("grieta")
	check(gi > 0 and s.SIEGES[gi].has("endless"), "La Grieta está en los datos")
	s.set_siege(gi, 0)
	s.reset()
	check(s.is_endless() and s.wave_count() == 6, "empieza con las oleadas del primer asedio")
	s.route = "verdugo"
	s.wave_index = 5
	to_combat(s)
	s.enemies.clear()
	s.spawn_queue.clear()
	run_ticks(s, 2)
	check(s.phase == "prep" and s.wave_index == 6 and s.wave_count() == 7, "al superar la sexta se genera la séptima (no hay victoria)")
	var w7: Dictionary = s.WAVES[6]
	check(float(w7["hp_mult"]) > 1.0 and w7["spawns"].size() >= 2, "la oleada generada tiene vida extra y varios grupos")
	var has_hero: bool = false
	for g in s._gen_wave(9)["spawns"]:
		has_hero = has_hero or String(g["kind"]) == "@hero"
	check(has_hero, "la oleada 10 trae al heraldo")
	var has_boss: bool = false
	for g2 in s._gen_wave(14)["spawns"]:
		has_boss = has_boss or String(g2["kind"]) == "gran_maestre"
	check(has_boss, "la oleada 15 trae al Gran Maestre")
	var b0: int = 0
	var b1: int = 0
	for g3 in s._gen_wave(7)["spawns"]:
		b0 += int(s.B["enemies"].get(String(g3["kind"]), {"reward": 30})["reward"]) * int(g3["count"])
	for g4 in s._gen_wave(20)["spawns"]:
		b1 += int(s.B["enemies"].get(String(g4["kind"]), {"reward": 30})["reward"]) * int(g4["count"])
	check(b1 > b0, "el presupuesto crece con las oleadas (%d -> %d)" % [b0, b1])
	s.set_siege(0, 0)
	# reto semanal: augurio permanente
	var r = new_sim(4)
	r.week_augur = "luna"
	r._spawn_enemy("campesino", 0)
	check(float(r.enemies[-1]["max_hp"]) > float(r.B["enemies"]["campesino"]["hp"]), "el augurio del reto dura toda la partida")
	r.augur = "luna"
	check(is_equal_approx(r.augur_fx("enemy_hp"), 0.25), "el mismo augurio elegido no se suma dos veces")


func test_logros() -> void:
	print("Logros y dones que abren")
	var L = load("res://scripts/logros.gd").new()
	check(L.list.size() >= 10, "data/logros.json tiene la lista")
	var s = new_sim(2)
	var got: Array = L.on_event(s, {"t": "wave_clear", "wave": 1}, false)
	check(got.has("primera_sangre"), "superar una oleada da Primera sangre")
	check(L.on_event(s, {"t": "wave_clear", "wave": 2}, false).is_empty(), "un logro no se repite")
	L.on_event(s, {"t": "brasa_land", "hits": 9}, false)
	check(L.got.has("brasa_perfecta") and L.unlocked_boons().has("eco_brasa"), "Brasa perfecta abre el don Eco de la Fosa")
	check(not s._draft_ok(s.draft_def("eco_brasa")) or s.wave_index < 2, "sin el logro el don bloqueado no sale")
	s.wave_index = 3
	check(not s._draft_ok(s.draft_def("eco_brasa")), "un don bloqueado no sale aunque toque por oleada")
	s.unlocked = L.unlocked_boons()
	check(s._draft_ok(s.draft_def("eco_brasa")), "con el logro el don ya puede salir")
	L.on_event(s, {"t": "wave_start", "wave": 1}, false)
	L.on_event(s, {"t": "door_hit", "lane": 0, "amount": 3}, false)
	var v: Array = L.on_event(s, {"t": "victory"}, false)
	check(v.has("puerta_resiste") and not v.has("intocable"), "ganar el primer asedio con la Puerta tocada no da Intocable")
	var L2 = load("res://scripts/logros.gd").new()
	L2.from_save(L.to_save())
	check(L2.got.size() == L.got.size() and int(L2.stats["victorias"]) == 1, "logros y estadísticas se guardan y se cargan")


func test_music() -> void:
	print("Música procedural")
	var M = load("res://scripts/music.gd").new()
	M.target = 0.0
	var calm: PackedVector2Array = M.render(22050)
	M.intensity = 1.0
	var loud: PackedVector2Array = M.render(22050 * 2)
	var peak: float = 0.0
	var energy_c: float = 0.0
	var energy_l: float = 0.0
	var ok: bool = true
	for v in calm:
		energy_c += absf(v.x)
		ok = ok and is_finite(v.x) and absf(v.x) <= 1.2
	for v2 in loud:
		energy_l += absf(v2.x)
		peak = maxf(peak, absf(v2.x))
		ok = ok and is_finite(v2.x)
	check(ok and peak <= 1.2, "la síntesis no se sale ni da NaN (pico %.2f)" % peak)
	check(energy_c > 50.0, "en calma suena algo (drone y campanas)")
	check(energy_l / 2.0 > energy_c, "en combate hay más energía (bajo y tambores)")


func test_contracts() -> void:
	print("Encargos")
	var s = new_sim(6)
	s.contracts_enabled = true
	s.reset()
	check(s.contract_offer.size() == 2, "al empezar se ofrecen dos encargos")
	check(not s.choose_contract("no_existe"), "no se puede elegir un encargo no ofrecido")
	s.contract_offer = ["solo_fuego", "austero"]
	check(s.choose_contract("solo_fuego") and s.contract_status() == "ok", "elegir Solo fuego")
	to_combat(s)
	add_enemy(s, "campesino", 1, 700.0)
	s.cast_rayo(s.epos(s.enemies[0]))
	check(s.contract_status() == "fail", "lanzar un Rayo falla Solo fuego")
	var s2 = new_sim(6)
	s2.contracts_enabled = true
	s2.meta_mode = true
	s2.reset()
	s2.contract_offer = ["tizon_invicto"]
	s2.choose_contract("tizon_invicto")
	s2.wave_index = s2.WAVES.size() - 1
	to_combat(s2)
	s2.enemies.clear()
	s2.spawn_queue.clear()
	var e0: int = s2.essence
	var evs: Array = run_ticks(s2, 2)
	var done: bool = evs.has("contract_done")
	check(s2.phase == "victory" and done and s2.essence > e0 + int(s2.B["meta"]["victory"]), "ganar cumpliendo el encargo da su esencia")
	var s3 = new_sim(6)
	s3.contracts_enabled = true
	s3.reset()
	s3.wave_index = 1
	check(not s3.choose_contract(String(s3.contract_offer[0])), "el encargo solo se elige antes de la primera oleada")


func test_terrain() -> void:
	print("Terreno por partida")
	var seen: Dictionary = {}
	for i in 30:
		var s = new_sim(200 + i)
		s.remix_enabled = true
		s.reset()
		seen[s.terrain] = true
	check(seen.size() >= 3, "con la remezcla salen terrenos distintos (%s)" % str(seen.keys()))
	var f = new_sim(3)
	f.terrain = "fisura"
	f.terrain_lane = 2
	f.start_wave()
	var tz: bool = false
	for z in f.zones:
		tz = tz or (z.get("terrain", false) and int(z["lane"]) == 2)
	check(tz, "la Fisura pone una franja ardiente fija en su carril")
	var e: Dictionary = add_enemy(f, "campesino", 2, 770.0)
	run_ticks(f, 3)
	check(float(e["burn_t"]) > 0.0, "quien pisa la Fisura arde")
	var o = new_sim(3)
	o.terrain = "osario"
	o.terrain_lane = 0
	to_combat(o)
	var a: Dictionary = add_enemy(o, "campesino", 0, 1000.0)
	var b: Dictionary = add_enemy(o, "campesino", 1, 1000.0)
	run_ticks(o, 30)
	check(float(a["x"]) > float(b["x"]), "en el Osario los humanos van más lentos por su carril")
	var v = new_sim(3)
	var d0: float = float(v._stats("brasa")["delay"])
	v.terrain = "viento"
	v._invalidate()
	check(float(v._stats("brasa")["delay"]) < d0, "con Viento del Abismo la Brasa cae antes")


func test_save_run() -> void:
	print("Guardar a mitad de partida")
	var a = new_sim(77)
	a.remix_enabled = true
	a.augurs_enabled = true
	a.reset()
	a.souls = 123
	a.buy("sabueso")
	a.wave_index = 2
	a.boons = ["pacto_fuego"]
	a.terrain = "osario"
	a._invalidate()
	var txt: String = var_to_str(a.run_save())
	var b = new_sim(1)
	check(b.run_load(str_to_var(txt)), "la partida guardada se carga")
	check(b.souls == a.souls and b.wave_index == 2 and b.creatures.size() == a.creatures.size(), "almas, oleada y bestias se recuperan")
	check(b.WAVES == a.WAVES, "las oleadas remezcladas se recuperan")
	check(b.terrain == "osario" and str(b.boons) == str(["pacto_fuego"]), "terreno y dones se recuperan")
	check(typeof(b.creatures[0]["id"]) == TYPE_INT, "los tipos se conservan (var_to_str, no JSON)")
	check(b.brasa_radius() == a.brasa_radius(), "los efectos de los dones vuelven a aplicarse")
	to_combat(a)
	check(a.run_save().is_empty(), "en combate no se guarda")


func test_anim() -> void:
	print("Animación por fotogramas (solo vista)")
	check(not Anim.data().is_empty(), "data/anim.json se lee")
	check(Anim.frame_count("demonio", "reposo") == 52, "el reposo del demonio tiene 52 fotogramas")
	check(Anim.frame("demonio", "reposo", 0) != null, "el primer fotograma carga")
	check(not Anim.has_clip("demonio", "baile"), "un clip que no está en los datos no existe")
	check(not Anim.has_clip("nadie", "reposo"), "un personaje sin datos no tiene clips")
	var a = Anim.new("demonio")
	check(a.clip == "reposo", "el demonio empieza en reposo")
	a.update(10.0)
	check(a.clip == "reposo" and a.index() >= 0 and a.index() < 52, "el reposo es un bucle")
	check(a.play("rayo"), "play(rayo) arranca el clip")
	check(a.index() == 4, "el rayo empieza en su fotograma start (5)")
	check(absf(Anim.impact_delay("demonio", "rayo") - 2.0 / 24.0) < 0.001, "el impacto del rayo llega 2 fotogramas después")
	a.set_base("")
	check(a.clip == "rayo", "set_base no corta un lanzamiento")
	a.update(5.0)
	check(a.clip == "reposo", "al acabar un clip de una vez vuelve al reposo")
	a.play("derrota")
	a.update(50.0)
	check(a.clip == "derrota" and a.done and a.index() == 40, "la derrota se queda en el último fotograma")
	var h: Vector2 = Anim.hand_at("demonio", "rayo", Vector2(100, 400))
	check(h.x > 100.0 and h.y < 400.0, "la mano del rayo queda delante y arriba de los pies")
	var tz = Anim.new("sabueso")
	check(tz.clip == "" and tz.texture() == null, "Tizón sin reposo usa el sprite fijo")
	tz.set_base("carrera")
	check(tz.texture() != null, "Tizón corre con fotogramas")
	tz.play("mordisco")
	tz.update(5.0)
	check(tz.clip == "" and tz.texture() == null, "tras el mordisco vuelve al sprite fijo")
	Anim.enabled = false
	var off = Anim.new("demonio")
	check(off.texture() == null and off.draw_opts().is_empty(), "sin animaciones (o sin carpeta) no hay fotograma")
	Anim.enabled = true
	Anim.clear_cache()
	# poses por código y reproductores de bestias
	var P = load("res://scripts/poses.gd")
	var po = P.new()
	var sm = new_sim()
	to_combat(sm)
	var tz2: Dictionary = sm.named_creature()
	po.update(sm, 0.0, 0.016)
	check(po.clip_of(int(tz2["id"])) == "", "Tizón quieto: sprite fijo (respira por código)")
	for i in 10:
		tz2["x"] = float(tz2["x"]) + 6.0
		po.update(sm, 1.0 / 30.0, 1.0 / 30.0)
	check(po.moving(int(tz2["id"])) and po.clip_of(int(tz2["id"])) == "carrera", "Tizón en marcha usa la carrera")
	po.on_event({"t": "bite", "id": tz2["id"]}, sm)
	check(po.clip_of(int(tz2["id"])) == "mordisco", "el evento bite lanza el mordisco")
	var pz: Dictionary = po.pose(int(tz2["id"]), 1.0, 1.0, 0.0, false, true, true)
	check(pz["shift"].x == 0.0, "con el clip de mordisco no hay embestida por código encima")
	var e0: Dictionary = add_enemy(sm, "escudero", 1, 600.0)
	po.update(sm, 1.0 / 30.0, 1.0 / 30.0)
	e0["cd"] = 2.0
	po.update(sm, 1.0 / 30.0, 1.0 / 30.0)
	po.update(sm, 1.0 / 30.0, 0.12)
	var pe: Dictionary = po.pose(int(e0["id"]), 1.0, -1.0, 0.0, false, false, false)
	check(pe["shift"].x < -5.0, "un enemigo que golpea embiste hacia la izquierda")
	var ph: Dictionary = po.pose(int(e0["id"]), 1.0, -1.0, 1.0, false, false, false)
	check(ph["shift"].x > pe["shift"].x, "al recibir un golpe retrocede")
	sm.enemies.clear()
	po.update(sm, 1.0 / 30.0, 1.0 / 30.0)
	check(not po.units.has(int(e0["id"])), "las unidades que desaparecen se olvidan")
