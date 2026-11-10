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
	# variedad por partida (remezcla y augurios) salvo con BAL_PROC=0
	s.remix_enabled = OS.get_environment("BAL_PROC") != "0"
	s.augurs_enabled = OS.get_environment("BAL_PROC") != "0"
	s.contracts_enabled = OS.get_environment("BAL_PROC") != "0"
	s.essence = essence
	s.skills = skills.duplicate()
	s.set_siege(int(OS.get_environment("BAL_SIEGE")) if OS.has_environment("BAL_SIEGE") else 0, int(OS.get_environment("BAL_WRATH")) if OS.has_environment("BAL_WRATH") else 0)
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


## Carrera. Con BAL_CLIMB=1 el bot sube la Ira tras cada victoria (como un jugador que busca reto)
## y pasa al segundo asedio al ganar Ira 3 en el primero.
func report_career(n_car: int, n_games: int) -> void:
	var wins_at: Array = []
	var ess_at: Array = []
	var lvl_at: Array = []
	var climb: bool = OS.has_environment("BAL_CLIMB")
	var spent_total: Array = []
	spent_total.resize(n_car)
	spent_total.fill(0)
	for g in n_games:
		wins_at.append(0)
		ess_at.append(0)
		lvl_at.append([])
	for c in n_car:
		var essence: int = 0
		var skills: Dictionary = {}
		var sg: int = 0
		var ira: int = 0
		for g in n_games:
			var s = new_game(5000 + c * 100 + g, essence, skills)
			if climb:
				s.set_siege(sg, ira)
				s.reset()
				lvl_at[g].append("%d.%d" % [sg + 1, ira])
			var bot = Bot.new(5000 + c * 100 + g, 0.0)
			var ess0: int = s.essence
			bot.buy_meta(s)
			spent_total[c] += ess0 - s.essence
			ess_at[g] += spent_total[c]
			var res: Dictionary = bot.play(s)
			if res["phase"] == "victory":
				wins_at[g] += 1
				if climb:
					ira += 1
					if sg == 0 and ira > 3:
						sg = 1
						ira = 0
					ira = mini(ira, 5)
			essence = s.essence
			skills = s.skills.duplicate()
	for g in n_games:
		print("  partida %2d: victorias %d/%d (%.0f%%), esencia invertida media %d %s" % [g + 1, wins_at[g], n_car, 100.0 * wins_at[g] / n_car, ess_at[g] / n_car, " ".join(lvl_at[g]) if climb else ""])


## Victorias del bot torpe con un árbol comprado con `ess` de esencia.
func report_with_essence(n: int, ess: int) -> void:
	var wins: int = 0
	var reached: Array = []
	for i in n:
		var s = new_game(3000 + i, ess, {})
		var bot = Bot.new(3000 + i, 0.0)
		bot.buy_meta(s)
		s.essence = 0
		var res: Dictionary = bot.play(s)
		if res["phase"] == "victory":
			wins += 1
		reached.append(int(res["wave"]) - 1)
	reached.sort()
	print("  árbol de %4d esencia: victorias %d/%d (%.0f%%)  oleadas superadas %s" % [ess, wins, n, 100.0 * wins / maxi(1, n), str(reached)])
