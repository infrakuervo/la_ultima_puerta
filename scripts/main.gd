extends Node2D
## Vista y entrada de La Última Puerta. Toda la lógica vive en sim.gd; aquí solo se
## dibuja, se oye y se lee el ratón. Se juega entera con el ratón (Espacio/F/B son atajos).

const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const SoundBank = preload("res://scripts/sound_bank.gd")
const Juice = preload("res://scripts/juice.gd")
const Menu = preload("res://scripts/menu.gd")
const Anim = preload("res://scripts/anim.gd")
const Poses = preload("res://scripts/poses.gd")
const Logros = preload("res://scripts/logros.gd")
const Music = preload("res://scripts/music.gd")

const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const BESTIARY_PATH: String = "user://bestiario.json"
const ARENA_TOP: float = 90.0
const ARENA_BOTTOM: float = 598.0

const FORM_INFO: Dictionary = {
	"sabueso": "Muerde y a veces agarra a un enemigo (Presa) para que no avance.",
	"horno": "Inhala hasta 5 enemigos de su carril y los escupe en llamas. Quema el suelo.",
	"trueno": "Salta a apoyos y tiradores y encadena descargas. Deja su hueco abierto.",
	"alacran": "Tanque. Agarra a un invasor con la pinza 3 s y le hace daño.",
	"sapo": "Escupe brea al grupo desde atrás: daña y frena a quien pisa el charco.",
	"manta": "Planea por el carril más lleno, golpea y aturde a todos. Intocable en vuelo.",
	"ojo": "Dispara desde atrás; sobre enemigos en llamas encadena. Marca el blanco del Trueno.",
	"gargola": "Tanque. Herida, se vuelve piedra y suelta en una onda lo que encajó.",
	"enjambre": "Quema desde atrás a los dos más enteros. Con el Ojo, combo de llamas.",
	"garfio": "Engancha a un apoyo o tirador lejano y lo arrastra a la vanguardia.",
}

var sim = null
var sound = null
var players: Array = []
var player_idx: int = 0
var sound_last: Dictionary = {}

var clock: float = 0.0
var accum: float = 0.0
var speed: int = 1
var selected_id: int = -1
var dragging: bool = false
var mouse_pos: Vector2 = Vector2.ZERO
var show_bestiary: bool = false
var show_tree: bool = false
var _tree_pos: Dictionary = {}
var spell: String = "brasa"
var holding: bool = false

var fx: Array = []
var warns: Array = []
var mut_anim: Dictionary = {}
var demon_anim = Anim.new("demonio")
var poses = Poses.new()
var arena_offset: Vector2 = Vector2.ZERO   # temblor de cámara aplicado a la arena en este fotograma
var _sim_dt: float = 0.0
const INTRO_PATH: String = "res://art/video/intro_demonio.ogv"
const INTRO_MAX: float = 12.0   # por si el vídeo no avisa al terminar
var intro_layer: CanvasLayer = null
var intro_t: float = 0.0
var banner_text: String = ""
var banner_t: float = 0.0
var banner_dur: float = 1.0
var juice = Juice.new()
var menu = Menu.new()
var fade: float = 0.0
var last_phase: String = ""
var siege_wins: Dictionary = {}   # id de asedio -> mayor nivel de Ira ganado
var records: Dictionary = {}      # "grieta" -> oleadas superadas (récord); "reto:<semana>" -> récord del reto
var new_record: bool = false
var logros = Logros.new()
var music = Music.new()
var toasts: Array = []            # avisos de logro: {title, desc, t}
var challenge: Dictionary = {}    # reto semanal en curso ({} si no): {key, week, siege, wrath, augur}
var unlock_note: String = ""
var flash_red: float = 0.0
var flash_white: float = 0.0
var font: Font = null


func _ready() -> void:
	font = ThemeDB.fallback_font
	sim = Sim.new(int(Time.get_ticks_usec() % 1000000))
	if not Engine.has_meta("sin_persistencia"):
		sim.meta_mode = true
		sim.draft_enabled = true
		sim.remix_enabled = true
		sim.augurs_enabled = true
		_load_meta()
		sim.reset()
	sound = SoundBank.new()
	_ensure_buses()
	for i in 10:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		players.append(p)
	_load_bestiary()
	if Engine.has_meta("sin_persistencia"):
		menu.persist = false
		menu.open = false
		menu.started = true
	menu.load_options()
	menu.apply(self)
	speed = int(menu.opts["velocidad"])
	if DisplayServer.get_name() != "headless" and not Engine.has_meta("sin_persistencia"):
		music.setup(self, "Musica")
	if not Engine.has_meta("sin_persistencia") and bool(menu.opts.get("intro", true)) and DisplayServer.get_name() != "headless":
		_start_intro()


## Buses de audio separados para música y efectos (los volúmenes van en Opciones).
func _ensure_buses() -> void:
	for nm in ["Efectos", "Musica"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var bi: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, nm)
			AudioServer.set_bus_send(bi, "Master")


# ----------------------------------------------------------------------------
# Intro en vídeo (antes del menú). Se salta con clic o tecla; se quita en Opciones.
# ----------------------------------------------------------------------------

func _start_intro() -> void:
	if not ResourceLoader.exists(INTRO_PATH):
		return
	var stream: VideoStream = load(INTRO_PATH)
	if stream == null:
		return
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 10
	add_child(intro_layer)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	intro_layer.add_child(bg)
	var vp: VideoStreamPlayer = VideoStreamPlayer.new()
	vp.stream = stream
	vp.expand = true
	vp.size = Vector2(SCREEN_W, SCREEN_H)
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.finished.connect(_end_intro)
	intro_layer.add_child(vp)
	var hint: Label = Label.new()
	hint.text = "Clic o tecla para saltar"
	hint.position = Vector2(SCREEN_W - 260, SCREEN_H - 40)
	hint.modulate = Color(1, 1, 1, 0.45)
	intro_layer.add_child(hint)
	intro_t = 0.0
	vp.play()


## Intensidad de la música según lo que pasa: calma en menús y preparación, combate según
## cuántos enemigos quedan, al máximo con héroes y jefes.
func _music_target() -> float:
	if intro_layer != null or menu.open:
		return 0.05
	match sim.phase:
		"combat":
			var k: float = 0.55 + 0.4 * clampf(float(sim.enemies.size()) / 22.0, 0.0, 1.0)
			for e in sim.enemies:
				var st: Dictionary = sim.B["enemies"][e["kind"]]
				if st.get("hero", false) or st.get("boss", false):
					k = 1.0
			return k
		"victory":
			return 0.2
		"defeat":
			return 0.0
	return 0.15


func _end_intro() -> void:
	if intro_layer == null:
		return
	intro_layer.queue_free()
	intro_layer = null
	fade = 1.0


# ----------------------------------------------------------------------------
# Bucle
# ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	music.target = _music_target()
	music.update(delta)
	if intro_layer != null:
		intro_t += delta
		if intro_t > INTRO_MAX:
			_end_intro()
		return
	clock += delta
	mouse_pos = get_global_mouse_position()
	fade = maxf(0.0, fade - delta * 2.5)
	if menu.open:
		juice.update(delta)
		demon_anim.update(delta)
		queue_redraw()
		return
	if sim.phase != last_phase:
		if last_phase != "" and sim.phase != "combat":
			fade = maxf(fade, 0.45)
		last_phase = sim.phase
	menu.tut_update(delta)
	_sim_dt = 0.0
	if sim.phase == "combat" and juice.hitstop <= 0.0:
		accum += delta * float(speed)
		var guard: int = 0
		while accum >= Sim.TICK and guard < 12:
			sim.step(Sim.TICK)
			accum -= Sim.TICK
			guard += 1
			if sim.phase != "combat":
				break
		_sim_dt = float(guard) * Sim.TICK
	else:
		accum = 0.0
	if sim.phase == "combat" and holding and not show_bestiary:
		_cast_at(mouse_pos)
	_handle_events()
	_update_fx(delta)
	queue_redraw()


func _update_fx(delta: float) -> void:
	demon_anim.update(delta)
	var rate: float = float(speed) if sim.phase == "combat" else 1.0
	if juice.hitstop > 0.0:
		rate = 0.0
	poses.update(sim, _sim_dt, delta, rate)
	var keep: Array = []
	for f in fx:
		f["t"] += delta
		if f["t"] < f["ttl"]:
			keep.append(f)
	fx = keep
	var keepw: Array = []
	for w in warns:
		w["t"] += delta
		if w["t"] < w["ttl"]:
			keepw.append(w)
	warns = keepw
	for k in mut_anim.keys():
		mut_anim[k] += delta
		if mut_anim[k] > 1.9:
			mut_anim.erase(k)
	banner_t = maxf(0.0, banner_t - delta)
	for ts in toasts:
		ts["t"] += delta
	if not toasts.is_empty() and float(toasts[0]["t"]) > 3.8:
		toasts.pop_front()
	juice.update(delta)
	flash_red = maxf(0.0, flash_red - delta * 2.5)
	flash_white = maxf(0.0, flash_white - delta * 1.6)


func _play(name: String, min_gap: float = 0.0) -> void:
	if min_gap > 0.0:
		var last: float = float(sound_last.get(name, -10.0))
		if clock - last < min_gap:
			return
		sound_last[name] = clock
	if not sound.streams.has(name):
		return
	var p: AudioStreamPlayer = players[player_idx]
	player_idx = (player_idx + 1) % players.size()
	p.stream = sound.streams[name]
	p.volume_db = -8.0
	p.play()


func _lane_y(lane: int) -> float:
	return sim.lane_y(lane)


func _enemy_pos(id: int) -> Vector2:
	var e: Dictionary = sim.enemy_by_id(id)
	if e.is_empty():
		return Vector2(-100, -100)
	return sim.epos(e)


func _creature_pos(c: Dictionary) -> Vector2:
	var y: float = _lane_y(int(c["lane"]))
	if c["air"] and c["kind"] != "manta":
		var k: float = clampf(float(c["t"]) / float(sim.B["trueno"]["jump_time"]), 0.0, 1.0)
		y = lerpf(_lane_y(int(c["from_lane"])), _lane_y(int(c["to_lane"])), k) - sin(k * PI) * 130.0
	return Vector2(c["x"], y)


func _creature_pos_by_id(id: int) -> Vector2:
	var c: Dictionary = sim.creature_by_id(id)
	if c.is_empty():
		return Vector2(-100, -100)
	return _creature_pos(c)


func _add_fx(d: Dictionary) -> void:
	if not d.has("t"):
		d["t"] = 0.0
	fx.append(d)


func _float(p: Vector2, text: String, col: Color, ttl: float = 1.0) -> void:
	_add_fx({"type": "float", "p": p, "text": text, "col": col, "ttl": ttl})


func _warn(d: Dictionary) -> void:
	d["t"] = 0.0
	warns.append(d)


# ----------------------------------------------------------------------------
# Eventos de la simulación -> sonido y señales visuales
# ----------------------------------------------------------------------------

func _handle_events() -> void:
	for ev in sim.events:
		_on_event(ev)
	sim.events.clear()


func _on_event(ev: Dictionary) -> void:
	var t: String = ev["t"]
	menu.tut_event(self, ev)
	poses.on_event(ev, sim)
	for lid in logros.on_event(sim, ev, not challenge.is_empty()):
		var ld: Dictionary = logros.def(String(lid))
		var extra: String = ""
		if ld.has("unlock"):
			sim.unlocked = logros.unlocked_boons()
			extra = "Nuevo don en el draft: %s" % String(sim.draft_def(String(ld["unlock"])).get("title", ""))
		toasts.append({"title": String(ld["name"]), "desc": String(ld["desc"]), "extra": extra, "t": 0.0})
		_play("level")
		_save_meta()
	match t:
		"placed":
			_play("click")
		"bought":
			_play("buy")
		"route_chosen":
			_play("buy")
		"loan_ojo":
			_play("revive")
			var op: Vector2 = _creature_pos_by_id(int(ev["id"]))
			_float(op + Vector2(0, -110), "Ojo prestado esta oleada", Color(0.95, 0.85, 0.4), 2.2)
		"wave_start":
			_play("horn")
			var w: Dictionary = sim.current_wave()
			var hero: bool = false
			for g in w["spawns"]:
				if g["kind"] == "@hero":
					hero = true
			if hero:
				banner_text = "Llega %s" % String(sim.ROUTES[sim.route]["hero_name"])
				banner_t = 2.2
				banner_dur = 2.2
			else:
				banner_text = "Oleada %d: %s" % [int(ev["wave"]), String(w["title"])]
				banner_t = 1.6
				banner_dur = 1.6
		"brasa_cast":
			_play("brasa_cast")
			demon_anim.play("brasa")
		"brasa_land":
			_play("horno_spit")
			juice.burst(ev["p"], 26, Color(1.0, 0.5, 0.15), 260.0, 0.7, 3.0, 380.0, 120.0)
			if int(ev["hits"]) >= 3:
				juice.stop(0.06)
			juice.add_trauma(0.21)
			_add_fx({"type": "ring", "p": ev["p"], "r0": 10.0, "r1": float(ev["r"]), "col": Color(1.0, 0.55, 0.2, 0.9), "ttl": 0.45})
			_add_fx({"type": "disc", "p": ev["p"], "r": float(ev["r"]), "col": Color(1.0, 0.5, 0.15, 0.35), "ttl": 0.5})
		"rayo":
			_play("rayo")
			# el rayo sale de la mano en el fotograma de impacto del clip (si hay animación)
			var rdelay: float = Anim.impact_delay("demonio", "rayo") if demon_anim.play("rayo") else 0.0
			var rfrom: Vector2 = Anim.hand_at("demonio", "rayo", demon_feet())
			if rfrom == Vector2.INF:
				rfrom = ev["from"]
			juice.burst(ev["to"] + Vector2(0, -30), 8, Color(0.7, 0.9, 1.0), 240.0, 0.25, 2.0, 200.0)
			_add_fx({"type": "bolt", "a": rfrom, "b": ev["to"], "col": Color(0.75, 0.9, 1.0), "ttl": 0.18, "t": -rdelay})
			_add_fx({"type": "ring", "p": ev["to"], "r0": 4.0, "r1": 26.0, "col": Color(0.75, 0.9, 1.0, 0.9), "ttl": 0.2, "t": -rdelay})
			if rdelay > 0.0:
				_add_fx({"type": "ring", "p": rfrom, "r0": 6.0, "r1": 30.0, "col": Color(0.8, 0.92, 1.0, 0.9), "ttl": 0.16, "t": -rdelay})
		"rayo_chain":
			_play("rayo")
			var cdelay: float = Anim.impact_delay("demonio", "rayo") if demon_anim.clip == "rayo" else 0.0
			_add_fx({"type": "bolt", "a": ev["from"], "b": ev["to"], "col": Color(0.9, 0.95, 1.0), "ttl": 0.22, "t": -cdelay})
		"leveled":
			_play("level")
			_float(_creature_pos_by_id(int(ev["id"])) + Vector2(0, -110), "Nivel %d" % int(ev["level"]), Color(1.0, 0.9, 0.4), 1.4)
		"bite":
			_play("bite", 0.06)
		"hit":
			_play("hit", 0.05)
			var hp0: Vector2 = Vector2(ev["x"], float(ev.get("y", _lane_y(int(ev["lane"])))) - 34)
			_add_fx({"type": "ring", "p": hp0, "r0": 4.0, "r1": 16.0, "col": Color(1, 1, 1, 0.8), "ttl": 0.15})
			juice.flash(int(ev.get("id", -1)))
			juice.burst(hp0, 4, Color(1.0, 0.85, 0.5), 160.0, 0.3, 2.0, 400.0)
			juice.number(hp0 + Vector2(0, -30), float(ev.get("amount", 0.0)), int(ev.get("id", -1)))
		"kill":
			_play("kill", 0.04)
			var kp: Vector2 = Vector2(ev["x"], float(ev.get("y", _lane_y(int(ev["lane"])))) - 30)
			_float(kp + Vector2(30, -8), "+%d" % int(ev["reward"]), Color(0.6, 0.9, 1.0, 0.85), 0.8)
			var kst: Dictionary = sim.B["enemies"].get(String(ev.get("kind", "")), {})
			var big: bool = kst.get("elite", false) or kst.get("hero", false) or kst.get("boss", false)
			juice.burst(kp, 18 if big else 9, Color(0.25, 0.12, 0.1), 220.0, 0.6, 3.5, 500.0)
			juice.burst(kp, 10 if big else 4, Color(1.0, 0.55, 0.2), 180.0, 0.8, 2.5, -40.0, 60.0)
			if big:
				juice.stop(0.09)
				juice.add_trauma(0.35)
				_play("big_kill")
		"presa_windup":
			_play("presa_windup")
			_warn({"type": "presa", "eid": int(ev["target"]), "ttl": 0.4})
		"presa":
			var pc: Dictionary = sim.creature_by_id(int(ev["id"]))
			_play("alacran_grab" if not pc.is_empty() and pc["kind"] == "alacran" else "presa")
		"horno_inhale":
			_play("horno_inhale")
			_warn({"type": "inhale", "cid": int(ev["id"]), "ttl": float(sim.B["horno"]["inhale_time"]) + 0.2})
		"horno_spit":
			_play("horno_spit")
			juice.add_trauma(0.28)
			_add_fx({"type": "fire", "x0": ev["x0"], "x1": ev["x1"], "y": _lane_y(int(ev["lane"])), "ttl": 0.7})
			if not bool(ev["minor"]):
				_float(Vector2((float(ev["x0"]) + float(ev["x1"])) * 0.5, _lane_y(int(ev["lane"])) - 90), "LLAMARADA", Color(1.0, 0.6, 0.2), 1.1)
		"trueno_crouch":
			_play("trueno_crouch")
			_warn({"type": "crouch", "cid": int(ev["id"]), "eid": int(ev["target"]), "ttl": float(sim.B["trueno"]["crouch_time"]) + 0.1})
		"trueno_jump":
			_play("trueno_jump")
			_add_fx({"type": "line", "a": Vector2(ev["from_x"], _lane_y(int(ev["from_lane"])) - 30), "b": Vector2(ev["to_x"], _lane_y(int(ev["to_lane"])) - 30), "col": Color(0.6, 0.8, 1.0), "w": 3.0, "ttl": 0.5})
			_float(Vector2(ev["from_x"], _lane_y(int(ev["from_lane"])) - 100), "Hueco abierto", Color(1.0, 0.5, 0.4), 1.4)
		"trueno_land":
			_play("trueno_land")
			juice.add_trauma(0.42)
			_add_fx({"type": "ring", "p": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 10), "r0": 10.0, "r1": 150.0, "col": Color(0.7, 0.85, 1.0), "ttl": 0.45})
		"ojo_shot":
			_play("ojo_shot", 0.08)
			var cp: Vector2 = _creature_pos_by_id(int(ev["id"]))
			_add_fx({"type": "line", "a": cp + Vector2(0, -62), "b": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 30), "col": Color(1.0, 0.9, 0.4), "w": 2.0, "ttl": 0.1})
		"ojo_chain":
			_play("ojo_chain")
			var op2: Vector2 = _enemy_pos(int(ev["from"]))
			for tid in ev["to"]:
				var tp: Vector2 = _enemy_pos(int(tid))
				if tp.x > 0.0 and op2.x > 0.0:
					_add_fx({"type": "line", "a": op2 + Vector2(0, -30), "b": tp + Vector2(0, -30), "col": Color(1.0, 0.95, 0.5), "w": 3.0, "ttl": 0.3})
			_float(op2 + Vector2(0, -80), "COMBO", Color(1.0, 0.95, 0.5), 0.9)
		"ojo_mark":
			_play("ojo_mark")
		"bell":
			_play("bell")
			_warn({"type": "bell", "cid": int(ev["id"]), "ttl": 1.0})
		"heal":
			_play("heal", 0.2)
			_float(Vector2(ev["x"], _lane_y(int(ev["lane"])) - 70), "+", Color(0.4, 1.0, 0.5), 0.7)
		"shot":
			_play("shot", 0.08)
			_add_fx({"type": "line", "a": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 30), "b": Vector2(ev["tx"], _lane_y(int(ev["lane"])) - 30), "col": Color(0.8, 0.8, 0.8), "w": 2.0, "ttl": 0.1})
		"aim":
			_play("tirador_aim")
			_warn({"type": "aim", "eid": int(ev["id"]), "range": float(ev["range"]), "ttl": float(ev["aim"])})
		"tirador_shot":
			_play("tirador_shot")
			juice.add_trauma(0.21)
			_add_fx({"type": "line", "a": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 30), "b": Vector2(ev["tx"], _lane_y(int(ev["lane"])) - 30), "col": Color(1.0, 0.9, 0.6), "w": 6.0, "ttl": 0.25})
		"sweep_wind":
			_play("tajo_wind")
			_warn({"type": "sweep", "eid": int(ev["id"]), "ttl": float(ev["wind"])})
		"sweep":
			_play("tajo_sweep")
			juice.stop(0.05)
			juice.add_trauma(0.49)
			_add_fx({"type": "ring", "p": Vector2(ev["x"], ev["y"]), "r0": 10.0, "r1": float(ev["r"]), "col": Color(1.0, 0.35, 0.2, 0.9), "ttl": 0.4})
			_add_fx({"type": "disc", "p": Vector2(ev["x"], ev["y"]), "r": float(ev["r"]), "col": Color(1.0, 0.3, 0.15, 0.3), "ttl": 0.4})
		"ring":
			_play("campana_ring")
			juice.add_trauma(0.21)
			_add_fx({"type": "ring", "p": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 10), "r0": 20.0, "r1": float(ev["r"]), "col": Color(0.95, 0.85, 0.3, 0.9), "ttl": 0.6})
			_float(Vector2(ev["x"], _lane_y(int(ev["lane"])) - 120), "REPIQUE", Color(0.95, 0.85, 0.3), 1.1)
		"sapo_windup":
			_play("sapo_windup")
			_warn({"type": "presa", "eid": int(ev["target"]), "ttl": float(sim.B["sapo"]["windup"])})
		"sapo_spit":
			_play("sapo_spit")
			var sp: Vector2 = Vector2(ev["x"], ev["y"])
			_add_fx({"type": "line", "a": Vector2(ev["from_x"], _lane_y(int(ev["lane"])) - 40), "b": sp, "col": Color(0.25, 0.15, 0.1), "w": 6.0, "ttl": 0.25})
			_add_fx({"type": "ring", "p": sp, "r0": 8.0, "r1": float(sim.B["sapo"]["tar_radius"]), "col": Color(0.3, 0.2, 0.1, 0.9), "ttl": 0.4})
		"manta_dive":
			_play("manta_dive")
		"manta_glide":
			_play("manta_glide")
			_add_fx({"type": "line", "a": Vector2(0, _lane_y(int(ev["lane"])) - 20), "b": Vector2(SCREEN_W, _lane_y(int(ev["lane"])) - 20), "col": Color(0.7, 0.5, 0.9, 0.5), "w": 2.0, "ttl": 0.5})
		"draft":
			banner_text = "Elige una recompensa"
			banner_t = 1.4
			banner_dur = 1.4
		"creature_hit":
			juice.flash(1000000 + int(ev["id"]))
			var chp: Vector2 = _creature_pos_by_id(int(ev["id"]))
			if chp.x > 0.0:
				juice.burst(chp + Vector2(0, -40), 3, Color(0.8, 0.15, 0.1), 140.0, 0.35, 2.5, 500.0)
				if float(ev.get("amount", 0.0)) >= 15.0:
					juice.number(chp + Vector2(0, -90), float(ev["amount"]), -1, Color(1.0, 0.4, 0.35))
		"elite_spawn":
			var ek: String = String(ev["kind"])
			if sim.B["enemies"][ek].get("hero", false) or sim.B["enemies"][ek].get("boss", false):
				_play("horn")
			else:
				_play("elite")
				_float(Vector2(1150, _lane_y(int(ev["lane"])) - 120), "¡%s!" % sim.label(ek), Color(1.0, 0.8, 0.35), 1.8)
		"stone":
			_play("guardia")
			var sp0: Vector2 = _creature_pos_by_id(int(ev["id"]))
			_float(sp0 + Vector2(0, -110), "PIEDRA", Color(0.8, 0.8, 0.85), 1.0)
		"stone_absorb":
			_play("hit", 0.08)
		"stone_break":
			_play("trueno_land")
			juice.add_trauma(0.3)
			var sbp: Vector2 = Vector2(ev["x"], _lane_y(int(ev["lane"])) - 30)
			_add_fx({"type": "ring", "p": sbp, "r0": 10.0, "r1": float(ev["r"]), "col": Color(0.85, 0.8, 0.75, 0.9), "ttl": 0.45})
			juice.burst(sbp, 22, Color(0.55, 0.52, 0.5), 280.0, 0.6, 3.5, 600.0)
		"swarm":
			_play("enjambre", 0.1)
			var swp: Vector2 = _creature_pos_by_id(int(ev["id"])) + Vector2(0, -56)
			for tid2 in ev["targets"]:
				var tp2: Vector2 = _enemy_pos(int(tid2))
				if tp2.x > 0.0:
					_add_fx({"type": "line", "a": swp, "b": tp2 + Vector2(0, -40), "col": Color(1.0, 0.6, 0.2, 0.7), "w": 2.0, "ttl": 0.3})
					juice.burst(tp2 + Vector2(0, -40), 8, Color(1.0, 0.6, 0.2), 120.0, 0.5, 2.0, 0.0)
		"hook_windup":
			_play("presa_windup")
			_warn({"type": "hook", "cid": int(ev["id"]), "eid": int(ev["target"]), "ttl": float(sim.B["garfio"]["hook_windup"])})
		"hook":
			_play("garfio")
			var gp0: Vector2 = _creature_pos_by_id(int(ev["id"]))
			var gp1: Vector2 = _enemy_pos(int(ev["target"]))
			if gp1.x > 0.0:
				_add_fx({"type": "line", "a": gp0 + Vector2(20, -46), "b": gp1 + Vector2(0, -40), "col": Color(0.75, 0.85, 0.9), "w": 3.0, "ttl": 0.4})
		"shield_pulse":
			_play("escudo", 0.2)
			_add_fx({"type": "ring", "p": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 20), "r0": 10.0, "r1": float(ev["r"]), "col": Color(0.6, 0.85, 1.0, 0.8), "ttl": 0.5})
		"explode":
			_play("explosion")
			juice.add_trauma(0.45)
			var xp: Vector2 = Vector2(ev["x"], float(ev.get("y", _lane_y(int(ev["lane"])))) - 30)
			juice.burst(xp, 30, Color(1.0, 0.55, 0.15), 340.0, 0.7, 4.0, 300.0)
			juice.burst(xp, 16, Color(0.2, 0.15, 0.12), 200.0, 1.0, 5.0, -30.0)
			_float(xp + Vector2(0, -50), "¡BUM!", Color(1.0, 0.5, 0.2), 1.0)
		"summon":
			_play("horn")
			banner_text = "El Gran Maestre llama a su escolta"
			banner_t = 1.6
			banner_dur = 1.6
		"judgment_wind":
			_play("juicio_carga")
			_warn({"type": "judgment", "lane": int(ev["lane"]), "x": float(ev["x"]), "ttl": float(ev["wind"])})
		"judgment":
			_play("juicio")
			juice.add_trauma(0.5)
			juice.stop(0.07)
			var jy2: float = _lane_y(int(ev["lane"]))
			_add_fx({"type": "disc", "p": Vector2((150.0 + float(ev["x"])) * 0.5, jy2), "r": 60.0, "col": Color(1.0, 0.95, 0.7, 0.0), "ttl": 0.1})
			_add_fx({"type": "line", "a": Vector2(150, jy2 - 10), "b": Vector2(ev["x"], jy2 - 10), "col": Color(1.0, 0.97, 0.75), "w": 40.0, "ttl": 0.35})
			flash_white = 0.35
		"set":
			var sd: Dictionary = sim.B["draft"]["sets"][String(ev["family"])]
			banner_text = "Resonancia: %s" % String(sd["name"])
			banner_t = 2.2
			banner_dur = 2.2
			flash_white = 0.3
			_play("mutate")
		"augur_done":
			_float(Vector2(640, 240), "Augurio cumplido: %s" % String(sim.augur_def(String(ev["id"])).get("name", "")), Color(0.85, 0.65, 1.0), 1.8)
		"draft_pick":
			_play("level")
			_save_meta()
		"heal_pulse":
			_play("lumbrero")
			juice.burst(Vector2(ev["x"], _lane_y(int(ev["lane"])) - 40), 14, Color(0.6, 1.0, 0.7), 90.0, 1.0, 2.5, -60.0)
			_add_fx({"type": "ring", "p": Vector2(ev["x"], _lane_y(int(ev["lane"])) - 10), "r0": 10.0, "r1": float(ev["r"]), "col": Color(0.6, 1.0, 0.7, 0.8), "ttl": 0.5})
		"door_hit":
			_play("door_hit", 0.1)
			if not demon_anim.busy():
				demon_anim.play("golpe")
			juice.burst(Vector2(140, _lane_y(int(ev["lane"])) - 40), 6, Color(0.5, 0.3, 0.2), 200.0, 0.5, 3.0, 600.0)
			juice.add_trauma(0.35)
			flash_red = 0.5
			_float(Vector2(120, _lane_y(int(ev["lane"])) - 40), "-%d" % int(ev["amount"]), Color(1.0, 0.3, 0.3))
		"execute":
			_float(_creature_pos_by_id(int(ev["id"])) + Vector2(0, -100), "EJECUCION", Color(1.0, 0.2, 0.2), 1.2)
		"creature_down":
			_play("down")
			var dp: Vector2 = _creature_pos_by_id(int(ev["id"]))
			if bool(ev["named"]):
				_float(dp + Vector2(0, -100), "Tizón cae... volverá", Color(1.0, 0.7, 0.5), 1.8)
			else:
				_float(dp + Vector2(0, -80), "cae", Color(1.0, 0.7, 0.5), 1.0)
		"revived":
			_play("revive")
			var rp: Vector2 = _creature_pos_by_id(int(ev["id"]))
			_float(rp + Vector2(0, -110), "Vuelve con una cicatriz", Color(1.0, 0.45, 0.4), 2.4)
		"mutated":
			_play("mutate")
			mut_anim[int(ev["id"])] = 0.0
			flash_white = 0.7
			banner_text = "%s se convierte en %s" % [String(ev["name"]), sim.label(String(ev["form"]))]
			banner_t = 2.4
			banner_dur = 2.4
			_save_bestiary()
		"form_seen":
			_save_bestiary()
		"wave_clear":
			_play("buy")
			_save_bestiary()
			_save_meta()
		"victory":
			_play("win")
			if not challenge.is_empty():
				new_record = sim.wave_count() > int(records.get(record_key(), 0))
				records[record_key()] = maxi(int(records.get(record_key(), 0)), sim.wave_count())
			demon_anim.play("victoria")
			var sid: String = sim.siege_id()
			unlock_note = ""
			var first: bool = not siege_wins.has(sid)
			if first or int(siege_wins[sid]) < sim.wrath:
				siege_wins[sid] = sim.wrath
				if sim.wrath < int(sim.B["wrath"]["max"]):
					unlock_note = "Se abre Ira %d en este asedio." % (sim.wrath + 1)
			if first:
				for sg in sim.SIEGES:
					if String(sg.get("unlock", "")) == sid:
						unlock_note = "Se abre: %s. %s" % [String(sg["name"]), unlock_note]
			_save_bestiary()
			_save_meta()
		"defeat":
			_play("lose")
			new_record = false
			var rkey: String = record_key()
			if rkey != "":
				var cleared: int = sim.defeat_wave - 1
				if cleared > int(records.get(rkey, 0)):
					records[rkey] = cleared
					new_record = cleared > 0
				_save_meta()
			demon_anim.play("derrota")
			_save_bestiary()


# ----------------------------------------------------------------------------
# Bestiario (archivo sencillo en user://)
# ----------------------------------------------------------------------------

func _load_bestiary() -> void:
	if not FileAccess.file_exists(BESTIARY_PATH):
		return
	var f: FileAccess = FileAccess.open(BESTIARY_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var forms: Array = data.get("formas", [])
	for fm in forms:
		if FORM_INFO.has(String(fm)) and not sim.seen_forms.has(fm):
			sim.seen_forms.append(fm)


func _save_bestiary() -> void:
	if Engine.has_meta("sin_persistencia"):
		return
	var t: Dictionary = sim.named_creature()
	var rec: Dictionary = {}
	if not t.is_empty():
		rec = {"nombre": t["name"], "forma": t["kind"], "bajas": t["kills"], "cicatrices": t["scars"]}
	var data: Dictionary = {"formas": sim.seen_forms, "tizon": rec}
	var f: FileAccess = FileAccess.open(BESTIARY_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))


# ----------------------------------------------------------------------------
# Entrada
# ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if intro_layer != null:
		if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
			_end_intro()
			get_viewport().set_input_as_handled()
		return
	if menu.open:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			menu.press(self, event.position)
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE and menu.started:
				menu.toggle(self)
			elif (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and menu.panel == "main":
				menu._do(self, "continue" if menu.started and sim.phase != "victory" and sim.phase != "defeat" else "new")
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb.position)
			else:
				_on_release(mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_toggle_spell()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER:
				if show_tree:
					pass
				elif sim.phase == "prep":
					sim.start_wave()
				elif sim.phase == "victory" or sim.phase == "defeat":
					_restart()
			elif k.keycode == KEY_F:
				speed = speed % 3 + 1
			elif k.keycode == KEY_B:
				show_bestiary = not show_bestiary
			elif k.keycode == KEY_T:
				_toggle_tree()
			elif k.keycode == KEY_ESCAPE:
				if show_tree or show_bestiary:
					show_tree = false
					show_bestiary = false
				else:
					holding = false
					menu.toggle(self)
			elif k.keycode == KEY_1:
				spell = "brasa"
			elif k.keycode == KEY_2:
				spell = "rayo"


func _draft_active() -> bool:
	return sim.phase == "prep" and not sim.draft.is_empty()


func _draft_rect(i: int) -> Rect2:
	return Rect2(100.0 + float(i) * 370.0, 170.0, 340.0, 330.0)


func _toggle_tree() -> void:
	if _draft_active():
		return
	if sim.phase == "prep" or sim.phase == "victory" or sim.phase == "defeat":
		show_tree = not show_tree
		_play("click")
	else:
		show_tree = false


func _toggle_spell() -> void:
	spell = "rayo" if spell == "brasa" else "brasa"
	_play("click")


func _cast_at(p: Vector2) -> void:
	if not _in_arena(p) or _over_button(p):
		return
	if spell == "brasa":
		sim.cast_brasa(p)
	else:
		sim.cast_rayo(p)


func _in_arena(p: Vector2) -> bool:
	return p.y > ARENA_TOP and p.y < ARENA_BOTTOM


func _over_button(p: Vector2) -> bool:
	for b in _buttons():
		if b["rect"].has_point(p):
			return true
	return false


func _nearest_lane(y: float) -> int:
	var best: int = 0
	var bd: float = 1e9
	for i in 3:
		var d: float = absf(y - _lane_y(i))
		if d < bd:
			bd = d
			best = i
	return best


func _restart() -> void:
	holding = false
	if not challenge.is_empty():
		sim.rng.seed = int(challenge["seed"])   # el reto siempre empieza igual
	sim.reset()
	fx.clear()
	warns.clear()
	mut_anim.clear()
	demon_anim = Anim.new("demonio")
	poses.reset()
	selected_id = -1
	dragging = false
	accum = 0.0
	banner_t = 0.0
	banner_dur = 0.0
	_play("click")


func _buttons() -> Array:
	if _draft_active():
		var dout: Array = []
		for i in sim.draft.size():
			dout.append({"id": "draft:%d" % i, "rect": _draft_rect(i), "text": "", "sub": "", "on": true})
		return dout
	if show_tree:
		if sim.phase != "prep" and sim.phase != "victory" and sim.phase != "defeat":
			show_tree = false
		else:
			return _tree_buttons()
	var out: Array = []
	var ph: String = sim.phase
	var y: float = 624.0
	if ph == "prep":
		out.append({"id": "buy_sabueso", "rect": Rect2(20, y, 150, 72), "text": "Sabueso", "sub": "%d almas" % sim.cost_of("sabueso"), "on": sim.can_buy("sabueso")})
		out.append({"id": "buy_ojo", "rect": Rect2(180, y, 150, 72), "text": "Ojo de Latón", "sub": "%d almas" % sim.cost_of("ojo"), "on": sim.can_buy("ojo")})
		var can_any: bool = false
		for sid in sim.SK_ORDER:
			if sim.can_skill(sid):
				can_any = true
				break
		out.append({"id": "tree", "rect": Rect2(340, y, 150, 72), "text": "Árbol (T)", "sub": "%d rangos" % sim.skill_points_spent(), "on": true, "active": can_any})
		var lsub: String = "elige una bestia"
		var lon: bool = false
		if selected_id >= 0:
			var sc: Dictionary = sim.creature_by_id(selected_id)
			if not sc.is_empty():
				var lc: int = sim.level_cost(sc)
				lsub = "máximo" if lc < 0 else "%d almas" % lc
				lon = sim.can_level(selected_id)
		out.append({"id": "level", "rect": Rect2(500, y, 150, 72), "text": "Subir nivel", "sub": lsub, "on": lon})
		out.append({"id": "start", "rect": Rect2(1030, y, 230, 72), "text": "Iniciar oleada", "sub": "Espacio", "on": true})
	elif ph == "combat":
		var bcd: float = sim.brasa_cd / float(sim._stats("brasa")["cd"])
		var rcd: float = sim.rayo_cd / float(sim._stats("rayo")["cd"])
		out.append({"id": "spell_brasa", "rect": Rect2(20, y, 150, 72), "text": "Brasa", "sub": "tecla 1", "on": true, "cd": bcd, "active": spell == "brasa"})
		out.append({"id": "spell_rayo", "rect": Rect2(180, y, 150, 72), "text": "Rayo", "sub": "tecla 2", "on": true, "cd": rcd, "active": spell == "rayo"})
	elif ph == "route":
		out.append({"id": "route_verdugo", "rect": Rect2(150, 150, 480, 360), "text": "", "sub": "", "on": true})
		out.append({"id": "route_inquisidor", "rect": Rect2(650, 150, 480, 360), "text": "", "sub": "", "on": true})
	elif ph == "forge":
		out.append({"id": "forge", "rect": Rect2(490, 430, 300, 64), "text": "Entregar a Tizón", "sub": "", "on": true})
	elif ph == "victory" or ph == "defeat":
		out.append({"id": "restart", "rect": Rect2(490, 480, 300, 64), "text": "Reiniciar", "sub": "Espacio", "on": true})
		out.append({"id": "tree", "rect": Rect2(490, 552, 300, 64), "text": "Árbol (T)", "sub": "%d esencia" % sim.essence, "on": true})
		out.append({"id": "menu", "rect": Rect2(810, 480, 160, 64), "text": "Menú", "sub": "Esc", "on": true})
	out.append({"id": "speed", "rect": Rect2(820, y, 90, 72), "text": "Velocidad", "sub": "x%d" % speed, "on": true})
	out.append({"id": "bestiary", "rect": Rect2(920, y, 100, 72), "text": "Bestiario", "sub": "B", "on": true})
	return out


func _do_button(id: String) -> void:
	if id.begins_with("draft:"):
		sim.draft_pick(int(id.substr(6)))
		return
	if id.begins_with("sk:"):
		if sim.buy_skill(id.substr(3)):
			_play("level")
			_save_meta()
		return
	match id:
		"start":
			sim.start_wave()
		"buy_sabueso":
			sim.buy("sabueso")
		"buy_ojo":
			sim.buy("ojo")
		"tree":
			_toggle_tree()
		"tree_close":
			show_tree = false
		"level":
			sim.level_up(selected_id)
		"spell_brasa":
			spell = "brasa"
		"spell_rayo":
			spell = "rayo"
		"speed":
			speed = speed % 3 + 1
			_play("click")
		"bestiary":
			show_bestiary = not show_bestiary
			_play("click")
		"route_verdugo":
			sim.choose_route("verdugo")
		"route_inquisidor":
			sim.choose_route("inquisidor")
		"forge":
			sim.give_relic()
		"restart":
			_restart()
		"menu":
			menu.toggle(self)


func _creature_at(p: Vector2) -> int:
	var best: int = -1
	for c in sim.creatures:
		if c["dead"]:
			continue
		var cp: Vector2 = _creature_pos(c)
		var top: float = -110.0 if c["kind"] == "ojo" or c["kind"] == "horno" else -80.0
		if p.x >= cp.x - 44.0 and p.x <= cp.x + 56.0 and p.y >= cp.y + top and p.y <= cp.y + 12.0:
			best = int(c["id"])
	return best


func _on_press(p: Vector2) -> void:
	if show_bestiary:
		show_bestiary = false
		return
	for b in _buttons():
		if b["rect"].has_point(p):
			if b["on"]:
				_do_button(String(b["id"]))
			return
	if show_tree:
		return
	if sim.phase == "combat":
		if _in_arena(p):
			holding = true
			_cast_at(p)
		return
	if sim.phase != "prep":
		return
	for ar in _augur_rects():
		if ar["rect"].has_point(p):
			var pick: String = String(ar["id"])
			sim.choose_augur("" if pick == sim.augur else pick)
			_play("click")
			return
	var cid: int = _creature_at(p)
	if cid >= 0:
		selected_id = cid
		dragging = true
		return
	if selected_id >= 0 and _in_arena(p):
		if sim.place_at(selected_id, p.x, _nearest_lane(p.y)):
			selected_id = -1
		else:
			_float(p + Vector2(0, -20), "no cabe ahí", Color(1.0, 0.5, 0.4), 0.9)
		return
	selected_id = -1


func _on_release(p: Vector2) -> void:
	holding = false
	if not dragging:
		return
	dragging = false
	if sim.phase != "prep" or selected_id < 0:
		return
	var c: Dictionary = sim.creature_by_id(selected_id)
	if c.is_empty():
		return
	if _creature_pos(c).distance_to(p) < 24.0:
		return
	if not _in_arena(p):
		return
	if sim.place_at(selected_id, p.x, _nearest_lane(p.y)):
		selected_id = -1
	else:
		_float(p + Vector2(0, -20), "no cabe ahí", Color(1.0, 0.5, 0.4), 0.9)


# ----------------------------------------------------------------------------
# Dibujo
# ----------------------------------------------------------------------------

func _txt(s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.6))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.08, 0.03, 0.04))
	arena_offset = juice.offset()
	draw_set_transform(arena_offset, 0.0, Vector2.ONE)
	_draw_arena()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud()
	_draw_boons()
	_draw_lane_preview()
	_draw_tree()
	_draw_draft()
	_draw_overlays()
	_draw_buttons()
	if show_bestiary:
		_draw_bestiary()
	_draw_tooltip()
	if flash_red > 0.0:
		draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(1.0, 0.1, 0.05, flash_red * 0.3))
	if flash_white > 0.0:
		draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(1.0, 0.85, 0.6, flash_white * 0.6))
	if banner_t > 0.0 and not _overlay_open():
		var a: float = clampf(banner_t / 0.5, 0.0, 1.0)
		var slide: float = (1.0 - clampf((banner_dur - banner_t) / 0.25, 0.0, 1.0)) * 60.0
		draw_rect(Rect2(0, 300, SCREEN_W, 90), Color(0, 0, 0, 0.55 * a))
		_txt(banner_text, Vector2(slide, 360), 44, Color(1.0, 0.85, 0.5, a), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
	_draw_toasts()
	menu.tut_draw(self)
	menu.draw(self)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))


func _draw_arena() -> void:
	var bgt: Texture2D = Art.background()
	if bgt != null:
		draw_texture_rect(bgt, Rect2(0, 0, SCREEN_W, SCREEN_H), false)
		_draw_arena_rest(true)
		return
	# suelo de piedra continuo con baldosas en perspectiva
	var floor_top: float = ARENA_TOP
	draw_rect(Rect2(40, floor_top, SCREEN_W - 40, ARENA_BOTTOM - floor_top), Color(0.15, 0.08, 0.09))
	for r in 9:
		var ty: float = floor_top + r * 58.0
		var shade: float = 0.015 * float(r % 2)
		draw_rect(Rect2(40, ty, SCREEN_W - 40, 29.0), Color(0.17 + shade, 0.09 + shade, 0.10 + shade, 0.55))
		draw_line(Vector2(40, ty), Vector2(SCREEN_W, ty), Color(0.05, 0.02, 0.03, 0.8), 2.0)
		var off: float = 0.0 if r % 2 == 0 else 60.0
		var tx: float = 140.0 + off
		while tx < SCREEN_W:
			draw_line(Vector2(tx, ty), Vector2(tx, ty + 58.0), Color(0.05, 0.02, 0.03, 0.5), 2.0)
			tx += 120.0
	# oscuridad del fondo y entrada de los humanos por la derecha
	draw_rect(Rect2(40, floor_top, SCREEN_W - 40, 40), Color(0, 0, 0, 0.35))
	for i in 3:
		draw_rect(Rect2(SCREEN_W - 26, _lane_y(i) - 40, 26, 80), Color(0.5, 0.35, 0.2, 0.35))
	_draw_arena_rest(false)


func _draw_arena_rest(painted: bool) -> void:
	if not painted:
		var door_rect: Rect2 = Rect2(40, _lane_y(0) - 70, 90, _lane_y(2) - _lane_y(0) + 140)
		Art.draw_door(draw_ctx(), door_rect, clampf(sim.door_hp / sim.door_max, 0.0, 1.0), 0.0)
	juice.draw_back(self)
	_draw_demon()
	# zonas de despliegue: solo se resaltan al colocar
	if sim.phase == "prep":
		_draw_zones()
	# suelo en llamas
	for z in sim.zones:
		var zy: float = _lane_y(int(z["lane"]))
		var za: float = clampf(float(z["t"]) / 1.0, 0.0, 1.0)
		draw_rect(Rect2(float(z["x0"]), zy - 20, float(z["x1"]) - float(z["x0"]), 40), Color(1.0, 0.4, 0.1, 0.25 * za))
		var n: int = int((float(z["x1"]) - float(z["x0"])) / 26.0)
		for k in n:
			var fx0: float = float(z["x0"]) + k * 26.0 + 10.0
			var h: float = 12.0 + 8.0 * sin(clock * 9.0 + k)
			draw_colored_polygon(PackedVector2Array([Vector2(fx0 - 7, zy + 18), Vector2(fx0, zy + 18 - h), Vector2(fx0 + 7, zy + 18)]), Color(1.0, 0.5, 0.15, 0.7 * za))
	for tp in sim.tar_pools:
		var ta: float = clampf(float(tp["t"]) / 1.0, 0.0, 1.0)
		var pp: Vector2 = tp["p"]
		var rr: float = float(tp["r"])
		# draw_set_transform sustituye la transformación: hay que volver a sumar el temblor
		draw_set_transform(arena_offset + pp, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, rr, Color(0.12, 0.07, 0.04, 0.55 * ta))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 28, Color(0.5, 0.3, 0.12, 0.8 * ta), 2.0)
		draw_set_transform(arena_offset, 0.0, Vector2.ONE)
	# hueco del Trueno
	for c in sim.creatures:
		if c["kind"] == "trueno" and not c["dead"] and c["state"] != "home":
			var hp: Vector2 = Vector2(c["home_x"], _lane_y(int(c["home_lane"])))
			draw_arc(hp, 34.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.25, 0.4 + 0.4 * sin(clock * 8.0)), 3.0)
			_txt("HUECO", hp + Vector2(-30, -48), 16, Color(1.0, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	# criaturas y enemigos ordenados por profundidad (más abajo = más cerca)
	var items: Array = []
	for c2 in sim.creatures:
		if c2["dead"]:
			continue
		var cy: float = _creature_pos(c2).y
		if c2["air"]:
			cy = 2000.0
		items.append({"y": cy, "c": c2})
	for e in sim.enemies:
		items.append({"y": sim.epos(e).y, "e": e})
	items.sort_custom(func(a, b): return a["y"] < b["y"])
	for it in items:
		if it.has("c"):
			_draw_creature(it["c"])
		else:
			_draw_enemy(it["e"])
	_draw_brasas()
	_draw_fx_and_warns()
	juice.draw_front(self, font)
	if sim.phase == "combat":
		_draw_aim()


func _zone_rect(depth: String) -> Rect2:
	var z: Dictionary = sim.B["zones"][depth]
	var top: float = _lane_y(0) - 64.0
	return Rect2(float(z["x0"]) - 20.0, top, float(z["x1"]) - float(z["x0"]) + 40.0, _lane_y(2) - _lane_y(0) + 128.0)


func _draw_zones() -> void:
	var active: bool = selected_id >= 0
	var a: float = 0.20 if active else 0.08
	var rr: Rect2 = _zone_rect("rear")
	var fr: Rect2 = _zone_rect("front")
	draw_rect(rr, Color(0.35, 0.5, 0.9, a))
	draw_rect(fr, Color(1.0, 0.55, 0.2, a))
	draw_rect(rr, Color(0.5, 0.65, 1.0, 0.5 if active else 0.25), false, 2.0)
	draw_rect(fr, Color(1.0, 0.7, 0.3, 0.5 if active else 0.25), false, 2.0)
	_txt("RETAGUARDIA", Vector2(rr.position.x, rr.position.y - 6), 15, Color(0.6, 0.75, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	_txt("VANGUARDIA", Vector2(fr.position.x, fr.position.y - 6), 15, Color(1.0, 0.75, 0.4, 0.9), HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
	if active and _in_arena(mouse_pos):
		var lane: int = _nearest_lane(mouse_pos.y)
		var gx: float = clampf(mouse_pos.x, sim.zone_min_x(), sim.zone_max_x())
		var ok: bool = sim.spot_ok(gx, lane, selected_id)
		var col: Color = Color(0.4, 1.0, 0.5, 0.8) if ok else Color(1.0, 0.3, 0.3, 0.8)
		var gp: Vector2 = Vector2(gx, _lane_y(lane))
		draw_arc(gp, 30.0, 0.0, TAU, 24, col, 3.0)
		draw_circle(gp, 30.0, Color(col.r, col.g, col.b, 0.15))


## Pies del demonio en la arena (donde cae el sprite fijo y el ancla de los fotogramas).
func demon_feet() -> Vector2:
	return sim.demon_pos() + Vector2(34, 32)


## Dibuja el demonio animado (o el sprite fijo si no hay fotogramas). false si no hay ni sprite.
func draw_demon_at(feet: Vector2, sc: float = 1.0) -> bool:
	var fr: Dictionary = demon_anim.draw_opts()
	if fr.is_empty():
		return Art.draw_sprite(self, "demonio", feet, clock, {"bob": sin(clock * 2.0) * 2.0, "scale": sc})
	return Art.draw_sprite(self, "demonio", feet, clock, {"frame": fr, "scale": sc})


func _draw_demon() -> void:
	var dp: Vector2 = sim.demon_pos() + Vector2(34, 10)
	var animated: bool = not demon_anim.draw_opts().is_empty()
	if draw_demon_at(demon_feet()):
		if animated:
			return

		var pulse0: float = 0.5 + 0.5 * sin(clock * 3.0)
		draw_circle(dp + Vector2(52, -106), 8.0 + 6.0 * pulse0, Color(1.0, 0.55, 0.2, 0.18 + 0.2 * pulse0))
		return
	var pulse: float = 0.5 + 0.5 * sin(clock * 3.0)
	draw_circle(dp + Vector2(0, 6), 26.0, Color(0, 0, 0, 0.35))
	draw_colored_polygon(PackedVector2Array([dp + Vector2(-16, 4), dp + Vector2(-12, -44), dp + Vector2(0, -56), dp + Vector2(12, -44), dp + Vector2(16, 4)]), Color(0.55, 0.08, 0.1))
	draw_circle(dp + Vector2(0, -60), 11.0, Color(0.7, 0.12, 0.12))
	draw_colored_polygon(PackedVector2Array([dp + Vector2(-10, -66), dp + Vector2(-20, -88), dp + Vector2(-3, -70)]), Color(0.9, 0.85, 0.7))
	draw_colored_polygon(PackedVector2Array([dp + Vector2(10, -66), dp + Vector2(20, -88), dp + Vector2(3, -70)]), Color(0.9, 0.85, 0.7))
	draw_circle(dp + Vector2(-4, -61), 2.0, Color(1.0, 0.85, 0.3))
	draw_circle(dp + Vector2(4, -61), 2.0, Color(1.0, 0.85, 0.3))
	var hand: Vector2 = dp + Vector2(22, -34)
	draw_line(dp + Vector2(10, -40), hand, Color(0.55, 0.08, 0.1), 5.0)
	draw_circle(hand, 5.0 + 3.0 * pulse, Color(1.0, 0.55, 0.2, 0.6 + 0.4 * pulse))


func _draw_brasas() -> void:
	var origin: Vector2 = Anim.hand_at("demonio", "brasa", demon_feet())
	var imp: float = Anim.impact_delay("demonio", "brasa")
	if origin == Vector2.INF:
		origin = sim.demon_pos() + Vector2(56, -34)
		imp = 0.0
	for b in sim.pending_brasas:
		var delay: float = maxf(0.01, float(b["d"]))
		var k: float = clampf(1.0 - float(b["t"]) / delay, 0.0, 1.0)
		var target: Vector2 = b["p"]
		draw_arc(target, float(b["r"]), 0.0, TAU, 36, Color(1.0, 0.45, 0.1, 0.9), 3.0)
		draw_arc(target, float(b["r"]) * (1.0 - k), 0.0, TAU, 36, Color(1.0, 0.8, 0.3, 0.7), 2.0)
		# la bola sale de la mano en el fotograma de impacto del clip y vuela el resto del retraso
		var since: float = delay - float(b["t"])
		if imp > 0.0 and delay > imp * 1.5:
			if since < imp:
				continue
			k = clampf((since - imp) / (delay - imp), 0.0, 1.0)
		var pp: Vector2 = origin.lerp(target, k) + Vector2(0, -sin(k * PI) * 170.0)
		draw_circle(pp, 11.0, Color(1.0, 0.55, 0.15))
		draw_circle(pp, 6.0, Color(1.0, 0.9, 0.5))


func _draw_aim() -> void:
	if not _in_arena(mouse_pos) or _over_button(mouse_pos) or show_bestiary or show_tree:
		return
	if spell == "brasa":
		var r: float = sim.brasa_radius()
		var ready: bool = sim.brasa_cd <= 0.0
		var col: Color = Color(1.0, 0.5, 0.15, 0.9) if ready else Color(0.6, 0.4, 0.3, 0.6)
		draw_circle(mouse_pos, r, Color(col.r, col.g, col.b, 0.12))
		draw_arc(mouse_pos, r, 0.0, TAU, 40, col, 3.0)
		var cap: String = "Brasa: cae en %.1f s" % float(sim._stats("brasa")["delay"]) if ready else "recarga %.1f s" % sim.brasa_cd
		_txt(cap, mouse_pos + Vector2(-80, -r - 8), 16, col, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	else:
		var rg: float = float(sim._stats("rayo")["range"])
		var origin: Vector2 = sim.demon_pos()
		draw_arc(origin, rg, -0.9, 0.9, 40, Color(0.7, 0.85, 1.0, 0.25), 2.0)
		var tgt: Dictionary = sim.rayo_target(mouse_pos)
		var ready2: bool = sim.rayo_cd <= 0.0
		var col2: Color = Color(0.75, 0.9, 1.0, 0.95) if ready2 else Color(0.5, 0.55, 0.65, 0.6)
		draw_arc(mouse_pos, float(sim._stats("rayo")["pick_radius"]), 0.0, TAU, 24, Color(col2.r, col2.g, col2.b, 0.35), 2.0)
		if not tgt.is_empty():
			var tp: Vector2 = sim.epos(tgt)
			draw_arc(tp + Vector2(0, -30), 34.0, 0.0, TAU, 24, col2, 3.0)
			draw_line(origin + Vector2(40, -40), tp + Vector2(0, -30), Color(col2.r, col2.g, col2.b, 0.3), 1.5)
		var cap2: String = "Rayo: golpe inmediato" if ready2 else "recarga %.1f s" % sim.rayo_cd
		_txt(cap2, mouse_pos + Vector2(-80, -52), 16, col2, HORIZONTAL_ALIGNMENT_CENTER, 160.0)


func draw_ctx() -> CanvasItem:
	return self


func _draw_creature(c: Dictionary) -> void:
	var pos: Vector2 = _creature_pos(c)
	var kind: String = c["kind"]
	var scale_v: float = 1.0
	var glow: float = 0.0
	var m: float = float(mut_anim.get(int(c["id"]), -1.0))
	if m >= 0.0:
		if m < 0.9:
			kind = "sabueso"
			glow = m / 0.9
			scale_v = 1.0 + 0.18 * sin(m * 38.0) * glow
			pos += Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)) * glow
		else:
			glow = 1.0 - (m - 0.9) / 1.0
			scale_v = 1.0 + 0.25 * glow
			draw_arc(pos + Vector2(0, -34), (m - 0.9) * 260.0, 0.0, TAU, 32, Color(1.0, 0.7, 0.3, clampf(glow, 0.0, 1.0)), 4.0)
	var crouch: bool = c["state"] == "crouch"
	if crouch:
		pos.y += 4.0
	var opts: Dictionary = {"scale": scale_v, "scars": c["scars"], "hambre": c["hambre"], "crouch": crouch, "stone": c["state"] == "stone",
		"fallen": c["fallen"], "glow": glow, "flash": 0.0}
	if c["stun"] > 0.0:
		opts["flash"] = 0.15
	opts["flash"] = maxf(float(opts["flash"]), juice.flash_of(1000000 + int(c["id"])))
	if selected_id == int(c["id"]):
		draw_arc(pos + Vector2(0, -34), 52.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.4, 0.8), 3.0)
	var id: int = int(c["id"])
	if m < 0.0 and not c["fallen"] and not c["air"] and c["state"] != "stone":
		var fr: Dictionary = poses.frame_of(id)
		var look: float = poses.facing(id)
		var pz: Dictionary = poses.pose(id, clock, look, juice.flash_of(1000000 + id),
			float(c["windup"]) > 0.0 or crouch, not fr.is_empty(), poses.clip_of(id) == "mordisco")
		opts["frame"] = fr
		opts["posed"] = true
		opts["no_shadow"] = true
		_draw_posed(pos, pz, look, Art.shadow_w(kind, scale_v), func(): Art.draw_creature(self, kind, Vector2.ZERO, clock + float(id), opts))
	else:
		Art.draw_creature(self, kind, pos, clock + float(id), opts)
	if c["stun"] > 0.0:
		_txt("aturdido", pos + Vector2(-30, -110), 15, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	for lv in int(c["level"]) - 1:
		draw_circle(pos + Vector2(-8 + lv * 12, 40), 4.0, Color(1.0, 0.85, 0.3))
	if c["named"]:
		var nm: String = String(c["name"])
		_txt(nm, pos + Vector2(-50, 24), 18, Color(1.0, 0.85, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	if c["fallen"]:
		_txt("caído", pos + Vector2(-30, -46), 16, Color(1.0, 0.7, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	elif sim.phase == "combat" and c["hp"] < c["max_hp"]:
		_bar(pos + Vector2(-26, -100 if kind == "horno" or kind == "ojo" else -82), 52.0, float(c["hp"]) / float(c["max_hp"]), Color(0.4, 0.9, 0.4))
	if c["loaned"]:
		_txt("prestado", pos + Vector2(-34, 24), 14, Color(0.9, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 68.0)


func _draw_toasts() -> void:
	if toasts.is_empty() or sim.phase == "victory" or sim.phase == "defeat":
		return   # en la pantalla final los logros ya salen en su línea
	var ts: Dictionary = toasts[0]
	var t: float = float(ts["t"])
	var a: float = clampf(minf(t / 0.3, (3.8 - t) / 0.5), 0.0, 1.0)
	var extra: String = String(ts.get("extra", ""))
	var r: Rect2 = Rect2(SCREEN_W * 0.5 - 260, 86 - 30.0 * (1.0 - a), 520, 58 if extra == "" else 78)
	draw_rect(r, Color(0.08, 0.04, 0.02, 0.88 * a))
	draw_rect(r, Color(1.0, 0.8, 0.35, a), false, 2.0)
	_txt("LOGRO: %s" % String(ts["title"]), r.position + Vector2(0, 24), 19, Color(1.0, 0.85, 0.45, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_txt(String(ts["desc"]), r.position + Vector2(0, 46), 14, Color(0.9, 0.85, 0.75, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if extra != "":
		_txt(extra, r.position + Vector2(0, 67), 14, Color(0.85, 0.65, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Dibuja una unidad con su pose de código: sombra plana en el suelo y cuerpo girado/escalado desde
## los pies. draw_set_transform sustituye la transformación, así que se compone con el temblor.
## flip = -1 la dibuja mirando al otro lado (una bestia que vuelve a casa).
func _draw_posed(pos: Vector2, pz: Dictionary, flip: float, shadow_w: float, body: Callable) -> void:
	Art.shadow(self, pos, shadow_w * (1.0 + 0.5 * (pz["scale"].x - 1.0)))
	var sc: Vector2 = pz["scale"]
	draw_set_transform(arena_offset + pos + pz["shift"], pz["rot"], Vector2(sc.x * flip, sc.y))
	body.call()
	draw_set_transform(arena_offset, 0.0, Vector2.ONE)


func _bar(p: Vector2, w: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(p, Vector2(w, 6)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(p, Vector2(w * clampf(frac, 0.0, 1.0), 6)), col)


func _draw_enemy(e: Dictionary) -> void:
	var pos: Vector2 = sim.epos(e)
	var kind: String = e["kind"]
	var variant: int = 0 if bool(sim.B["enemies"][kind].get("hero", false)) else int(float(e["bump"]) * 4.0) % 4
	var hfl: float = juice.flash_of(int(e["id"]))
	var opts: Dictionary = {"burning": e["burn_t"] > 0.0, "bump": e["bump"], "flash": hfl, "variant": variant}
	var elite: bool = bool(sim.B["enemies"][kind].get("elite", false))
	var est0: Dictionary = sim.B["enemies"][kind]
	if est0.has("tint"):
		var tn: Array = est0["tint"]
		opts["tint"] = Color(float(tn[0]), float(tn[1]), float(tn[2]))
	if est0.has("sprite") and not elite:
		opts["sprite"] = String(est0["sprite"])
		opts["scale"] = float(est0.get("scale", 1.0))
	if bool(est0.get("boss", false)):
		draw_circle(pos + Vector2(0, -130), 70.0 + 6.0 * sin(clock * 3.0), Color(1.0, 0.9, 0.5, 0.10))
		draw_arc(pos + Vector2(0, -232), 26.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.5, 0.8), 3.0)
	if elite and est0.has("sprite"):
		opts["sprite"] = String(sim.B["enemies"][kind]["sprite"])
		opts["scale"] = float(sim.B["enemies"][kind].get("scale", 1.0))
		var ep0: Vector2 = pos
		draw_arc(ep0 + Vector2(0, 4), 30.0, 0.0, TAU, 20, Color(1.0, 0.82, 0.3, 0.55 + 0.25 * sin(clock * 4.0)), 3.0)
		if sim.B["enemies"][kind].has("haste_radius"):
			draw_arc(ep0 + Vector2(0, 4), float(sim.B["enemies"][kind]["haste_radius"]), 0.0, TAU, 40, Color(1.0, 0.5, 0.2, 0.22), 2.0)
		if sim.B["enemies"][kind].has("cover_range"):
			draw_line(ep0 + Vector2(0, -6), ep0 + Vector2(float(sim.B["enemies"][kind]["cover_range"]), -6), Color(0.9, 0.85, 0.6, 0.4), 4.0)
	var eid: int = int(e["id"])
	opts["posed"] = true
	opts["no_shadow"] = true
	var epz: Dictionary = poses.pose(eid, clock, -1.0, hfl, float(e.get("aim_t", 0.0)) > 0.0, false, false)
	var esw: float = Art.shadow_w(kind, float(opts.get("scale", 1.0)), String(opts.get("sprite", "")))
	_draw_posed(pos, epz, 1.0, esw, func(): Art.draw_enemy(self, kind, Vector2.ZERO, clock, opts))
	var st: Dictionary = sim.B["enemies"][kind]
	var top: float = -118.0 if (kind == "verdugo" or kind == "inquisidor" or kind == "tajo" or kind == "campana") else -62.0
	if elite:
		top = -128.0 if (kind == "tajo" or kind == "campana") else -92.0
		if kind == "ariete":
			top = -124.0
		elif kind == "paladin":
			top = -102.0
	if bool(st.get("boss", false)):
		top = -250.0
		_txt(sim.label(kind), pos + Vector2(-100, top - 8), 16, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_bar(pos + Vector2(-50, top), 100.0, float(e["hp"]) / float(e["max_hp"]), Color(1.0, 0.75, 0.25))
	elif elite:
		_txt(sim.label(kind), pos + Vector2(-100, top - 8), 13, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	if (e["hp"] < e["max_hp"] or bool(st.get("hero", false)) or elite) and not bool(st.get("boss", false)):
		_bar(pos + Vector2(-22, top), 44.0, float(e["hp"]) / float(e["max_hp"]), Color(0.9, 0.3, 0.3))
	if float(e.get("shield", 0.0)) > 0.0:
		draw_arc(pos + Vector2(0, -40), 34.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.45 + 0.2 * sin(clock * 6.0)), 3.0)
	if bool(st.get("explode", false)):
		var fz: Vector2 = pos + Vector2(-14, -70)
		draw_circle(fz, 6.0, Color(0.15, 0.1, 0.08))
		draw_circle(fz + Vector2(0, -8), 2.5 + 1.5 * sin(clock * 30.0), Color(1.0, 0.8, 0.3))
	if e["burn_t"] > 0.0:
		var fl: float = 6.0 + 4.0 * sin(clock * 14.0 + float(e["id"]))
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, -10), pos + Vector2(0, -10 - fl * 2.0), pos + Vector2(8, -10)]), Color(1.0, 0.5, 0.1, 0.8))
	var stt: float = top - 26.0 if elite else top - 8.0
	if e["held"] > 0.0:
		draw_arc(pos + Vector2(0, -26), 26.0, 0.0, TAU, 20, Color(0.8, 0.8, 0.8), 3.0)
		_txt("agarrado", pos + Vector2(-45, stt), 14, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	if e["stun"] > 0.0 and e["held"] <= 0.0:
		_txt("retenido", pos + Vector2(-45, stt), 14, Color(0.95, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	if e["marked"]:
		var r: float = 28.0 + 3.0 * sin(clock * 8.0)
		draw_arc(pos + Vector2(0, -34), r, 0.0, TAU, 24, Color(0.6, 0.85, 1.0), 3.0)
		_txt("MARCA", pos + Vector2(-30, stt - 12), 15, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	if e["pull_t"] > 0.0:
		draw_line(pos + Vector2(0, -30), Vector2(e["pull_x"], pos.y - 30), Color(1.0, 0.5, 0.2, 0.5), 2.0)


func _draw_fx_and_warns() -> void:
	for w in warns:
		var k: float = clampf(float(w["t"]) / float(w["ttl"]), 0.0, 1.0)
		var blink: float = 0.5 + 0.5 * sin(float(w["t"]) * 22.0)
		match String(w["type"]):
			"presa":
				var ep: Vector2 = _enemy_pos(int(w["eid"]))
				if ep.x > 0.0:
					draw_arc(ep + Vector2(0, -30), 34.0 - 14.0 * k, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.5 + 0.5 * blink), 4.0)
					_txt("PRESA", ep + Vector2(-30, -80), 17, Color(1.0, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			"inhale":
				var hc: Dictionary = sim.creature_by_id(int(w["cid"]))
				if not hc.is_empty():
					var hy: float = _lane_y(int(hc["lane"]))
					var rng: float = float(sim.B["horno"]["inhale_range"])
					draw_rect(Rect2(float(hc["x"]) + 40.0, hy - 48, rng * (1.0 - k * 0.5), 96), Color(1.0, 0.45, 0.1, 0.13 + 0.1 * blink))
					_txt("INHALA", Vector2(float(hc["x"]) - 10.0, hy - 108), 18, Color(1.0, 0.6, 0.2), HORIZONTAL_ALIGNMENT_CENTER, 80.0)
			"crouch":
				var tc: Vector2 = _creature_pos_by_id(int(w["cid"]))
				var te: Vector2 = _enemy_pos(int(w["eid"]))
				if te.x > 0.0 and tc.x > 0.0:
					draw_line(tc + Vector2(0, -40), te + Vector2(0, -40), Color(0.6, 0.8, 1.0, 0.35 + 0.4 * blink), 2.0)
					draw_arc(te + Vector2(0, -34), 36.0 - 10.0 * k, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.6 + 0.4 * blink), 4.0)
					_txt("SALTA", tc + Vector2(-30, -110), 18, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			"aim":
				var ap: Vector2 = _enemy_pos(int(w["eid"]))
				if ap.x > 0.0:
					draw_line(ap + Vector2(0, -30), ap + Vector2(-float(w["range"]), -30), Color(1.0, 0.3, 0.2, 0.25 + 0.45 * blink), 3.0)
					_txt("VIROTE", ap + Vector2(-30, -110), 17, Color(1.0, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			"sweep":
				var sp: Vector2 = _enemy_pos(int(w["eid"]))
				if sp.x > 0.0:
					draw_circle(sp + Vector2(-60, -10), 120.0 * (0.4 + 0.6 * (1.0 - k)), Color(1.0, 0.25, 0.15, 0.12 + 0.18 * blink))
					draw_arc(sp + Vector2(-60, -10), 120.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.2, 0.5 + 0.4 * blink), 3.0)
					_txt("BARRIDO", sp + Vector2(-40, -150), 17, Color(1.0, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, 80.0)
			"bell":
				var bc: Vector2 = _creature_pos_by_id(int(w["cid"]))
				if bc.x > 0.0:
					draw_arc(bc + Vector2(0, -34), 40.0 + 40.0 * k, 0.0, TAU, 28, Color(0.95, 0.85, 0.3, 1.0 - k), 4.0)
					_txt("CAMPANA", bc + Vector2(-34, -100), 17, Color(0.95, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 68.0)
			"judgment":
				var jy: float = _lane_y(int(w["lane"]))
				var jx: float = float(w["x"])
				draw_rect(Rect2(150, jy - 50, jx - 150, 100), Color(1.0, 0.95, 0.6, 0.10 + 0.22 * blink * k))
				draw_line(Vector2(150, jy - 50), Vector2(jx, jy - 50), Color(1.0, 0.9, 0.5, 0.7), 2.0)
				draw_line(Vector2(150, jy + 50), Vector2(jx, jy + 50), Color(1.0, 0.9, 0.5, 0.7), 2.0)
				_txt("JUICIO: ¡APARTA A TUS BESTIAS!", Vector2(150, jy - 58), 18, Color(1.0, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, jx - 150)
			"hook":
				var hc2: Vector2 = _creature_pos_by_id(int(w["cid"]))
				var he: Vector2 = _enemy_pos(int(w["eid"]))
				if hc2.x > 0.0 and he.x > 0.0:
					draw_line(hc2 + Vector2(20, -46), he + Vector2(0, -40), Color(0.7, 0.9, 1.0, 0.3 + 0.4 * blink), 2.0)
					draw_arc(he + Vector2(0, -34), 30.0, 0.0, TAU, 20, Color(0.7, 0.9, 1.0, 0.6 + 0.4 * blink), 3.0)
					_txt("GARFIO", hc2 + Vector2(-34, -110), 17, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 68.0)
	for f in fx:
		if float(f["t"]) < 0.0:
			continue   # efecto con retraso (p. ej. el rayo espera al fotograma de impacto)
		var fk: float = clampf(float(f["t"]) / float(f["ttl"]), 0.0, 1.0)
		match String(f["type"]):
			"disc":
				var dcol: Color = f["col"]
				dcol.a = dcol.a * (1.0 - fk)
				draw_circle(f["p"], float(f["r"]), dcol)
			"bolt":
				var bcol: Color = f["col"]
				bcol.a = 1.0 - fk
				var ba: Vector2 = f["a"]
				var bb: Vector2 = f["b"]
				var pts: PackedVector2Array = PackedVector2Array([ba])
				for j in range(1, 7):
					var tt: float = float(j) / 7.0
					var jit: Vector2 = Vector2(sin(clock * 90.0 + j * 7.0), cos(clock * 77.0 + j * 5.0)) * 14.0
					pts.append(ba.lerp(bb, tt) + jit)
				pts.append(bb)
				draw_polyline(pts, bcol, 4.0)
				draw_polyline(pts, Color(1, 1, 1, bcol.a), 1.5)
			"line":
				var lc: Color = f["col"]
				lc.a = 1.0 - fk
				draw_line(f["a"], f["b"], lc, float(f["w"]))
			"ring":
				var rc: Color = f["col"]
				rc.a = rc.a * (1.0 - fk)
				draw_arc(f["p"], lerpf(float(f["r0"]), float(f["r1"]), fk), 0.0, TAU, 28, rc, 3.0)
			"fire":
				var fy: float = float(f["y"])
				var fa: float = 1.0 - fk
				var fw: float = float(f["x1"]) - float(f["x0"])
				draw_rect(Rect2(float(f["x0"]), fy - 30, fw * minf(1.0, fk * 4.0), 56), Color(1.0, 0.5, 0.1, 0.45 * fa))
			"float":
				var fc: Color = f["col"]
				fc.a = 1.0 - fk * fk
				var fp: Vector2 = f["p"]
				# ancho según el texto (antes se cortaban los largos) y sin salirse de la pantalla
				var fw: float = font.get_string_size(String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8.0
				var fx0: float = clampf(fp.x - fw * 0.5, 4.0, SCREEN_W - fw - 4.0)
				_txt(String(f["text"]), Vector2(fx0, fp.y - fk * 34.0), 20, fc, HORIZONTAL_ALIGNMENT_CENTER, fw)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, 78), Color(0.05, 0.02, 0.03))
	draw_line(Vector2(0, 78), Vector2(SCREEN_W, 78), Color(0.4, 0.12, 0.08), 3.0)
	_txt("ALMAS %d" % sim.souls, Vector2(24, 44), 30, Color(0.7, 0.9, 1.0))
	var sg_txt: String = sim.siege_name().get_slice(":", 0)
	if sim.wrath > 0:
		sg_txt += "  ·  Ira %d" % sim.wrath
	if not challenge.is_empty():
		sg_txt = "Reto semanal  ·  " + sg_txt
	_txt(sg_txt, Vector2(24, 68), 14, Color(0.85, 0.6, 0.5))
	var shown_wave: int = mini(sim.wave_index + 1, sim.wave_count())
	if sim.phase == "victory":
		shown_wave = sim.wave_count()
	var w: Dictionary = sim.WAVES[mini(sim.wave_index, sim.wave_count() - 1)]
	if sim.phase == "victory":
		w = sim.WAVES[sim.wave_count() - 1]
	var title: String = "Oleada %d / %d  -  %s" % [shown_wave, sim.wave_count(), String(w["title"])]
	if sim.is_endless():
		title = "Oleada %d  -  %s" % [shown_wave, String(w["title"])]
	if sim.phase == "route" or sim.phase == "forge":
		title = "Entre oleadas"
	_txt(title, Vector2(240, 36), 24, Color(1.0, 0.85, 0.55))
	var note: String = String(w.get("note", ""))
	if sim.phase == "prep" and note != "":
		_txt(note, Vector2(240, 62), 17, Color(0.8, 0.7, 0.65))
	elif sim.phase != "prep":
		_txt(_phase_hint(), Vector2(240, 62), 17, Color(0.8, 0.7, 0.65))
	_txt("PUERTA", Vector2(900, 34), 18, Color(1.0, 0.7, 0.5))
	var frac: float = clampf(sim.door_hp / sim.door_max, 0.0, 1.0)
	draw_rect(Rect2(900, 42, 340, 22), Color(0, 0, 0, 0.7))
	var dcol: Color = Color(0.9, 0.7, 0.2).lerp(Color(0.9, 0.15, 0.1), 1.0 - frac)
	draw_rect(Rect2(900, 42, 340.0 * frac, 22), dcol)
	_txt("%d / %d" % [int(ceil(sim.door_hp)), int(sim.door_max)], Vector2(900, 60), 16, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 340.0)
	# panel inferior
	draw_rect(Rect2(0, 604, SCREEN_W, 116), Color(0.05, 0.02, 0.03))
	draw_line(Vector2(0, 604), Vector2(SCREEN_W, 604), Color(0.4, 0.12, 0.08), 3.0)
	if sim.phase == "prep":
		_txt("Arrastra bestias a las zonas marcadas: vanguardia hace de muro, retaguardia dispara. Selecciona una para subirla de nivel. T abre el árbol de habilidades.", Vector2(20, 618), 14, Color(0.75, 0.65, 0.6))
	elif sim.phase == "combat":
		var left: int = sim.spawn_queue.size() + sim.enemies.size()
		_txt("Quedan %d enemigos." % left, Vector2(340, 646), 17, Color(0.95, 0.85, 0.7))
		if sim.augur != "":
			_txt("Augurio: %s" % String(sim.augur_def(sim.augur).get("name", "")), Vector2(560, 646), 15, Color(0.85, 0.65, 1.0))
		_txt("Clic: lanza (mantén para repetir). Clic dcho. o rueda: cambia.", Vector2(340, 672), 14, Color(0.8, 0.7, 0.65), HORIZONTAL_ALIGNMENT_LEFT, 470.0)


func _phase_hint() -> String:
	match sim.phase:
		"combat":
			return "Combate"
		"route":
			return "Elige una ruta"
		"forge":
			return "Una reliquia espera"
		"victory":
			return "La Puerta resiste"
		"defeat":
			return "La Puerta ha caído"
	return ""


func _draw_lane_preview() -> void:
	if sim.phase != "prep" or show_tree:
		return
	var tot: Dictionary = _preview_tot()
	var pv: Array = sim.preview(sim.wave_index)
	var rows: int = tot.size()
	var h: float = 44.0 + 20.0 * float(rows)
	var box: Rect2 = Rect2(1040, 98, 232, h)
	draw_rect(box, Color(0, 0, 0, 0.6))
	draw_rect(box, Color(0.5, 0.2, 0.15), false, 2.0)
	_txt("LLEGARÁ POR LA DERECHA", Vector2(box.position.x + 10, box.position.y + 20), 15, Color(0.9, 0.5, 0.4))
	var y: float = box.position.y + 42.0
	for k in tot.keys():
		var kk: String = String(k)
		var hero: bool = bool(sim.B["enemies"].get(kk, {}).get("hero", false)) or kk == "heroe"
		var col: Color = Color(1.0, 0.35, 0.3) if hero else Color(0.9, 0.85, 0.8)
		var line: String = "%d x %s" % [int(tot[k]), sim.label(kk)]
		var fs: int = 16 if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < box.size.x - 16 else 13
		_txt(line, Vector2(box.position.x + 10, y), fs, col)
		y += 20.0
	if sim.augur_fx("one_front") > 0.0:
		_txt("todos por el mismo frente (Niebla)", Vector2(box.position.x + 10, box.end.y + 18), 14, Color(0.85, 0.65, 1.0))
	elif not pv[3].is_empty():
		_txt("sin orden y por cualquier frente", Vector2(box.position.x + 10, box.end.y + 18), 14, Color(0.8, 0.7, 0.6))
	_draw_augurs()


## Lo que llega en la próxima oleada, con el augurio elegido aplicado.
func _preview_tot() -> Dictionary:
	var tot: Dictionary = sim.preview_totals(sim.wave_index)
	var cnt: float = sim.augur_fx("count")
	if cnt > 0.0:
		for k0 in tot.keys():
			var est: Dictionary = sim.B["enemies"].get(String(k0), {})
			if not (est.get("elite", false) or est.get("hero", false) or est.get("boss", false)):
				tot[k0] = int(round(float(tot[k0]) * (1.0 + cnt)))
	var extra_el: int = int(sim.augur_fx("extra_elite"))
	if extra_el > 0:
		tot["élite al azar"] = extra_el
	return tot


## Tarjetas de augurio (riesgo/recompensa opcional) bajo la previsión de la oleada.
func _augur_rects() -> Array:
	var out: Array = []
	if sim.phase != "prep" or show_tree or _draft_active() or sim.augur_offer.is_empty():
		return out
	var rows: int = sim.preview_totals(sim.wave_index).size() + 1   # fila de reserva: Campeón añade una línea sin mover las tarjetas
	var y: float = 98.0 + 44.0 + 20.0 * float(rows) + 52.0
	for id in sim.augur_offer:
		out.append({"id": String(id), "rect": Rect2(1040, y, 232, 78)})
		y += 84.0
	return out


func _draw_augurs() -> void:
	var rects: Array = _augur_rects()
	if rects.is_empty():
		return
	var top: Vector2 = rects[0]["rect"].position
	_txt("AUGURIO (opcional)", top + Vector2(10, -8), 15, Color(0.85, 0.6, 1.0))
	for ar in rects:
		var r: Rect2 = ar["rect"]
		var a: Dictionary = sim.augur_def(String(ar["id"]))
		var on: bool = sim.augur == String(ar["id"])
		var hov: bool = r.has_point(mouse_pos)
		draw_rect(r, Color(0.22, 0.08, 0.28, 0.9) if on else Color(0.06, 0.02, 0.08, 0.82 if hov else 0.7))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else Color(0.55, 0.3, 0.65), false, 3.0 if on else 2.0)
		_txt(String(a.get("name", "")), r.position + Vector2(10, 20), 16, Color(1.0, 0.85, 0.5) if on else Color(0.92, 0.8, 1.0))
		draw_multiline_string(font, r.position + Vector2(10, 38), String(a.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 13, 3, Color(0.85, 0.8, 0.85))
	var last: Rect2 = rects[-1]["rect"]
	_txt("Elegido: %s" % String(sim.augur_def(sim.augur).get("name", "")) if sim.augur != "" else "Sin elegir: Calma", Vector2(last.position.x + 10, last.end.y + 16), 13, Color(0.75, 0.65, 0.8))


# --- Árbol de habilidades -------------------------------------------------------

const TREE_X0: float = 24.0
const TREE_DX: float = 154.0
const TREE_Y0: float = 122.0
const TREE_DY: float = 53.0
const TREE_W: float = 144.0
const TREE_H: float = 46.0


func _build_tree_pos() -> void:
	_tree_pos.clear()
	for ci in sim.BRANCHES.size():
		var idx: int = 0
		for id in sim.SK_ORDER:
			if sim.SK[id]["branch"] == sim.BRANCHES[ci]["id"]:
				_tree_pos[id] = Rect2(TREE_X0 + ci * TREE_DX, TREE_Y0 + idx * TREE_DY, TREE_W, TREE_H)
				idx += 1


func _node_rect(id: String) -> Rect2:
	if _tree_pos.is_empty():
		_build_tree_pos()
	return _tree_pos[id]


func _tree_buttons() -> Array:
	var out: Array = []
	for id in sim.SK_ORDER:
		out.append({"id": "sk:" + id, "rect": _node_rect(id), "text": "", "sub": "", "on": sim.can_skill(id)})
	out.append({"id": "tree_close", "rect": Rect2(490, 624, 300, 72), "text": "Cerrar árbol", "sub": "T / Esc", "on": true})
	return out


func _branch_color(id: String) -> Color:
	for b in sim.BRANCHES:
		if b["id"] == id:
			return Color.html(String(b["color"]))
	return Color.WHITE


func _draw_tree() -> void:
	if not show_tree:
		return
	draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0.03, 0.01, 0.03, 0.93))
	draw_rect(Rect2(0, 606, SCREEN_W, 30), Color(0.05, 0.02, 0.03))
	_txt("ÁRBOL DE HABILIDADES", Vector2(24, 666), 24, Color(1.0, 0.85, 0.55))
	_txt("%d esencia" % sim.essence, Vector2(1000, 666), 26, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 256.0)
	for ci in sim.BRANCHES.size():
		var br: Dictionary = sim.BRANCHES[ci]
		var bc: Color = _branch_color(String(br["id"]))
		var title: String = String(br["name"])
		if String(br["route"]) != "":
			title += " (ruta)"
		_txt(title, Vector2(TREE_X0 + ci * TREE_DX, 114), 15, bc, HORIZONTAL_ALIGNMENT_CENTER, TREE_W)
	# líneas de requisito
	for id in sim.SK_ORDER:
		var nd: Dictionary = sim.SK[id]
		var rc: Rect2 = _node_rect(id)
		for rq in nd["req"]:
			var pr: Rect2 = _node_rect(String(rq["id"]))
			var met: bool = sim.skill_rank(String(rq["id"])) >= int(rq["rank"])
			var lc: Color = _branch_color(String(nd["branch"]))
			lc.a = 0.7 if met else 0.22
			draw_line(pr.get_center(), rc.get_center(), lc, 2.0 if met else 1.5)
	var hov_id: String = ""
	for id in sim.SK_ORDER:
		var nd2: Dictionary = sim.SK[id]
		var r: Rect2 = _node_rect(id)
		var st: String = sim.skill_state(id)
		var bc2: Color = _branch_color(String(nd2["branch"]))
		var fill: Color = Color(0.12, 0.07, 0.09)
		var edge: Color = bc2.darkened(0.55)
		var tc: Color = Color(0.5, 0.45, 0.45)
		match st:
			"max":
				fill = bc2.darkened(0.55)
				edge = bc2
				tc = Color(1, 1, 1)
			"ok":
				fill = Color(0.2, 0.11, 0.1)
				edge = bc2
				tc = Color(1.0, 0.95, 0.85)
			"poor":
				fill = Color(0.16, 0.09, 0.09)
				edge = bc2.darkened(0.25)
				tc = Color(0.75, 0.68, 0.65)
		if skill_rank_pos(id):
			fill = fill.lerp(bc2.darkened(0.5), 0.5)
		var hov: bool = r.has_point(mouse_pos)
		if hov:
			hov_id = id
			fill = fill.lightened(0.18)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 2.0 if st != "ok" else 3.0)
		_txt(String(nd2["name"]), Vector2(r.position.x + 4, r.position.y + 18), 13, tc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0)
		var rank_txt: String = "%d/%d" % [sim.skill_rank(id), int(nd2["max"])]
		var cost: int = sim.skill_cost(id)
		var sub: String = rank_txt + ("   máx" if cost < 0 else "   %d esencia" % cost)
		if st == "route":
			sub = rank_txt + "   (ruta)"
		_txt(sub, Vector2(r.position.x + 4, r.position.y + 38), 12, tc.darkened(0.1), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0)
	if hov_id != "":
		_draw_skill_tip(hov_id)


func skill_rank_pos(id: String) -> bool:
	return sim.skill_rank(id) > 0


func _draw_skill_tip(id: String) -> void:
	var nd: Dictionary = sim.SK[id]
	var lines: Array = []
	lines.append("%s   rango %d / %d" % [String(nd["name"]), sim.skill_rank(id), int(nd["max"])])
	lines.append(String(nd["desc"]))
	var st: String = sim.skill_state(id)
	if st == "locked":
		var need: Array = []
		for rq in nd["req"]:
			if sim.skill_rank(String(rq["id"])) < int(rq["rank"]):
				need.append("%s %d" % [String(sim.SK[rq["id"]]["name"]), int(rq["rank"])])
		lines.append("Requiere: " + ", ".join(need))
	elif st == "route":
		lines.append("Se abre al elegir esta ruta.")
	elif st == "poor":
		lines.append("Cuesta %d esencia (te faltan %d)." % [sim.skill_cost(id), sim.skill_cost(id) - sim.currency()])
	elif st == "ok":
		lines.append("Clic para comprar: %d esencia." % sim.skill_cost(id))
	var w: float = 470.0
	var h: float = 14.0 + 22.0 * lines.size()
	var r: Rect2 = _node_rect(id)
	var p: Vector2 = Vector2(clampf(r.position.x, 8.0, SCREEN_W - w - 8.0), r.end.y + 6.0)
	if p.y + h > 600.0:
		p.y = r.position.y - h - 6.0
	draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.92))
	draw_rect(Rect2(p, Vector2(w, h)), _branch_color(String(nd["branch"])), false, 2.0)
	for i in lines.size():
		var col: Color = Color(1.0, 0.9, 0.6) if i == 0 else Color(0.92, 0.88, 0.84)
		_txt(String(lines[i]), p + Vector2(10, 22 + 22 * i), 15, col, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0)


func _draw_draft() -> void:
	if not _draft_active():
		return
	draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(0, 606, SCREEN_W, 30), Color(0.05, 0.02, 0.03))
	_txt("Elige una para continuar.", Vector2(0, 666), 20, Color(0.85, 0.75, 0.65), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
	_txt("ELIGE UNA RECOMPENSA", Vector2(0, 130), 34, Color(1.0, 0.85, 0.55), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
	for i in sim.draft.size():
		var o: Dictionary = sim.draft[i]
		var r: Rect2 = _draft_rect(i)
		var hov: bool = r.has_point(mouse_pos)
		var rar: String = String(o.get("rarity", "comun"))
		var rc: Color = RARITY_COL.get(rar, RARITY_COL["comun"])
		if rar != "comun":
			# halo de rareza
			var gl: float = 0.5 + 0.5 * sin(clock * 2.5 + float(i))
			draw_rect(r.grow(6.0 + 3.0 * gl), Color(rc.r, rc.g, rc.b, 0.12 + 0.1 * gl))
		draw_rect(r, Color(0.2, 0.09, 0.07) if not hov else Color(0.33, 0.15, 0.1))
		draw_rect(r, Color(1.0, 0.85, 0.4) if hov else rc, false, 3.0 if rar == "comun" else 4.0)
		var beast: bool = String(o["type"]) == "beast"
		var head: String = "BESTIA" if beast else "RECOMPENSA"
		if String(o["type"]) == "boon":
			head = "DON ÉPICO" if rar == "epica" else "DON RARO"
		_txt(head, Vector2(r.position.x, r.position.y + 30), 15, rc if rar != "comun" else Color(0.75, 0.6, 0.5), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if String(o["type"]) == "boon":
			var bc: Vector2 = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 135)
			var pulse2: float = 1.0 + 0.06 * sin(clock * 3.0 + float(i))
			draw_circle(bc, 56.0 * pulse2, Color(rc.r, rc.g, rc.b, 0.16))
			draw_arc(bc, 56.0 * pulse2, 0.0, TAU, 40, rc, 3.0)
			draw_boon_icon(String(o.get("icon", "")), bc, 34.0)
		elif beast:
			Art.draw_creature(self, String(o["kind"]), Vector2(r.position.x + r.size.x * 0.5, r.position.y + 190), clock, {"scale": 1.5})
		else:
			var oc: Vector2 = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 135)
			var rcol: Color = {"souls": Color(0.55, 0.85, 1.0), "door": Color(1.0, 0.75, 0.3), "essence": Color(0.75, 0.55, 1.0)}.get(String(o["type"]), Color(1.0, 0.7, 0.3))
			var pulse: float = 1.0 + 0.05 * sin(clock * 3.0 + float(i))
			draw_circle(oc, 52.0 * pulse, Color(rcol.r, rcol.g, rcol.b, 0.18))
			draw_arc(oc, 52.0 * pulse, 0.0, TAU, 40, rcol, 3.0)
			var glyph: String = "+%d" % int(o["amount"])
			if String(o["type"]) == "door":
				glyph = "+%d%%" % int(round(float(o["amount"]) * 100.0))
			_txt(glyph, Vector2(oc.x - 60, oc.y + 12), 32, rcol, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		_txt(String(o["title"]), Vector2(r.position.x, r.position.y + 238), 24, Color(1.0, 0.92, 0.75), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_multiline_string(font, Vector2(r.position.x + 20, r.position.y + 268), String(o["desc"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 40.0, 17, -1, Color(0.85, 0.8, 0.75))


const RARITY_COL: Dictionary = {"comun": Color(0.8, 0.45, 0.25), "rara": Color(0.45, 0.7, 1.0), "epica": Color(0.85, 0.5, 1.0)}
const BOON_COL: Dictionary = {"fuego": Color(1.0, 0.55, 0.2), "rayo": Color(0.7, 0.88, 1.0), "bestia": Color(1.0, 0.35, 0.3), "alma": Color(0.55, 0.9, 1.0), "puerta": Color(1.0, 0.8, 0.35)}


## Icono sencillo de un don (fuego, rayo, bestia, alma, puerta), centrado en c con radio r.
func draw_boon_icon(icon: String, c: Vector2, r: float) -> void:
	var col: Color = BOON_COL.get(icon, Color(1, 0.8, 0.5))
	match icon:
		"fuego":
			var fl: float = 0.08 * sin(clock * 9.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.55, 0.6) * r, c + Vector2(-0.6, -0.1) * r, c + Vector2(-0.2, -0.5) * r,
				c + Vector2(0.05, -1.0 - fl) * r, c + Vector2(0.35, -0.4) * r, c + Vector2(0.6, -0.05) * r, c + Vector2(0.55, 0.6) * r]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.25, 0.6) * r, c + Vector2(0.0, -0.3) * r, c + Vector2(0.25, 0.6) * r]), Color(1.0, 0.9, 0.5))
		"rayo":
			draw_polyline(PackedVector2Array([c + Vector2(0.2, -1.0) * r, c + Vector2(-0.35, 0.05) * r, c + Vector2(0.15, 0.05) * r, c + Vector2(-0.25, 1.0) * r]), col, maxf(3.0, r * 0.18))
		"bestia":
			for k in 3:
				var x: float = (-0.45 + 0.45 * k) * r
				draw_line(c + Vector2(x + 0.15 * r, -0.8 * r), c + Vector2(x - 0.15 * r, 0.8 * r), col, maxf(3.0, r * 0.16))
		"alma":
			draw_circle(c, r * 0.55, Color(col.r, col.g, col.b, 0.35))
			draw_circle(c, r * 0.32, col)
		"puerta":
			draw_rect(Rect2(c + Vector2(-0.55, -0.3) * r, Vector2(1.1, 1.1) * r), col, false, maxf(2.5, r * 0.12))
			draw_arc(c + Vector2(0, -0.3) * r, 0.55 * r, PI, TAU, 16, col, maxf(2.5, r * 0.12))
		_:
			draw_circle(c, r * 0.4, col)


## Dones de la partida: iconos pequeños arriba a la izquierda de la arena (nombre al pasar el ratón).
func _draw_boons() -> void:
	var sets: Array = sim.active_sets()
	for si in sets.size():
		var sd: Dictionary = sim.B["draft"]["sets"][String(sets[si])]
		var sp: Vector2 = Vector2(24, 140 + 22 * si)
		var col: Color = BOON_COL.get(String(sets[si]), Color(1, 0.8, 0.5))
		draw_rect(Rect2(sp + Vector2(-6, -16), Vector2(font.get_string_size("◆ " + String(sd["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12, 21)), Color(0, 0, 0, 0.55))
		_txt("◆ %s" % String(sd["name"]), sp, 15, col)
		if Rect2(sp + Vector2(0, -16), Vector2(140, 20)).has_point(mouse_pos):
			draw_rect(Rect2(sp + Vector2(-6, 6), Vector2(470, 26)), Color(0, 0, 0, 0.8))
			_txt(String(sd["desc"]), sp + Vector2(0, 24), 14, Color(0.95, 0.9, 0.85))
	for i in sim.boons.size():
		var d: Dictionary = sim.draft_def(String(sim.boons[i]))
		var c: Vector2 = Vector2(30 + 34 * i, 104)
		var rc: Color = RARITY_COL.get(String(d.get("rarity", "rara")), RARITY_COL["rara"])
		draw_circle(c, 15.0, Color(0, 0, 0, 0.65))
		draw_arc(c, 15.0, 0.0, TAU, 20, rc, 2.0)
		draw_boon_icon(String(d.get("icon", "")), c, 9.0)
		if c.distance_to(mouse_pos) < 16.0:
			var tip: String = "%s: %s" % [String(d.get("title", "")), String(d.get("desc", "")).trim_prefix("Esta partida: ")]
			draw_rect(Rect2(c + Vector2(-14, 20), Vector2(420, 26)), Color(0, 0, 0, 0.8))
			_txt(tip, c + Vector2(-8, 38), 14, Color(0.95, 0.9, 0.85))


func _draw_buttons() -> void:
	for b in _buttons():
		var id: String = String(b["id"])
		if id.begins_with("sk:") or id.begins_with("draft:"):
			continue
		if id == "route_verdugo" or id == "route_inquisidor":
			continue
		var r: Rect2 = b["rect"]
		var hov: bool = r.has_point(mouse_pos) and b["on"]
		var base: Color = Color(0.32, 0.14, 0.1) if b["on"] else Color(0.15, 0.1, 0.1)
		if id == "start":
			base = Color(0.55, 0.18, 0.08)
		if hov:
			base = base.lightened(0.25)
		draw_rect(r, base)
		if b.has("cd") and float(b["cd"]) > 0.0:
			var ch: float = r.size.y * clampf(float(b["cd"]), 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.end.y - ch, r.size.x, ch), Color(0, 0, 0, 0.55))
		var edge: Color = Color(0.8, 0.45, 0.25) if b["on"] else Color(0.3, 0.2, 0.2)
		var edge_w: float = 2.0
		if b.has("active") and bool(b["active"]):
			edge = Color(1.0, 0.9, 0.4)
			edge_w = 4.0
		draw_rect(r, edge, false, edge_w)
		var tc: Color = Color(1.0, 0.92, 0.8) if b["on"] else Color(0.5, 0.45, 0.45)
		_txt(String(b["text"]), Vector2(r.position.x, r.position.y + 32), 18, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_txt(String(b["sub"]), Vector2(r.position.x, r.position.y + 56), 15, tc.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_overlays() -> void:
	var ph: String = sim.phase
	if ph == "route":
		draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0, 0, 0, 0.72))
		_txt("¿A qué heraldo reciben tus bestias?", Vector2(0, 124), 32, Color(1.0, 0.85, 0.55), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		for key in ["verdugo", "inquisidor"]:
			var rt: Dictionary = sim.ROUTES[key]
			var rect: Rect2 = Rect2(150, 150, 480, 360) if key == "verdugo" else Rect2(650, 150, 480, 360)
			var hov: bool = rect.has_point(mouse_pos)
			draw_rect(rect, Color(0.25, 0.1, 0.08) if not hov else Color(0.38, 0.16, 0.1))
			draw_rect(rect, Color(0.85, 0.5, 0.25), false, 3.0)
			_txt(String(rt["hero_name"]), Vector2(rect.position.x, rect.position.y + 52), 34, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt("Reliquia: %s" % String(rt["relic"]), Vector2(rect.position.x, rect.position.y + 92), 20, Color(0.95, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt("Tizón se convertirá en", Vector2(rect.position.x, rect.position.y + 134), 17, Color(0.8, 0.7, 0.65), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt(String(rt["form_name"]), Vector2(rect.position.x, rect.position.y + 166), 28, Color(1.0, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			draw_multiline_string(font, Vector2(rect.position.x + 30, rect.position.y + 214), String(rt["promise"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60, 20, -1, Color(0.9, 0.85, 0.8))
			var sil: String = String(rt["form"])
			Art.draw_creature(self, sil, rect.position + Vector2(rect.size.x * 0.5 - 20, 340), clock, {"scale": 1.1})
	elif ph == "forge":
		draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0, 0, 0, 0.72))
		var r: Dictionary = sim.ROUTES[sim.route]
		var card: Rect2 = Rect2(390, 130, 500, 380)
		draw_rect(card, Color(0.22, 0.09, 0.07))
		draw_rect(card, Color(0.85, 0.5, 0.25), false, 3.0)
		_txt("Has derrotado a %s" % String(r["hero_name"]), Vector2(card.position.x, card.position.y + 44), 26, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, card.size.x)
		_txt(String(r["relic"]), Vector2(card.position.x, card.position.y + 92), 32, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, card.size.x)
		_txt("Tizón conservará su nombre y su historia.", Vector2(card.position.x, card.position.y + 130), 18, Color(0.85, 0.8, 0.75), HORIZONTAL_ALIGNMENT_CENTER, card.size.x)
		Art.draw_creature(self, "sabueso", Vector2(520, 392), clock, {"scars": int(sim.named_creature().get("scars", 0))})
		_txt("->", Vector2(600, 360), 36, Color(1.0, 0.8, 0.4))
		Art.draw_creature(self, String(r["form"]), Vector2(730, 392), clock, {"scale": 1.0})
	elif ph == "victory" or ph == "defeat":
		draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0, 0, 0, 0.78))
		var title: String = "LA PUERTA RESISTE" if ph == "victory" else "LA PUERTA CAE"
		var tcol: Color = Color(1.0, 0.85, 0.5) if ph == "victory" else Color(1.0, 0.35, 0.3)
		_txt(title, Vector2(0, 168), 56, tcol, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		var sub: String = "Has defendido las %d oleadas." % sim.wave_count() if ph == "victory" else "Cayó en la oleada %d de %d." % [sim.defeat_wave, sim.wave_count()]
		if sim.is_endless() and ph == "defeat":
			title = "LA GRIETA TE TRAGA"
			sub = "Aguantaste %d oleadas.  %s" % [sim.defeat_wave - 1, "¡Nuevo récord!" if new_record else "Récord: %d" % int(records.get(record_key(), 0))]
		elif not challenge.is_empty():
			sub += "  Reto semanal: %s" % ("¡nuevo récord!" if new_record else "récord %d/%d" % [int(records.get(record_key(), 0)), sim.wave_count()])
		_txt(sub, Vector2(0, 214), 24, Color(0.9, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		_txt("Enemigos abatidos: %d    Puerta: %d / %d" % [sim.kills, int(ceil(sim.door_hp)), int(sim.door_max)], Vector2(0, 254), 22, Color(0.8, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		var ep: String = sim.epitaph()
		if ep != "":
			_txt(ep, Vector2(0, 296), 24, Color(1.0, 0.85, 0.6), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if ph == "victory" and unlock_note != "" and sim.meta_mode:
			_txt(unlock_note, Vector2(0, 336), 22, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if not logros.fresh.is_empty():
			var names: Array = []
			for lid in logros.fresh:
				names.append(String(logros.def(String(lid)).get("name", "")))
			_txt("Logros: " + ", ".join(names), Vector2(0, 372), 18, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		# el demonio a la izquierda: victoria con los brazos en llamas o derrota de rodillas
		draw_circle(Vector2(250, 470), 120.0, Color(1.0, 0.45, 0.15, 0.14) if ph == "victory" else Color(0.6, 0.1, 0.1, 0.12))
		draw_demon_at(Vector2(250, 590), 1.25)
		var t: Dictionary = sim.named_creature()
		if not t.is_empty():
			Art.draw_creature(self, String(t["kind"]), Vector2(640, 468), clock, {"scars": int(t["scars"]), "scale": 0.85})


func _overlay_open() -> bool:
	return show_bestiary or show_tree or _draft_active() or sim.phase in ["route", "forge", "victory", "defeat"]


func _draw_bestiary() -> void:
	var rect: Rect2 = Rect2(220, 96, 840, 500)
	draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0, 0, 0, 0.6))
	draw_rect(rect, Color(0.12, 0.06, 0.06))
	draw_rect(rect, Color(0.85, 0.5, 0.25), false, 3.0)
	_txt("Bestiario", Vector2(rect.position.x + 28, rect.position.y + 44), 32, Color(1.0, 0.85, 0.55))
	_txt("(clic para cerrar)", Vector2(rect.end.x - 200, rect.position.y + 40), 15, Color(0.7, 0.6, 0.55))
	var n: int = sim.seen_forms.size()
	var rows: int = maxi(1, int(ceil(float(n) / 2.0)))
	var row: float = minf(140.0, 360.0 / float(rows))
	var bs: float = clampf(row / 110.0, 0.45, 0.9)
	for i in n:
		var fk: String = String(sim.seen_forms[i])
		var col: int = i % 2
		var cell: Vector2 = Vector2(rect.position.x + 20.0 + 410.0 * float(col), rect.position.y + 66.0 + row * float(i / 2))
		Art.draw_creature(self, fk, Vector2(cell.x + 55, cell.y + row * 0.5 + 22.0 * bs), clock, {"scale": bs})
		_txt(sim.label(fk), Vector2(cell.x + 115, cell.y + 22), 20, Color(1.0, 0.9, 0.7))
		var fsz: int = 14 if row >= 90.0 else 13
		draw_multiline_string(font, Vector2(cell.x + 115, cell.y + 40), String(FORM_INFO.get(fk, "")), HORIZONTAL_ALIGNMENT_LEFT, 285.0, fsz, maxi(1, int((row - 26.0) / float(fsz + 2))), Color(0.85, 0.8, 0.75))
	var t: Dictionary = sim.named_creature()
	if not t.is_empty():
		_txt("Tizón: %s, %d bajas, %d cicatrices." % [sim.label(String(t["kind"])), int(t["kills"]), int(t["scars"])], Vector2(rect.position.x + 28, rect.end.y - 24), 20, Color(1.0, 0.7, 0.55))


func _draw_tooltip() -> void:
	if show_bestiary or show_tree or sim.phase == "route" or sim.phase == "forge" or sim.phase == "victory" or sim.phase == "defeat":
		return
	var lines: Array = []
	var cid: int = _creature_at(mouse_pos)
	if cid >= 0:
		var c: Dictionary = sim.creature_by_id(cid)
		var nm: String = String(c["name"])
		if nm != sim.label(String(c["kind"])):
			nm += " (%s)" % sim.label(String(c["kind"]))
		lines.append("%s  Nivel %d" % [nm, int(c["level"])])
		lines.append("Vida %d / %d    Bajas %d    Cicatrices %d" % [int(c["hp"]), int(c["max_hp"]), int(c["kills"]), int(c["scars"])])
		lines.append(String(FORM_INFO.get(String(c["kind"]), "")))
	else:
		for e in sim.enemies:
			var ep: Vector2 = sim.epos(e)
			if absf(mouse_pos.x - ep.x) < 30.0 and mouse_pos.y > ep.y - 100.0 and mouse_pos.y < ep.y + 10.0:
				lines.append("%s    Vida %d / %d" % [sim.label(String(e["kind"])), int(e["hp"]), int(e["max_hp"])])
				break
	if lines.is_empty():
		return
	var w: float = 420.0
	var hs: Array = []
	var h: float = 12.0
	for ln in lines:
		var lh: float = font.get_multiline_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 16).y
		hs.append(lh)
		h += lh + 4.0
	var p: Vector2 = Vector2(minf(mouse_pos.x + 16.0, SCREEN_W - w - 8.0), maxf(mouse_pos.y - h - 12.0, 84.0))
	draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(p, Vector2(w, h)), Color(0.8, 0.45, 0.25), false, 2.0)
	var yy: float = p.y + 6.0
	for i in lines.size():
		draw_multiline_string(font, Vector2(p.x + 10, yy + 16), String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 16, -1, Color(0.95, 0.9, 0.85))
		yy += float(hs[i]) + 4.0


const META_PATH: String = "user://meta.json"


func _load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	sim.essence = int(data.get("esencia", 0))
	logros.from_save(data.get("logros_data", {}))
	sim.unlocked = logros.unlocked_boons()
	var recs: Dictionary = data.get("records", {})
	for rk in recs:
		records[String(rk)] = int(recs[rk])
	var wins: Dictionary = data.get("asedios", {})
	for k in wins:
		siege_wins[String(k)] = int(wins[k])
	var sk: Dictionary = data.get("habilidades", {})
	for id in sk:
		if sim.SK.has(id):
			sim.skills[id] = mini(int(sk[id]), int(sim.SK[id]["max"]))


func _save_meta() -> void:
	if not sim.meta_mode:
		return
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"esencia": sim.essence, "habilidades": sim.skills, "asedios": siege_wins, "records": records, "logros_data": logros.to_save()}, "  "))


## Clave del récord de la partida actual ("" si no hay récord que guardar).
func record_key() -> String:
	if not challenge.is_empty():
		return String(challenge["key"])
	if sim.is_endless():
		return "grieta"
	return ""


## Reto de la semana: misma semilla para todos durante 7 días, asedio, Ira 1 y un augurio fijo.
func weekly_challenge() -> Dictionary:
	var week: int = int(Time.get_unix_time_from_system() / 604800.0)
	var augs: Array = sim.B["augurs"]["list"]
	var sg: int = 1 if week % 2 == 1 and siege_unlocked(1) else 0
	return {"key": "reto:%d" % week, "week": week, "siege": sg, "wrath": 1, "augur": String(augs[week % augs.size()]["id"]), "seed": week * 7919 + 17}


func start_challenge() -> void:
	challenge = weekly_challenge()
	sim.set_siege(int(challenge["siege"]), int(challenge["wrath"]))
	sim.week_augur = String(challenge["augur"])
	_restart()


func start_normal(si: int, wr: int) -> void:
	challenge = {}
	sim.week_augur = ""
	sim.set_siege(si, wr)
	_restart()


## Asedio desbloqueado: el primero siempre; los demás al ganar el que piden en `unlock`.
func siege_unlocked(i: int) -> bool:
	var un: String = String(sim.SIEGES[i].get("unlock", ""))
	return un == "" or siege_wins.has(un) or not sim.meta_mode


## Ira máxima elegible en un asedio: una más que la mayor ganada.
func max_wrath(i: int) -> int:
	var id: String = String(sim.SIEGES[i]["id"])
	if sim.SIEGES[i].has("endless"):
		return mini(int(sim.B["wrath"]["max"]), int(records.get("grieta", 0)) / 8)
	if not siege_wins.has(id):
		return 0
	return mini(int(sim.B["wrath"]["max"]), int(siege_wins[id]) + 1)
