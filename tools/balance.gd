extends Node
## Informe de equilibrio con el bot torpe (tests/bot.gd).
## Uso: godot --headless --path . res://tools/balance.tscn -- [partidas_primera=60] [carreras=8] [partidas_por_carrera=12]

const Sim = preload("res://scripts/sim.gd")
const Bot = preload("res://tests/bot.gd")


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var n_first: int = int(a[0]) if a.size() > 0 else 60
	var n_car: int = int(a[1]) if a.size() > 1 else 8
	var n_games: int = int(a[2]) if a.size() > 2 else 12
	var t0: int = Time.get_ticks_msec()
	print("== Primera partida (sin árbol), bot torpe ==")
	report_first(n_first, 0.0)
	print("== Primera partida, bot hábil (referencia) ==")
	report_first(maxi(10, n_first / 3), 1.0)
	if OS.has_environment("BAL_ESS"):
		for es in OS.get_environment("BAL_ESS").split(","):
			report_with_essence(n_first, int(es))
	if n_car > 0:
		print("== Carrera: partidas seguidas acumulando esencia, bot torpe ==")
		report_career(n_car, n_games)
	print("tiempo %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0)


func new_game(seed_v: int, essence: int, skills: Dictionary):
	var s = Sim.new(seed_v)
	s.meta_mode = true
	s.draft_enabled = true
	s.essence = essence
	s.skills = skills.duplicate()
	s.reset()
	return s


func report_first(n: int, level: float) -> void:
	var wins: int = 0
	var waves: Dictionary = {}
	var lost_route: Dictionary = {}
	var doors: Array = []
	var by_route: Dictionary = {"verdugo": [0, 0], "inquisidor": [0, 0]}
	for i in n:
		var s = new_game(1000 + i, 0, {})
		var bot = Bot.new(1000 + i, level)
		var r: Dictionary = bot.play(s, OS.get_environment("BAL_ROUTE"))
		by_route[r["route"]][1] += 1
		if OS.has_environment("BAL_DEBUG"):
			print("    ", r["route"], " ", r["phase"], " ", str(r["alive"]))
			if r["phase"] == "defeat":
				var ek: Dictionary = {}
				for e in s.enemies:
					ek[e["kind"]] = int(ek.get(e["kind"], 0)) + 1
				var ck: Array = []
				for c in s.creatures:
					ck.append("%s%s" % [c["kind"], "(caído)" if c["fallen"] else ""])
				print("      t=%.0f enemigos %s cola %d | bestias %s" % [s.wave_time, str(ek), s.spawn_queue.size(), str(ck)])
		if r["phase"] == "victory":
			wins += 1
			by_route[r["route"]][0] += 1
			doors.append(int(r["door"]))
		else:
			waves[r["wave"]] = int(waves.get(r["wave"], 0)) + 1
			var key: String = "%s@%d" % [String(r["route"]).substr(0, 4), int(r["wave"])]
			lost_route[key] = int(lost_route.get(key, 0)) + 1
	print("  victorias %d/%d (%.0f%%)  por ruta: verdugo %d/%d, inquisidor %d/%d" % [wins, n, 100.0 * wins / n, by_route["verdugo"][0], by_route["verdugo"][1], by_route["inquisidor"][0], by_route["inquisidor"][1]])
	var ks: Array = waves.keys()
	ks.sort()
	var parts: Array = []
	for k in ks:
		parts.append("oleada %d: %d" % [k, waves[k]])
	print("  derrotas en ", ", ".join(parts), "   ", str(lost_route))
	doors.sort()
	print("  Puerta al ganar: ", str(doors))


func report_career(n_car: int, n_games: int) -> void:
	var wins_at: Array = []
	var ess_at: Array = []
	for g in n_games:
		wins_at.append(0)
		ess_at.append(0)
	for c in n_car:
		var essence: int = 0
		var skills: Dictionary = {}
		for g in n_games:
			var s = new_game(5000 + c * 100 + g, essence, skills)
			var bot = Bot.new(5000 + c * 100 + g, 0.0)
			bot.buy_meta(s)
			var spent: int = 0
			for id in s.skills:
				for r in int(s.skills[id]):
					spent += int(s.SK[id]["cost_base"]) + int(s.SK[id]["cost_step"]) * r
			ess_at[g] += spent
			var res: Dictionary = bot.play(s)
			if res["phase"] == "victory":
				wins_at[g] += 1
			essence = s.essence
			skills = s.skills.duplicate()
	for g in n_games:
		print("  partida %2d: victorias %d/%d (%.0f%%), esencia invertida media %d" % [g + 1, wins_at[g], n_car, 100.0 * wins_at[g] / n_car, ess_at[g] / n_car])


## Victorias del bot torpe con un árbol comprado con `ess` de esencia.
func report_with_essence(n: int, ess: int) -> void:
	var wins: int = 0
	for i in n:
		var s = new_game(3000 + i, ess, {})
		var bot = Bot.new(3000 + i, 0.0)
		bot.buy_meta(s)
		s.essence = 0
		if bot.play(s)["phase"] == "victory":
			wins += 1
	print("  árbol de %4d esencia: victorias %d/%d (%.0f%%)" % [ess, wins, n, 100.0 * wins / maxi(1, n)])
