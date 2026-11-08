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
	test_guardia()
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
	check(s.slot_count() == 6, "hay seis casillas")
	check(s.ROUTES.has("verdugo") and s.ROUTES.has("inquisidor"), "hay dos rutas")
	check(s.named_creature()["name"] == "Tizón", "Tizón empieza en la partida")
	var pv: Array = s.preview(2)
	check(int(pv[0].get("campesino", 0)) == 12, "la oleada 3 muestra 12 campesinos por el carril 0")


func test_basic_combat() -> void:
	print("Combate básico (oleada 1)")
	var s = new_sim()
	check(s.start_wave(), "se puede iniciar la oleada 1")
	var guard: int = 0
	while s.phase == "combat" and guard < 30 * 120:
		s.step(Sim.TICK)
		s.events.clear()
		guard += 1
	check(s.phase == "prep", "la oleada 1 termina y vuelve a preparación (fase %s)" % s.phase)
	check(s.wave_index == 1, "avanza a la oleada 2")
	check(s.door_hp > 0.0, "la Puerta sigue en pie (%d)" % int(s.door_hp))
	check(s.souls > 40, "se ganan almas (%d)" % s.souls)
	check(s.kills == 3, "caen los 3 campesinos")


func test_presa() -> void:
	print("Presa de Tizón")
	var s = new_sim()
	to_combat(s)
	var e: Dictionary = add_enemy(s, "escudero", 1, 560.0)
	var seen: Array = run_ticks(s, 60)
	check(seen.has("presa_windup") and seen.has("presa"), "Tizón prepara y ejecuta la Presa")
	check(seen.has("bite"), "Tizón muerde")


func test_guardia() -> void:
	print("Garra de Guardia")
	var s = new_sim()
	s.souls = 500
	check(s.buy("guardia"), "se compra la Garra de Guardia")
	check(not s.can_buy("guardia"), "no se puede comprar dos veces")
	to_combat(s)
	var e: Dictionary = add_enemy(s, "campesino", 0, 330.0)
	var seen: Array = run_ticks(s, 3)
	check(seen.has("guardia"), "la Garra retiene al enemigo que se acerca a la Puerta")
	check(float(e["stun"]) > 0.0, "el enemigo queda retenido")


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
		var pv: Array = s.preview(4)
		var want: String = r
		check(int(pv[1].get(want, 0)) == 1, "[%s] la oleada 5 muestra a %s" % [r, want])
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
	check(s.wave_index == 0, "(punto de partida de la prueba)")
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
	var slot_before: int = int(t["slot"])
	check(s.place(int(t["id"]), 3), "se puede colocar a Tizón en la retaguardia")
	check(int(t["slot"]) == 3 and float(t["home_x"]) == 330.0, "ocupa la casilla trasera")
	check(not s.place(int(t["id"]), 99), "casilla inexistente rechazada")
	s.start_wave()
	check(not s.place(int(t["id"]), slot_before), "no se recoloca en combate")


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
func arrange(s) -> void:
	var pv: Array = s.preview(s.wave_index)
	var weight: Array = [0.0, 0.0, 0.0]
	for lane in 3:
		for k in pv[lane].keys():
			var hp_k: float = float(s.B["enemies"].get(String(k), {}).get("hp", 50))
			weight[lane] += hp_k * float(pv[lane][k])
	var order: Array = [0, 1, 2]
	order.sort_custom(func(a, b): return weight[a] > weight[b])
	var melee: Array = []
	var ojos: Array = []
	for c in s.creatures:
		if c["dead"]:
			continue
		if c["kind"] == "ojo":
			ojos.append(c)
		else:
			melee.append(c)
	# Tizón primero, luego el resto por orden de compra.
	melee.sort_custom(func(a, b): return (0 if a["named"] else 1) < (0 if b["named"] else 1))
	for i in melee.size():
		var lane_i: int = order[i % 3]
		s.place(int(melee[i]["id"]), lane_i)
	for j in ojos.size():
		s.place(int(ojos[j]["id"]), 3 + int(order[j % 3]))


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
					if c["kind"] == "sabueso":
						n_sab += 1
				if s.wave_index >= 1 and n_sab < 2 and s.can_buy("sabueso"):
					s.buy("sabueso")
				if s.wave_index >= 2 and s.can_buy("ojo"):
					s.buy("ojo")
				if s.wave_index >= 3 and s.can_buy("guardia"):
					s.buy("guardia")
				if s.wave_index >= 3 and s.can_buy("sabueso"):
					s.buy("sabueso")
				arrange(s)
				s.start_wave()
				wave_ticks = 0
			"route":
				s.choose_route(route)
			"forge":
				s.give_relic()
			"combat":
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
	var guard: int = 0
	while m.sim.phase == "combat" and guard < 30 * 120:
		m._process(1.0 / 30.0)
		guard += 1
	check(m.sim.phase == "prep" and m.sim.wave_index == 1, "la vista avanza la oleada 1")
	# comprar un sabueso con el botón
	m.sim.souls = 200
	m._on_press(Vector2(115, 660))
	check(m.sim.creatures.size() == 2, "el botón Sabueso recluta")
	# arrastrar a Tizón a la casilla trasera del carril 1
	var t: Dictionary = m.sim.named_creature()
	var from_p: Vector2 = m._creature_pos(t) + Vector2(10, -20)
	m._on_press(from_p)
	m._on_release(Vector2(330, m._lane_y(1)))
	check(int(t["slot"]) == 4, "arrastrar con el ratón recoloca a Tizón (casilla %d)" % int(t["slot"]))
	m.queue_free()
