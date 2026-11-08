extends Node
## Suite de pruebas (nodo). Se lanza con tests/run_tests.gd (línea de comandos) o con tests/run_scene.tscn (editor).
## Sale con código 0 si todo pasa y 1 si algo falla. También imprime un informe de equilibrio.

const Sim = preload("res://scripts/sim.gd")

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
	test_full_runs()
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
	var hp_a: float = float(a["hp"])
	check(s.cast_brasa(Vector2(720, s.lane_y(0))), "se lanza la Brasa")
	check(not s.cast_brasa(Vector2(720, s.lane_y(0))), "la Brasa respeta su enfriamiento")
	check(float(a["hp"]) == hp_a, "la Brasa tarda en caer: aún no hace daño")
	var seen: Array = run_ticks(s, 30)
	check(seen.has("brasa_land"), "la Brasa cae")
	check(float(a["hp"]) < hp_a and float(b["hp"]) < hp_a + 1.0, "la Brasa daña en área")
	check(float(far["hp"]) == float(far["max_hp"]), "la Brasa no toca a quien está fuera del círculo")
	check(float(a["burn_t"]) > 0.0 or a["dead"], "la Brasa prende a los alcanzados")
	# radio mayor con la mejora
	var r0: float = s.brasa_radius()
	s.up_brasa = true
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
	s3.up_rayo = true
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
	check(s2.buy("brasa_radio") and s2.up_brasa, "se compra el radio de Brasa")
	check(s2.buy("rayo_cadena") and s2.up_rayo, "se compra la cadena de Rayo")
	check(not s2.can_buy("brasa_radio") and not s2.can_buy("rayo_cadena"), "las mejoras no se compran dos veces")


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
			if kind == "clerigo":
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
				if s.wave_index >= 2 and s.can_buy("rayo_cadena"):
					s.buy("rayo_cadena")
				if s.wave_index >= 3 and s.can_buy("brasa_radio"):
					s.buy("brasa_radio")
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


# --- interfaz con el ratón ----------------------------------------------------

func test_ui_smoke() -> void:
	print("Interfaz (ratón)")
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "la escena principal carga")
	if packed == null:
		return
	var m = packed.instantiate()
	get_tree().root.add_child(m)
	await get_tree().process_frame
	check(m.sim != null, "la vista crea la simulación")
	m._on_press(Vector2(1130, 660))
	check(m.sim.phase == "combat", "el botón Iniciar oleada arranca la oleada con el ratón")
	m._on_press(Vector2(1100, 660))
	m._on_release(Vector2(1100, 660))
	check(m.sim.brasa_cd == 0.0, "pulsar el panel inferior no lanza hechizos")
	m._on_press(Vector2(640, 380))
	m._on_release(Vector2(640, 380))
	check(m.sim.brasa_cd > 0.0, "clic en la arena lanza la Brasa")
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
	m._on_press(Vector2(735, 660))
	check(int(t["level"]) == 2, "el botón Subir nivel sube a la bestia seleccionada")
	m._on_release(Vector2(330, m._lane_y(1)))
	check(float(t["home_x"]) == 330.0 and int(t["home_lane"]) == 1, "arrastrar con el ratón recoloca a Tizón en la retaguardia (x %d)" % int(t["home_x"]))
	m.queue_free()


