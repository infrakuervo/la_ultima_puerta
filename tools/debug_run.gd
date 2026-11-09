extends Node
## Depuración: una partida del bot torpe con línea de tiempo de la oleada indicada.
## godot --headless --path . res://tools/debug_run.tscn -- <semilla> <ruta> <oleada>
const Sim = preload("res://scripts/sim.gd")
const Bot = preload("res://tests/bot.gd")

func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var sd: int = int(a[0]); var route: String = a[1]; var wv: int = int(a[2])
	var s = Sim.new(sd)
	s.meta_mode = true
	s.draft_enabled = true
	s.reset()
	var bot = Bot.new(sd, 0.0)
	var last: float = -10.0
	while s.phase != "victory" and s.phase != "defeat":
		match s.phase:
			"prep":
				bot.prep(s)
				s.start_wave()
				last = -10.0
			"route": s.choose_route(route)
			"forge": s.give_relic()
			"combat":
				bot.combat_tick(s, Sim.TICK)
				s.step(Sim.TICK)
				for ev in s.events:
					if s.wave_index + 1 == wv and ev["t"] in ["creature_down", "execute", "sweep", "tirador_shot", "ring", "horno_spit", "trueno_land"]:
						print("   %.1f %s" % [s.wave_time, str(ev)])
				s.events.clear()
				if s.wave_index + 1 == wv and s.wave_time - last >= 4.0:
					last = s.wave_time
					var ek: Array = []
					for e in s.enemies:
						ek.append("%s@%d/%d" % [e["kind"].substr(0, 4), int(e["x"]), e["lane"]])
					var ck: Array = []
					for c in s.creatures:
						ck.append("%s%d/%d:%d/%d%s" % [c["kind"].substr(0, 4), c["level"], c["lane"], int(c["hp"]), int(c["max_hp"]), "C" if c["fallen"] else ""])
					print("t=%.0f puerta=%d | %s | %s" % [s.wave_time, int(s.door_hp), " ".join(ck), " ".join(ek)])
	print(s.phase)
	get_tree().quit(0)
