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
const FxLayer = preload("res://scripts/fx_layer.gd")

const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const Perfiles = preload("res://scripts/perfiles.gd")
var perfiles = null               # personajes (null en las pruebas sin persistencia)
var tree_from_menu: bool = false  # el árbol se abrió desde el menú: al cerrarlo se vuelve allí
var name_edit: LineEdit = null    # casilla del nombre al crear un personaje


## Archivos del personaje en uso ("" si no hay personaje o no hay persistencia).
func _pfile(file: String) -> String:
	return "" if perfiles == null else String(perfiles.path(file))


func char_name() -> String:
	return "" if perfiles == null else String(perfiles.current_name())
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
var tree_tab: String = "brasa"    # rama que se ve en el árbol
var _respec_arm: String = ""      # botón de reasignar pulsado una vez (pide confirmar)
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
var history: Array = []           # últimas partidas (resumen), se guarda en meta.json
var logros = Logros.new()
var music = Music.new()
var fx_layer = null               # efectos animados aditivos (clips de Flow sobre negro)
var toasts: Array = []            # avisos de logro: {title, desc, t}
var challenge: Dictionary = {}
var contract_note: String = ""
var tip: Dictionary = {}          # consejo de una sola vez en pantalla: {id, text, t}
const TIPS: Dictionary = {
	"encargo": "Encargo: un objetivo opcional para esta partida. Si lo cumples al ganar, te da esencia extra para el árbol.",
	"augurio": "Augurio: antes de cada oleada puedes aceptar un riesgo a cambio de un premio. O nada (Calma).",
	"don": "Los dones duran toda la partida. Dos de la misma familia despiertan una resonancia.",
	"terreno": "Este campo tiene terreno especial (abajo a la izquierda). Cambia de una partida a otra.",
	"grieta": "La Grieta no acaba: cada oleada es más dura. Aguanta todo lo que puedas para batir tu récord.",
}    # reto semanal en curso ({} si no): {key, week, siege, wrath, augur}
var unlock_note: String = ""
var branch_note: String = ""      # rama del árbol que se abre con esta victoria
var tree_refund: int = 0          # esencia devuelta al cargar un árbol guardado con nodos que ya no existen
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
		sim.contracts_enabled = true
		perfiles = Perfiles.new(String(Engine.get_meta("perfiles_root", "user://")))
		perfiles.load_all()
		menu.options_path = String(perfiles.root) + "opciones.json"
		_load_meta()
		sim.reset()
		_make_name_edit()
	sound = SoundBank.new()
	fx_layer = FxLayer.new()
	fx_layer.main = self
	add_child(fx_layer)
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
	if load_run():
		menu.started = true   # «Continuar» lleva a la partida guardada
	if perfiles != null and perfiles.current == "":
		menu.panel = "nuevo"   # primera vez: hay que crear un personaje
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
	if name_edit != null:
		var want_edit: bool = menu.open and menu.panel == "nuevo"
		if want_edit and not name_edit.visible:
			name_edit.text = ""
			name_edit.visible = true
			name_edit.grab_focus()
		elif not want_edit and name_edit.visible:
			name_edit.visible = false
			name_edit.release_focus()
	if menu.open:
		juice.update(delta)
		demon_anim.update(delta)
		queue_redraw()
		return
	if sim.phase != last_phase:
		if last_phase != "" and sim.phase != "combat":
			fade = maxf(fade, 0.45)
		last_phase = sim.phase
		if sim.phase == "prep":
			save_run()
		elif sim.phase == "victory" or sim.phase == "defeat":
			clear_run()
			_add_history()
	menu.tut_update(delta)
	_sim_dt = 0.0
	if sim.phase == "combat" and juice.hitstop <= 0.0 and not (show_tree and tree_from_menu):
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
	_update_tips(delta)
	_update_fx(delta)
	_update_fx_loops()
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
	if t in ["bought", "leveled", "placed", "draft_pick", "skill", "respec", "augur", "route_chosen"] and sim.phase == "prep":
		save_run()
	for lid in logros.on_event(sim, ev, not challenge.is_empty()):
		var ld: Dictionary = logros.def(String(lid))
		var extra: String = ""
		if ld.has("unlock"):
			sim.unlocked = logros.unlocked_boons()
			var ud: Dictionary = sim.draft_def(String(ld["unlock"]))
			extra = "Nuevo don en el draft: %s" % String(ud.get("title", "")) if not ud.is_empty() else "Nuevo augurio: %s" % String(sim.augur_def(String(ld["unlock"])).get("name", ""))
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
			fx_layer.spawn("brasa", ev["p"], float(ev["r"]) / 75.0)
			if int(ev["hits"]) >= 3:
				juice.stop(0.06)
			juice.add_trauma(0.21)
			_add_fx({"type": "ring", "p": ev["p"], "r0": 10.0, "r1": float(ev["r"]), "col": Color(1.0, 0.55, 0.2, 0.9), "ttl": 0.45})
			_add_fx({"type": "disc", "p": ev["p"], "r": float(ev["r"]), "col": Color(1.0, 0.5, 0.15, 0.35), "ttl": 0.5})
		"burn_burst":
			juice.burst(ev["p"], 14, Color(1.0, 0.6, 0.2), 200.0, 0.5, 2.5, 300.0, 80.0)
			_add_fx({"type": "ring", "p": ev["p"], "r0": 8.0, "r1": float(ev["r"]), "col": Color(1.0, 0.45, 0.15, 0.8), "ttl": 0.35})
		"respec":
			banner_text = "Árbol reasignado: +%d de esencia" % int(ev["refund"])
			banner_t = 2.0
			banner_dur = 2.0
		"rayo":
			_play("rayo")
			# el rayo sale de la mano en el fotograma de impacto del clip (si hay animación)
			var rdelay: float = Anim.impact_delay("demonio", "rayo") if demon_anim.play("rayo") else 0.0
			var rfrom: Vector2 = Anim.hand_at("demonio", "rayo", demon_feet())
			if rfrom == Vector2.INF:
				rfrom = ev["from"]
			juice.burst(ev["to"] + Vector2(0, -30), 8, Color(0.7, 0.9, 1.0), 240.0, 0.25, 2.0, 200.0)
			fx_layer.spawn("rayo", ev["to"] + Vector2(0, -30))
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
			# con el clip de Flow, el rayo de luz lo pone la capa de efectos; si no, la franja por código
			if not fx_layer.spawn_rect("juicio", Rect2(130, jy2 - 75, float(ev["x"]) - 100.0, 130)):
				_add_fx({"type": "line", "a": Vector2(150, jy2 - 10), "b": Vector2(ev["x"], jy2 - 10), "col": Color(1.0, 0.97, 0.75), "w": 40.0, "ttl": 0.35})
			flash_white = 0.35
		"set":
			var sd: Dictionary = sim.B["draft"]["sets"][String(ev["family"])]
			banner_text = "Resonancia: %s" % String(sd["name"])
			banner_t = 2.2
			banner_dur = 2.2
			flash_white = 0.3
			_play("mutate")
		"contract_done":
			contract_note = "Encargo cumplido: %s  (+%d %s)" % [String(sim.contract_def(String(ev["id"]))["name"]), int(ev["reward"]), "esencia" if sim.meta_mode else "almas"]
		"sanct_heal":
			var hp1: Vector2 = _enemy_pos(int(ev["id"]))
			if hp1.x > 0.0:
				juice.burst(hp1 + Vector2(0, -50), 2, Color(1.0, 0.92, 0.5), 60.0, 0.6, 2.0, -80.0)
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
			branch_note = ""
			var first: bool = not siege_wins.has(sid)
			if first or int(siege_wins[sid]) < sim.wrath:
				siege_wins[sid] = sim.wrath
				sim.won = siege_wins.keys()
				if sim.wrath < int(sim.B["wrath"]["max"]):
					unlock_note = "Se abre Ira %d en este asedio." % (sim.wrath + 1)
			if first:
				for sg in sim.SIEGES:
					if String(sg.get("unlock", "")) == sid:
						unlock_note = "Se abre: %s. %s" % [String(sg["name"]), unlock_note]
				for brn in sim.BRANCHES:
					if String(brn.get("unlock", "")) == sid:
						branch_note = "Rama nueva en el árbol: %s" % String(brn["name"])
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
	if not FileAccess.file_exists(_pfile("bestiario.json")):
		return
	var f: FileAccess = FileAccess.open(_pfile("bestiario.json"), FileAccess.READ)
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
	if Engine.has_meta("sin_persistencia") or _pfile("bestiario.json") == "":
		return
	var t: Dictionary = sim.named_creature()
	var rec: Dictionary = {}
	if not t.is_empty():
		rec = {"nombre": t["name"], "forma": t["kind"], "bajas": t["kills"], "cicatrices": t["scars"]}
	var data: Dictionary = {"formas": sim.seen_forms, "tizon": rec}
	var f: FileAccess = FileAccess.open(_pfile("bestiario.json"), FileAccess.WRITE)
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
			if menu.panel == "nuevo":
				return   # se está escribiendo el nombre
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
					if show_tree:
						_close_tree()
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
	if show_tree:
		_close_tree()
		_play("click")
		return
	if _draft_active():
		return
	if sim.phase == "prep" or sim.phase == "victory" or sim.phase == "defeat":
		# dentro de la partida el árbol se mira; solo se compra al terminarla (o desde el menú)
		sim.between_runs = false
		tree_from_menu = false
		show_tree = true
		_play("click")


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
	if fx_layer != null:
		fx_layer.items.clear()
	demon_anim = Anim.new("demonio")
	poses.reset()
	contract_note = ""
	clear_run()
	save_run()
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
		if not tree_from_menu and sim.phase != "prep" and sim.phase != "victory" and sim.phase != "defeat":
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
		out.append({"id": "tree", "rect": Rect2(340, y, 150, 72), "text": "Árbol (T)", "sub": ("%d rangos" if not sim.meta_mode else "ver · %d rangos") % sim.skill_points_spent(), "on": true, "active": can_any})
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
		out.append({"id": "route_verdugo", "rect": Rect2(150, 150, 480, 400), "text": "", "sub": "", "on": true})
		out.append({"id": "route_inquisidor", "rect": Rect2(650, 150, 480, 400), "text": "", "sub": "", "on": true})
	elif ph == "forge":
		out.append({"id": "forge", "rect": Rect2(490, 430, 300, 64), "text": "Entregar a Tizón", "sub": "", "on": true})
	elif ph == "victory" or ph == "defeat":
		out.append({"id": "restart", "rect": Rect2(490, 480, 300, 64), "text": "Reiniciar", "sub": "Espacio", "on": true})
		var can_end: bool = false
		for sid2 in sim.SK_ORDER:
			if sim.can_skill(sid2):
				can_end = true
				break
		out.append({"id": "tree", "rect": Rect2(490, 552, 300, 64), "text": "Subir el árbol (T)", "sub": "%d de esencia" % sim.essence, "on": true, "active": can_end})
		out.append({"id": "menu", "rect": Rect2(810, 480, 160, 64), "text": "Menú", "sub": "Esc", "on": true})
	out.append({"id": "speed", "rect": Rect2(820, y, 90, 72), "text": "Velocidad", "sub": "x%d" % speed, "on": true})
	out.append({"id": "bestiary", "rect": Rect2(920, y, 100, 72), "text": "Bestiario", "sub": "B", "on": true})
	return out


func _do_button(id: String) -> void:
	if id.begins_with("draft:"):
		sim.draft_pick(int(id.substr(6)))
		return
	var armed: String = _respec_arm
	_respec_arm = ""
	if id.begins_with("sk:"):
		if sim.buy_skill(id.substr(3)):
			_play("level")
			_save_meta()
		return
	if id.begins_with("tab:"):
		tree_tab = id.substr(4)
		_play("click")
		return
	if id.begins_with("respec:"):
		# dos clics: el primero arma el botón, el segundo reasigna
		if armed != id:
			_respec_arm = id
			_play("click")
		elif sim.respec(id.substr(7)):
			_play("mutate")
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
			_close_tree()
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
			if String(ar["kind"]) == "contract":
				sim.choose_contract("" if pick == sim.contract else pick)
			else:
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
	_draw_terrain_label()
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
	_draw_tip()
	menu.tut_draw(self)
	menu.draw(self)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))


func _draw_arena() -> void:
	var bgt: Texture2D = Art.background(String(sim.SIEGES[sim.siege_index].get("background", "fondo-fosa.jpg")))
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
	_draw_terrain()
	_draw_sanctuary()
	_draw_profane()
	_draw_demon()
	# zonas de despliegue: solo se resaltan al colocar
	if sim.phase == "prep":
		_draw_zones()
	# suelo en llamas
	for z in sim.zones:
		if z.get("terrain", false):
			continue   # la fisura se dibuja aparte (_draw_terrain)
		var zy: float = _lane_y(int(z["lane"]))
		var za: float = clampf(float(z["t"]) / 1.0, 0.0, 1.0)
		draw_rect(Rect2(float(z["x0"]), zy - 20, float(z["x1"]) - float(z["x0"]), 40), Color(1.0, 0.4, 0.1, (0.08 if FxLayer.has("llamas") else 0.25) * za))
		var n: int = int((float(z["x1"]) - float(z["x0"])) / 26.0)
		if FxLayer.has("llamas"):
			n = 0   # llamas de Flow: _draw_ground_fx
			var zw0: float = float(z["x1"]) - float(z["x0"])
			_draw_ground_fx("llamas", Rect2(float(z["x0"]) - 8.0, zy - 44.0, zw0 + 16.0, 64.0), za, float(z["x0"]) * 0.01)
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
	# suelo ardiendo de la Brasa (Tierra quemada)
	for fp in sim.fire_pools:
		var fa: float = clampf(float(fp["t"]) / 1.0, 0.0, 1.0)
		var fpp: Vector2 = fp["p"]
		var fr: float = float(fp["r"])
		draw_set_transform(arena_offset + fpp, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, fr, Color(1.0, 0.3, 0.05, 0.34 * fa))
		draw_circle(Vector2.ZERO, fr * 0.6, Color(1.0, 0.5, 0.1, 0.2 * fa))
		draw_arc(Vector2.ZERO, fr, 0.0, TAU, 32, Color(1.0, 0.6, 0.15, 0.9 * fa), 3.0)
		draw_set_transform(arena_offset, 0.0, Vector2.ONE)
		for k in 16:
			var ang: float = float(k) * 2.39996   # ángulo áureo: repartidas por todo el círculo
			var rad: float = sqrt((float(k) + 0.5) / 16.0) * 0.92
			var q: Vector2 = fpp + Vector2(cos(ang) * fr * rad, sin(ang) * fr * rad * 0.5)
			var fh: float = 20.0 + 10.0 * sin(clock * 9.0 + float(k) * 1.3)
			draw_colored_polygon(PackedVector2Array([q + Vector2(-8, 4), q + Vector2(0, 4 - fh), q + Vector2(8, 4)]), Color(1.0, 0.55, 0.15, 0.85 * fa))
			draw_colored_polygon(PackedVector2Array([q + Vector2(-4, 4), q + Vector2(0, 4 - fh * 0.55), q + Vector2(4, 4)]), Color(1.0, 0.9, 0.4, 0.8 * fa))
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


## Hoguera profana (piedra angular de la Inquisición): el santuario al revés, en verde y morado.
## En preparación se ve dónde arderá.
func _draw_profane() -> void:
	var p: Vector2 = Vector2.ZERO
	var r: float = 0.0
	if not sim.profane.is_empty():
		p = sim.profane["p"]
		r = float(sim.profane["r"])
	elif sim.phase == "prep" and sim.fadd("special.profane") > 0.0:
		var pc: Dictionary = sim.B["meta"].get("profane", {})
		p = Vector2(float(pc.get("x", 470.0)), _lane_y(1))
		r = float(pc.get("r", 120.0))
	else:
		return
	var pulse: float = 0.5 + 0.5 * sin(clock * 2.6)
	draw_set_transform(arena_offset + p, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(0.5, 0.2, 0.7, 0.10 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.55, 1.0, 0.6, 0.7), 3.0)
	draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 48, Color(0.7, 0.4, 1.0, 0.4), 2.0)
	draw_set_transform(arena_offset, 0.0, Vector2.ONE)
	for k in 5:
		var q: Vector2 = p + Vector2(-16.0 + 8.0 * float(k), 4.0)
		var fh: float = 26.0 + 12.0 * sin(clock * 8.0 + float(k) * 1.9) - absf(float(k) - 2.0) * 6.0
		draw_colored_polygon(PackedVector2Array([q + Vector2(-7, 0), q + Vector2(0, -fh), q + Vector2(7, 0)]), Color(0.5, 1.0, 0.55, 0.75))
	if sim.phase == "prep":
		_txt("HOGUERA PROFANA", p + Vector2(-80, -r * 0.5 - 10), 15, Color(0.6, 1.0, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 160.0)


## Efecto de Flow pegado al suelo (llamas, santuario): fotograma en bucle dentro de `rect`,
## con mezcla normal para que las unidades queden por delante.
func _draw_ground_fx(clip: String, rect: Rect2, alpha: float, phase: float) -> void:
	var ci: Dictionary = Anim.clip_info("efectos", clip)
	if ci.is_empty():
		return
	var i: int = int((clock + phase) * float(ci["fps"])) % int(ci["frames"])
	var tx: Texture2D = Anim.frame("efectos", clip, i)
	if tx != null:
		draw_texture_rect(tx, rect, false, Color(1, 1, 1, alpha))


## Santuario del tercer asedio: círculo dorado en el suelo con runas que giran.
func _draw_sanctuary() -> void:
	if sim.sanctuary.is_empty():
		return
	var p: Vector2 = sim.sanctuary["p"]
	var r: float = float(sim.sanctuary["r"])
	var pulse: float = 0.5 + 0.5 * sin(clock * 2.2)
	draw_set_transform(arena_offset + p, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.9, 0.5, 0.10 + 0.05 * pulse))
	if FxLayer.has("santuario"):
		# sigilo de Flow en el suelo (debajo de las unidades) y el borde exacto del área
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.88, 0.45, 0.45), 2.0)
		draw_set_transform(arena_offset, 0.0, Vector2.ONE)
		var sci: Dictionary = Anim.clip_info("efectos", "santuario")
		var ssz: Vector2 = Anim.frame("efectos", "santuario", 0).get_size()
		var sst: float = float(sci["height"]) * r / 110.0 / ssz.y
		var sanc: Vector2 = sci["anchor"]
		_draw_ground_fx("santuario", Rect2(p - sanc * sst, ssz * sst), 0.95, 0.0)
		if sim.phase == "prep":
			_txt("SANTUARIO", p + Vector2(-60, -r * 0.5 - 10), 15, Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		return
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.88, 0.45, 0.75), 3.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(1.0, 0.88, 0.45, 0.35), 2.0)
	for i in 12:
		var a: float = clock * 0.4 + TAU * float(i) / 12.0
		var q: Vector2 = Vector2(cos(a), sin(a)) * r * 0.91
		draw_line(q - Vector2(cos(a + 1.5), sin(a + 1.5)) * 6.0, q + Vector2(cos(a + 1.5), sin(a + 1.5)) * 6.0, Color(1.0, 0.95, 0.6, 0.8), 2.0)
	draw_set_transform(arena_offset, 0.0, Vector2.ONE)
	# columna de luz
	var lc: Color = Color(1.0, 0.9, 0.55, 0.07 + 0.04 * pulse)
	var lt: Color = Color(1.0, 0.9, 0.55, 0.0)
	draw_polygon(PackedVector2Array([p + Vector2(-r * 0.6, 0), p + Vector2(-r * 0.15, -170), p + Vector2(r * 0.15, -170), p + Vector2(r * 0.6, 0)]),
		PackedColorArray([lc, lt, lt, lc]))
	if sim.phase == "prep":
		_txt("SANTUARIO", p + Vector2(-60, -r * 0.5 - 10), 15, Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 120.0)


## Terreno de la partida: grieta de lava, huesos o viento, en su carril.
func _draw_terrain() -> void:
	var td: Dictionary = sim.terrain_def()
	if td.is_empty() or sim.terrain == "llano":
		return
	var ly: float = _lane_y(sim.terrain_lane)
	match sim.terrain:
		"fisura":
			var z: Dictionary = td["zone"]
			var x0: float = float(z["x0"])
			var x1: float = float(z["x1"])
			var cx: float = (x0 + x1) * 0.5
			var glow: float = 0.65 + 0.35 * sin(clock * 2.3)
			# resplandor en el suelo
			for k in 3:
				var rr: float = (x1 - x0) * (0.55 + 0.25 * k)
				draw_set_transform(arena_offset + Vector2(cx, ly), 0.0, Vector2(1.0, 0.42))
				draw_circle(Vector2.ZERO, rr, Color(1.0, 0.35, 0.05, 0.07 * glow))
			draw_set_transform(arena_offset, 0.0, Vector2.ONE)
			# grieta: polígono irregular oscuro con el núcleo de lava
			var left: PackedVector2Array = PackedVector2Array()
			var right: PackedVector2Array = PackedVector2Array()
			for k2 in 9:
				var t: float = float(k2) / 8.0
				var yy: float = ly - 34.0 + 68.0 * t
				var off: float = sin(t * 7.0 + 1.3) * 16.0 + sin(t * 17.0) * 5.0
				var wd: float = 4.0 + 9.0 * sin(t * PI)
				left.append(Vector2(cx + off - wd, yy))
				right.append(Vector2(cx + off + wd, yy))
			var crack: PackedVector2Array = left.duplicate()
			right.reverse()
			crack.append_array(right)
			draw_colored_polygon(crack, Color(0.12, 0.03, 0.02))
			var core: PackedVector2Array = PackedVector2Array()
			for k3 in left.size():
				core.append((left[k3] + crack[crack.size() - 1 - k3]) * 0.5)
			draw_polyline(core, Color(1.0, 0.5, 0.1, 0.9 * glow), 5.0)
			draw_polyline(core, Color(1.0, 0.92, 0.55, glow), 2.0)
			# ascuas que suben
			for k4 in 6:
				var ph: float = fposmod(clock * 0.6 + float(k4) * 0.17, 1.0)
				var ex: float = cx + sin(float(k4) * 2.1 + clock) * 14.0
				draw_circle(Vector2(ex, ly + 20.0 - ph * 70.0), 2.0 * (1.0 - ph) + 0.5, Color(1.0, 0.6, 0.2, 0.8 * (1.0 - ph)))
		"osario":
			for k5 in 22:
				var h1: float = fposmod(sin(float(k5) * 12.9898) * 43758.5453, 1.0)
				var h2: float = fposmod(sin(float(k5) * 78.233) * 12543.531, 1.0)
				var bx: float = 560.0 + h1 * 640.0
				var by: float = ly - 26.0 + h2 * 52.0
				var a: float = h1 * TAU
				var bone: Color = Color(0.86, 0.82, 0.72, 0.7)
				if k5 % 5 == 0:
					# calavera
					draw_circle(Vector2(bx, by - 4.0), 7.0, bone)
					draw_rect(Rect2(bx - 4.0, by + 1.0, 8.0, 5.0), bone)
					draw_circle(Vector2(bx - 2.5, by - 5.0), 1.8, Color(0.1, 0.05, 0.05))
					draw_circle(Vector2(bx + 2.5, by - 5.0), 1.8, Color(0.1, 0.05, 0.05))
				else:
					var d: Vector2 = Vector2(cos(a), sin(a) * 0.4) * 11.0
					draw_line(Vector2(bx, by) - d, Vector2(bx, by) + d, bone, 3.0)
					draw_circle(Vector2(bx, by) - d, 2.6, bone)
					draw_circle(Vector2(bx, by) + d, 2.6, bone)
		"viento":
			for k6 in 26:
				var sp: float = 120.0 + float(k6 % 5) * 40.0
				var sx: float = fposmod(float(k6) * 173.0 - clock * sp, 1300.0) - 20.0
				var sy: float = ARENA_TOP + 20.0 + float((k6 * 61) % 470) + sin(clock * 2.0 + float(k6)) * 6.0
				draw_line(Vector2(sx, sy), Vector2(sx + 40.0, sy - 3.0), Color(0.8, 0.75, 0.85, 0.28), 1.5)


func _draw_terrain_label() -> void:
	if sim.terrain == "llano" or show_tree or _overlay_open():
		return
	var td: Dictionary = sim.terrain_def()
	var p: Vector2 = Vector2(24, 592)
	var txt: String = "Terreno: %s" % String(td.get("name", ""))
	var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0
	draw_rect(Rect2(p + Vector2(-6, -15), Vector2(w, 20)), Color(0, 0, 0, 0.55))
	_txt(txt, p, 14, Color(0.95, 0.75, 0.5))
	if Rect2(p + Vector2(-6, -15), Vector2(w, 20)).has_point(mouse_pos):
		var dw: float = font.get_string_size(String(td["desc"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0
		draw_rect(Rect2(p + Vector2(-6, -44), Vector2(dw, 24)), Color(0, 0, 0, 0.85))
		_txt(String(td["desc"]), p + Vector2(0, -27), 14, Color(0.95, 0.9, 0.85))


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


## Posición de la bola de una Brasa en vuelo (Vector2.INF si aún no ha salido de la mano).
## La bola sale de la mano en el fotograma de impacto del clip y vuela el resto del retraso.
func _brasa_ball_pos(b: Dictionary) -> Vector2:
	var origin: Vector2 = Anim.hand_at("demonio", "brasa", demon_feet())
	var imp: float = Anim.impact_delay("demonio", "brasa")
	if origin == Vector2.INF:
		origin = sim.demon_pos() + Vector2(56, -34)
		imp = 0.0
	var delay: float = maxf(0.01, float(b["d"]))
	var k: float = clampf(1.0 - float(b["t"]) / delay, 0.0, 1.0)
	var since: float = delay - float(b["t"])
	if imp > 0.0 and delay > imp * 1.5:
		if since < imp:
			return Vector2.INF
		k = clampf((since - imp) / (delay - imp), 0.0, 1.0)
	return origin.lerp(b["p"], k) + Vector2(0, -sin(k * PI) * 170.0)


func _draw_brasas() -> void:
	var anim_ball: bool = FxLayer.has("bola")
	for b in sim.pending_brasas:
		var delay: float = maxf(0.01, float(b["d"]))
		var k: float = clampf(1.0 - float(b["t"]) / delay, 0.0, 1.0)
		var target: Vector2 = b["p"]
		draw_arc(target, float(b["r"]), 0.0, TAU, 36, Color(1.0, 0.45, 0.1, 0.9), 3.0)
		draw_arc(target, float(b["r"]) * (1.0 - k), 0.0, TAU, 36, Color(1.0, 0.8, 0.3, 0.7), 2.0)
		var pp: Vector2 = _brasa_ball_pos(b)
		if pp == Vector2.INF or anim_ball:
			continue   # con el clip «bola», la dibuja la capa de efectos (_update_fx_loops)
		draw_circle(pp, 11.0, Color(1.0, 0.55, 0.15))
		draw_circle(pp, 6.0, Color(1.0, 0.9, 0.5))


## Bucles de efectos de Flow (mezcla aditiva) para este fotograma: bola de la Brasa, llamas del
## suelo y santuario. Sin fotogramas no se añade nada y queda el dibujo por código.
func _update_fx_loops() -> void:
	if fx_layer == null:
		return
	fx_layer.visible = not (menu.open or show_tree or show_bestiary or _overlay_open() or intro_layer != null)
	fx_layer.clear_loops()
	if sim.phase == "combat":
		for b in sim.pending_brasas:
			var pp: Vector2 = _brasa_ball_pos(b)
			if pp != Vector2.INF:
				fx_layer.add_loop("bola", pp, float(b.get("k", 1.0)))
	# las llamas y el santuario van en el suelo, debajo de las unidades: los dibuja la arena
	# (_draw_ground_fx), con fotogramas que llevan transparencia en lugar de mezcla aditiva


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


## Consejos de una sola vez (se guardan en Opciones → tips) cuando aparece algo nuevo.
func _update_tips(delta: float) -> void:
	if not tip.is_empty():
		tip["t"] = float(tip["t"]) + delta
		if float(tip["t"]) > 7.0:
			tip = {}
		return
	if Engine.has_meta("sin_persistencia") or menu.tut_step >= 0 or sim.phase != "prep":
		return
	var seen: Array = menu.opts.get("tips", [])
	var want: String = ""
	if sim.is_endless() and sim.wave_index == 0:
		want = "grieta"
	elif sim.wave_index == 0 and not sim.contract_offer.is_empty():
		want = "encargo"
	elif not sim.augur_offer.is_empty():
		want = "augurio"
	elif _draft_active() and sim.draft.any(func(o): return String(o["type"]) == "boon"):
		want = "don"
	elif sim.terrain != "llano":
		want = "terreno"
	if want != "" and not seen.has(want):
		seen.append(want)
		menu.opts["tips"] = seen
		menu.save_options()
		tip = {"id": want, "text": TIPS[want], "t": 0.0}


func _draw_tip() -> void:
	if tip.is_empty():
		return
	var t: float = float(tip["t"])
	var a: float = clampf(minf(t / 0.3, (7.0 - t) / 0.6), 0.0, 1.0)
	var txt: String = String(tip["text"])
	var w: float = minf(900.0, font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0)
	var r: Rect2 = Rect2(SCREEN_W * 0.5 - w * 0.5, 548, w, 44)
	draw_rect(r, Color(0.05, 0.03, 0.08, 0.9 * a))
	draw_rect(r, Color(0.85, 0.65, 1.0, a), false, 2.0)
	_txt(txt, r.position + Vector2(0, 28), 16, Color(0.95, 0.9, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


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
	if char_name() != "":
		sg_txt = char_name() + "  ·  " + sg_txt
	if sim.is_endless():
		sg_txt += "  ·  récord %d" % int(records.get("grieta", 0))
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
		# la nota no debe meterse bajo la barra de la Puerta (x 900): letra más pequeña si no cabe
		var nfs: int = 17
		while nfs > 12 and font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > 645.0:
			nfs -= 1
		_txt(note, Vector2(240, 62), nfs, Color(0.8, 0.7, 0.65))
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
		_txt("Arrastra bestias a las zonas marcadas: vanguardia hace de muro, retaguardia dispara. Selecciona una para subirla de nivel. Las almas que te sobren al acabar suben el árbol (T para verlo).", Vector2(20, 618), 14, Color(0.75, 0.65, 0.6))
	elif sim.phase == "combat":
		var left: int = sim.spawn_queue.size() + sim.enemies.size()
		_txt("Quedan %d enemigos." % left, Vector2(340, 646), 17, Color(0.95, 0.85, 0.7))
		if sim.augur != "":
			_txt("Augurio: %s" % String(sim.augur_def(sim.augur).get("name", "")), Vector2(560, 646), 15, Color(0.85, 0.65, 1.0))
		if sim.contract != "":
			var cst: String = sim.contract_status()
			_txt("Encargo: %s%s" % [String(sim.contract_def(sim.contract)["name"]), "  (fallido)" if cst == "fail" else ""], Vector2(560, 672), 14, Color(1.0, 0.5, 0.4) if cst == "fail" else Color(1.0, 0.75, 0.4))
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
	if sim.phase != "prep" or show_tree or _draft_active():
		return out
	var offer: Array = sim.augur_offer
	var kind: String = "augur"
	if sim.wave_index == 0 and not sim.contract_offer.is_empty():
		offer = sim.contract_offer
		kind = "contract"
	if offer.is_empty():
		return out
	var rows: int = sim.preview_totals(sim.wave_index).size() + 1   # fila de reserva: Campeón añade una línea sin mover las tarjetas
	var y: float = 98.0 + 44.0 + 20.0 * float(rows) + 52.0
	for id in offer:
		out.append({"id": String(id), "rect": Rect2(1040, y, 232, 78), "kind": kind})
		y += 84.0
	return out


func _draw_augurs() -> void:
	var rects: Array = _augur_rects()
	if rects.is_empty():
		return
	var top: Vector2 = rects[0]["rect"].position
	var is_c: bool = String(rects[0]["kind"]) == "contract"
	_txt("ENCARGO (opcional)" if is_c else "AUGURIO (opcional)", top + Vector2(10, -8), 15, Color(1.0, 0.75, 0.4) if is_c else Color(0.85, 0.6, 1.0))
	for ar in rects:
		var r: Rect2 = ar["rect"]
		var a: Dictionary = sim.contract_def(String(ar["id"])) if is_c else sim.augur_def(String(ar["id"]))
		if is_c:
			a = a.duplicate()
			a["desc"] = "%s  Premio: +%d %s." % [String(a["desc"]), int(a["reward"]), "esencia" if sim.meta_mode else "almas"]
		var on: bool = (sim.contract if is_c else sim.augur) == String(ar["id"])
		var hov: bool = r.has_point(mouse_pos)
		var fill_on: Color = Color(0.3, 0.14, 0.04, 0.9) if is_c else Color(0.22, 0.08, 0.28, 0.9)
		var edge: Color = Color(0.7, 0.42, 0.2) if is_c else Color(0.55, 0.3, 0.65)
		draw_rect(r, fill_on if on else Color(0.06, 0.02, 0.04, 0.82 if hov else 0.7))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else edge, false, 3.0 if on else 2.0)
		_txt(String(a.get("name", "")), r.position + Vector2(10, 20), 16, Color(1.0, 0.85, 0.5) if on else Color(0.92, 0.8, 1.0))
		draw_multiline_string(font, r.position + Vector2(10, 38), String(a.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 13, 3, Color(0.85, 0.8, 0.85))
	var last: Rect2 = rects[-1]["rect"]
	var chosen: String = sim.contract if is_c else sim.augur
	var cname: String = String((sim.contract_def(chosen) if is_c else sim.augur_def(chosen)).get("name", ""))
	_txt("Elegido: %s" % cname if chosen != "" else ("Sin encargo" if is_c else "Sin elegir: Calma"), Vector2(last.position.x + 10, last.end.y + 16), 13, Color(0.75, 0.65, 0.8))


# --- Árbol de habilidades ---------------------------------------------------------
# Pestañas por rama a la izquierda, el árbol de la rama elegida en el centro (dos columnas y una
# lateral para la piedra angular y los nodos de dones) y un panel de detalle a la derecha.

const TREE_TAB_X: float = 16.0
const TREE_TAB_W: float = 190.0
const TREE_TAB_Y0: float = 90.0
const TREE_TAB_DY: float = 51.0
const TREE_TAB_H: float = 45.0
const TREE_COL_A: float = 232.0
const TREE_COL_B: float = 440.0
const TREE_COL_MID: float = 336.0
const TREE_COL_SIDE: float = 660.0
const TREE_Y0: float = 140.0
const TREE_DY: float = 76.0
const TREE_W: float = 196.0
const TREE_H: float = 52.0
const TREE_PANEL: Rect2 = Rect2(872, 90, 392, 506)


func _build_tree_pos() -> void:
	_tree_pos.clear()
	for br in sim.BRANCHES:
		var rows: Dictionary = {}
		for id in sim.SK_ORDER:
			var nd: Dictionary = sim.SK[id]
			if nd["branch"] != br["id"]:
				continue
			var y: float = TREE_Y0 + float(int(nd["row"])) * TREE_DY
			if bool(nd.get("side", false)):
				_tree_pos[id] = Rect2(TREE_COL_SIDE, y, TREE_W, TREE_H)
			else:
				if not rows.has(int(nd["row"])):
					rows[int(nd["row"])] = []
				rows[int(nd["row"])].append(id)
		for rw in rows:
			var ids: Array = rows[rw]
			# el padre de un nodo lateral va a la derecha: su línea no pasa por detrás de otro nodo
			if ids.size() == 2 and _feeds_side(String(ids[0])) and not _feeds_side(String(ids[1])):
				ids.reverse()
			var y2: float = TREE_Y0 + float(rw) * TREE_DY
			if ids.size() == 1:
				_tree_pos[ids[0]] = Rect2(TREE_COL_MID, y2, TREE_W, TREE_H)
			else:
				for i in ids.size():
					_tree_pos[ids[i]] = Rect2(TREE_COL_A + float(i) * (TREE_COL_B - TREE_COL_A), y2, TREE_W, TREE_H)


func _feeds_side(id: String) -> bool:
	for o in sim.SK_ORDER:
		if bool(sim.SK[o].get("side", false)):
			for rq in sim.SK[o]["req"]:
				if String(rq["id"]) == id:
					return true
	return false


func _node_rect(id: String) -> Rect2:
	if _tree_pos.is_empty():
		_build_tree_pos()
	return _tree_pos[id]


func _tab_rect(i: int) -> Rect2:
	return Rect2(TREE_TAB_X, TREE_TAB_Y0 + float(i) * TREE_TAB_DY, TREE_TAB_W, TREE_TAB_H)


func _respec_rect(all: bool) -> Rect2:
	return Rect2(TREE_PANEL.position.x + 12.0, TREE_PANEL.end.y - (46.0 if all else 92.0), TREE_PANEL.size.x - 24.0, 40.0)


func _tab_ids() -> Array:
	var out: Array = []
	for id in sim.SK_ORDER:
		if sim.SK[id]["branch"] == tree_tab:
			out.append(id)
	return out


func _tree_buttons() -> Array:
	var out: Array = []
	for i in sim.BRANCHES.size():
		out.append({"id": "tab:" + String(sim.BRANCHES[i]["id"]), "rect": _tab_rect(i), "text": "", "sub": "", "on": true})
	for id in _tab_ids():
		out.append({"id": "sk:" + id, "rect": _node_rect(id), "text": "", "sub": "", "on": sim.can_skill(id)})
	if sim.meta_mode:
		out.append({"id": "respec:" + tree_tab, "rect": _respec_rect(false), "text": "", "sub": "", "on": sim.can_respec(tree_tab)})
		out.append({"id": "respec:", "rect": _respec_rect(true), "text": "", "sub": "", "on": sim.can_respec("")})
	out.append({"id": "tree_close", "rect": Rect2(490, 624, 300, 72), "text": "Cerrar árbol", "sub": "T / Esc", "on": true})
	return out


func _branch_color(id: String) -> Color:
	for b in sim.BRANCHES:
		if b["id"] == id:
			return Color.html(String(b["color"]))
	return Color.WHITE


func _branch_ranks(bid: String) -> int:
	var n: int = 0
	for id in sim.skills:
		if sim.SK.has(id) and sim.SK[id]["branch"] == bid:
			n += int(sim.skills[id])
	return n


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _draw_tree() -> void:
	if not show_tree:
		return
	draw_rect(Rect2(0, 78, SCREEN_W, 526), Color(0.03, 0.01, 0.03, 0.95))
	draw_rect(Rect2(0, 606, SCREEN_W, 30), Color(0.05, 0.02, 0.03))
	_txt("ÁRBOL DE HABILIDADES", Vector2(24, 666), 24, Color(1.0, 0.85, 0.55))
	_txt("%d esencia" % sim.currency() if sim.meta_mode else "%d almas" % sim.currency(), Vector2(1000, 666), 26, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 256.0)
	if sim.meta_mode:
		var infl: float = float(sim.B["meta"].get("inflation", 0.0)) * float(sim.skill_points_spent())
		_txt("%d rangos · cada rango encarece los demás un %s%% (ahora +%d%%)" % [sim.skill_points_spent(), String.num(float(sim.B["meta"].get("inflation", 0.0)) * 100.0, 1).replace(".", ","), int(round(infl * 100.0))], Vector2(24, 694), 13, Color(0.7, 0.65, 0.75))
	if sim.meta_mode and not sim.tree_shop_open():
		var why: String = "Las mejoras se compran al terminar la partida, con las almas que te queden."
		if tree_from_menu:
			why = "Tienes una partida a medias: las mejoras se compran al terminarla, con las almas que te queden."
		_txt(why, Vector2(0, 621), 14, Color(1.0, 0.82, 0.35), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
	elif sim.meta_mode and sim.phase == "prep":
		_txt("Entre partidas: gasta la esencia ahorrada antes de empezar.", Vector2(0, 621), 14, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
	_draw_tree_tabs()
	var br: Dictionary = sim.branch_def(tree_tab)
	var bc: Color = _branch_color(tree_tab)
	var open: bool = sim.branch_open(tree_tab)
	var title: String = String(br["name"])
	if String(br["route"]) != "":
		title += "  (ruta de %s)" % String(sim.ROUTES[String(br["route"])]["hero_name"])
	_txt(title, Vector2(TREE_COL_A, 118), 22, bc)
	if not open:
		_txt("SELLADA · " + String(br.get("unlock_text", "")), Vector2(TREE_COL_A + 120.0, 117), 15, Color(1.0, 0.75, 0.4))
	var ids: Array = _tab_ids()
	# líneas de requisito
	for id in ids:
		var nd: Dictionary = sim.SK[id]
		var rc: Rect2 = _node_rect(id)
		for rq in nd["req"]:
			var pr: Rect2 = _node_rect(String(rq["id"]))
			var met: bool = sim.skill_rank(String(rq["id"])) >= int(rq["rank"])
			var lc: Color = bc
			lc.a = 0.7 if met else 0.22
			var p0: Vector2 = Vector2(pr.get_center().x, pr.end.y)
			var p1: Vector2 = Vector2(rc.get_center().x, rc.position.y)
			if bool(nd.get("side", false)):
				p0 = Vector2(pr.end.x, pr.get_center().y)
				p1 = Vector2(rc.position.x, rc.get_center().y)
			elif pr.position.y >= rc.position.y:
				p0 = pr.get_center()
				p1 = rc.get_center()
			draw_line(p0, p1, lc, 2.0 if met else 1.5)
	var hov_id: String = ""
	for id in ids:
		var nd2: Dictionary = sim.SK[id]
		var r: Rect2 = _node_rect(id)
		var st: String = sim.skill_state(id)
		var fill: Color = Color(0.12, 0.07, 0.09)
		var edge: Color = bc.darkened(0.55)
		var tc: Color = Color(0.5, 0.45, 0.45)
		match st:
			"max":
				fill = bc.darkened(0.55)
				edge = bc
				tc = Color(1, 1, 1)
			"ok":
				fill = Color(0.2, 0.11, 0.1)
				edge = bc
				tc = Color(1.0, 0.95, 0.85)
			"poor":
				fill = Color(0.16, 0.09, 0.09)
				edge = bc.darkened(0.25)
				tc = Color(0.75, 0.68, 0.65)
			"excluded", "sealed":
				fill = Color(0.07, 0.05, 0.06)
				edge = Color(0.28, 0.22, 0.22)
				tc = Color(0.42, 0.38, 0.38)
		if skill_rank_pos(id):
			fill = fill.lerp(bc.darkened(0.5), 0.5)
		var hov: bool = r.has_point(mouse_pos)
		if hov:
			hov_id = id
			fill = fill.lightened(0.18)
		var key: bool = bool(nd2.get("keystone", false))
		if key:
			var gold: Color = Color(1.0, 0.82, 0.35, 1.0 if st != "sealed" and st != "locked" else 0.45)
			draw_rect(r.grow(4.0), gold, false, 2.0)
			_txt("PIEDRA ANGULAR", Vector2(r.position.x, r.position.y - 9), 11, gold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		elif bool(nd2.get("boon", false)) and bool(nd2.get("side", false)):
			_txt("HABLA CON LOS DONES", Vector2(r.position.x, r.position.y - 9), 11, Color(0.75, 0.6, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 2.0 if st != "ok" else 3.0)
		_txt(String(nd2["name"]), Vector2(r.position.x + 6, r.position.y + 20), 14, tc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (30.0 if key else 12.0))
		if key:
			_diamond(Vector2(r.end.x - 16, r.position.y + 16), 7.0, Color(1.0, 0.82, 0.35) if skill_rank_pos(id) else Color(0.5, 0.42, 0.25))
		var rank_txt: String = "%d/%d" % [sim.skill_rank(id), int(nd2["max"])]
		var cost: int = sim.skill_cost(id)
		var sub: String = rank_txt + ("   máx" if cost < 0 else "   %d %s" % [cost, "esencia" if sim.meta_mode else "almas"])
		match st:
			"route":
				sub = rank_txt + "   (ruta)"
			"excluded":
				sub = "camino cerrado"
			"sealed":
				sub = "rama sellada"
		_txt(sub, Vector2(r.position.x + 6, r.position.y + 42), 12, tc.darkened(0.1), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0)
		if st == "excluded":
			draw_line(r.position + Vector2(6, r.size.y - 6), Vector2(r.end.x - 6, r.position.y + 6), Color(0.6, 0.25, 0.2, 0.7), 2.0)
		# pareja excluyente: rótulo entre los dos
		if nd2.has("excl") and String(id) < String(nd2["excl"]):
			var o: Rect2 = _node_rect(String(nd2["excl"]))
			var x0: float = minf(r.position.x, o.position.x)
			var x1: float = maxf(r.end.x, o.end.x)
			var chosen: bool = skill_rank_pos(id) or skill_rank_pos(String(nd2["excl"]))
			var lab: String = "CAMINO ELEGIDO" if chosen else "ELIGE UN CAMINO: EL OTRO SE CIERRA"
			var lw: float = font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
			draw_rect(Rect2((x0 + x1) * 0.5 - lw * 0.5, r.position.y - 19, lw, 15), Color(0.03, 0.01, 0.03))
			_txt(lab, Vector2(x0, r.position.y - 8), 11, Color(1.0, 0.6, 0.45), HORIZONTAL_ALIGNMENT_CENTER, x1 - x0)
	_draw_tree_panel(hov_id)


func _draw_tree_tabs() -> void:
	for i in sim.BRANCHES.size():
		var b: Dictionary = sim.BRANCHES[i]
		var bid: String = String(b["id"])
		var r: Rect2 = _tab_rect(i)
		var bc: Color = _branch_color(bid)
		var open: bool = sim.branch_open(bid)
		var sel: bool = bid == tree_tab
		var fill: Color = Color(0.2, 0.1, 0.1) if sel else Color(0.1, 0.06, 0.08)
		if r.has_point(mouse_pos):
			fill = fill.lightened(0.12)
		draw_rect(r, fill)
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), bc if open else bc.darkened(0.6))
		draw_rect(r, bc if sel else Color(0.3, 0.2, 0.22), false, 3.0 if sel else 1.0)
		_txt(String(b["name"]), Vector2(r.position.x + 14, r.position.y + 20), 16, bc if open else Color(0.5, 0.45, 0.45), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44.0)
		var sub: String = "%d rangos" % _branch_ranks(bid)
		if not open:
			sub = "sellada"
		elif String(b["route"]) != "":
			sub += " · ruta"
		_txt(sub, Vector2(r.position.x + 14, r.position.y + 38), 12, Color(0.7, 0.65, 0.65), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44.0)
		# marcas: piedra angular comprada y nodos que se pueden comprar ahora
		var can: bool = false
		var key: bool = false
		for id in sim.SK_ORDER:
			if sim.SK[id]["branch"] != bid:
				continue
			if sim.can_skill(id):
				can = true
			if bool(sim.SK[id].get("keystone", false)) and sim.skill_rank(id) > 0:
				key = true
		if key:
			_diamond(Vector2(r.end.x - 34, r.get_center().y), 7.0, Color(1.0, 0.82, 0.35))
		if can:
			draw_circle(Vector2(r.end.x - 14, r.get_center().y), 5.0, Color(0.6, 1.0, 0.6))
		elif not open:
			# candado
			var lp: Vector2 = Vector2(r.end.x - 20, r.get_center().y)
			draw_arc(lp + Vector2(0, -3), 5.0, PI, TAU, 10, Color(0.6, 0.55, 0.5), 2.0)
			draw_rect(Rect2(lp + Vector2(-7, -3), Vector2(14, 11)), Color(0.6, 0.55, 0.5))


func _panel_text(text: String, y: float, size: int, col: Color) -> float:
	var w: float = TREE_PANEL.size.x - 28.0
	draw_multiline_string(font, Vector2(TREE_PANEL.position.x + 14, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, col)
	return y + font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y + 8.0


func _draw_tree_panel(hov_id: String) -> void:
	var bc: Color = _branch_color(tree_tab)
	draw_rect(TREE_PANEL, Color(0.07, 0.04, 0.06))
	draw_rect(TREE_PANEL, bc.darkened(0.4), false, 2.0)
	var y: float = TREE_PANEL.position.y + 12.0
	var cur: String = "esencia" if sim.meta_mode else "almas"
	if hov_id != "":
		var nd: Dictionary = sim.SK[hov_id]
		y = _panel_text(String(nd["name"]), y, 22, Color(1.0, 0.9, 0.6))
		var tags: Array = ["rango %d / %d" % [sim.skill_rank(hov_id), int(nd["max"])]]
		if bool(nd.get("keystone", false)):
			tags.append("piedra angular")
		if nd.has("excl"):
			tags.append("camino excluyente")
		if bool(nd.get("boon", false)):
			tags.append("habla con los dones")
		y = _panel_text(" · ".join(tags), y, 13, bc)
		y = _panel_text(String(nd["desc"]), y + 4.0, 17, Color(0.94, 0.9, 0.86))
		if nd.has("excl"):
			y = _panel_text("Comprarlo cierra el otro camino: %s." % String(sim.SK[String(nd["excl"])]["name"]), y, 14, Color(1.0, 0.6, 0.45))
		y += 6.0
		match sim.skill_state(hov_id):
			"locked":
				var need: Array = []
				for rq in nd["req"]:
					if sim.skill_rank(String(rq["id"])) < int(rq["rank"]):
						need.append("%s %d" % [String(sim.SK[rq["id"]]["name"]), int(rq["rank"])])
				y = _panel_text("Requiere: " + ", ".join(need), y, 15, Color(0.85, 0.7, 0.6))
			"route":
				y = _panel_text("Se abre al elegir esta ruta.", y, 15, Color(0.85, 0.7, 0.6))
			"sealed":
				y = _panel_text("Rama sellada. %s." % String(sim.branch_def(tree_tab).get("unlock_text", "")), y, 15, Color(1.0, 0.75, 0.4))
			"excluded":
				y = _panel_text("Camino cerrado: elegiste %s. Reasigna la rama para cambiar." % String(sim.SK[String(nd["excl"])]["name"]), y, 15, Color(1.0, 0.55, 0.45))
			"poor":
				y = _panel_text("Cuesta %d %s (te faltan %d)." % [sim.skill_cost(hov_id), cur, sim.skill_cost(hov_id) - sim.currency()], y, 15, Color(0.85, 0.7, 0.6))
			"ok":
				y = _panel_text("Clic para comprar: %d %s." % [sim.skill_cost(hov_id), cur], y, 15, Color(0.6, 1.0, 0.6))
			"max":
				y = _panel_text("Al máximo.", y, 15, Color(0.8, 0.8, 0.8))
	else:
		var br: Dictionary = sim.branch_def(tree_tab)
		y = _panel_text(String(br["name"]), y, 22, bc)
		if not sim.branch_open(tree_tab):
			y = _panel_text("Rama sellada. %s." % String(br.get("unlock_text", "")), y, 16, Color(1.0, 0.75, 0.4))
		else:
			y = _panel_text("%d rangos · %d %s invertida" % [_branch_ranks(tree_tab), sim.paid_total(tree_tab), cur], y, 14, Color(0.8, 0.75, 0.75))
		y = _panel_text("Tu build", y + 6.0, 16, Color(1.0, 0.9, 0.6))
		var keys: Array = []
		var paths: Array = []
		for id in sim.SK_ORDER:
			if sim.skill_rank(id) <= 0:
				continue
			if bool(sim.SK[id].get("keystone", false)):
				keys.append(String(sim.SK[id]["name"]))
			elif sim.SK[id].has("excl"):
				paths.append(String(sim.SK[id]["name"]))
		y = _panel_text("Piedras angulares: " + (", ".join(keys) if not keys.is_empty() else "ninguna todavía"), y, 14, Color(1.0, 0.82, 0.35))
		y = _panel_text("Caminos: " + (", ".join(paths) if not paths.is_empty() else "sin elegir"), y, 14, Color(1.0, 0.6, 0.45))
		y = _panel_text("La piedra angular de cada rama cambia una regla y pide algo a cambio. Al final de la rama se elige un camino y el otro se cierra.", y + 6.0, 13, Color(0.7, 0.65, 0.7))
	if not sim.meta_mode:
		return
	# reasignar
	var pct: int = int(round(float(sim.B["meta"].get("respec_refund", 0.75)) * 100.0))
	var note: String = "Reasignar devuelve el %d%% de lo pagado." % pct
	if sim.paid_total("") > 0 and not sim.can_respec(""):
		note = "Reasignar: solo entre partidas (desde el menú o al acabar)."
	_txt(note, Vector2(TREE_PANEL.position.x + 14, _respec_rect(false).position.y - 8), 12, Color(0.7, 0.65, 0.7), HORIZONTAL_ALIGNMENT_LEFT, TREE_PANEL.size.x - 28.0)
	for all in [false, true]:
		var r: Rect2 = _respec_rect(all)
		var rid: String = "respec:" + ("" if all else tree_tab)
		var on: bool = sim.can_respec("" if all else tree_tab)
		var armed: bool = _respec_arm == rid
		var fill: Color = Color(0.45, 0.12, 0.08) if armed else (Color(0.22, 0.12, 0.14) if on else Color(0.1, 0.07, 0.08))
		if on and r.has_point(mouse_pos):
			fill = fill.lightened(0.15)
		draw_rect(r, fill)
		draw_rect(r, Color(1.0, 0.6, 0.4) if armed else (Color(0.7, 0.45, 0.4) if on else Color(0.3, 0.22, 0.22)), false, 2.0)
		var lab: String = "Reasignar todo el árbol" if all else "Reasignar esta rama"
		var back: int = sim.respec_refund("" if all else tree_tab)
		if armed:
			lab = "¿Seguro? Clic otra vez: +%d %s" % [back, cur]
		elif back > 0:
			lab += "  (+%d)" % back
		_txt(lab, Vector2(r.position.x, r.position.y + 26), 15, Color(1.0, 0.92, 0.8) if on else Color(0.5, 0.45, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func skill_rank_pos(id: String) -> bool:
	return sim.skill_rank(id) > 0


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
		if id.begins_with("sk:") or id.begins_with("draft:") or id.begins_with("tab:") or id.begins_with("respec:"):
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
			var rect: Rect2 = Rect2(150, 150, 480, 400) if key == "verdugo" else Rect2(650, 150, 480, 400)
			var hov: bool = rect.has_point(mouse_pos)
			draw_rect(rect, Color(0.25, 0.1, 0.08) if not hov else Color(0.38, 0.16, 0.1))
			draw_rect(rect, Color(0.85, 0.5, 0.25), false, 3.0)
			_txt(String(rt["hero_name"]), Vector2(rect.position.x, rect.position.y + 52), 34, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt("Reliquia: %s" % String(rt["relic"]), Vector2(rect.position.x, rect.position.y + 92), 20, Color(0.95, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt("Tizón se convertirá en", Vector2(rect.position.x, rect.position.y + 134), 17, Color(0.8, 0.7, 0.65), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			_txt(String(rt["form_name"]), Vector2(rect.position.x, rect.position.y + 166), 28, Color(1.0, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			draw_multiline_string(font, Vector2(rect.position.x + 30, rect.position.y + 214), String(rt["promise"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60, 20, -1, Color(0.9, 0.85, 0.8))
			var sil: String = String(rt["form"])
			Art.draw_creature(self, sil, rect.position + Vector2(rect.size.x * 0.5 - 20, 385), clock, {"scale": 0.9})
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
		if char_name() != "":
			sub = "%s: %s" % [char_name(), sub.substr(0, 1).to_lower() + sub.substr(1)]
		_txt(sub, Vector2(0, 214), 24, Color(0.9, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		_txt("Enemigos abatidos: %d    Puerta: %d / %d" % [sim.kills, int(ceil(sim.door_hp)), int(sim.door_max)], Vector2(0, 254), 22, Color(0.8, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		_txt(_run_stats_line(), Vector2(0, 462), 14, Color(0.7, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		# las almas que sobraron pasan al árbol
		if sim.meta_mode:
			var bank: String = "No te sobraron almas: esta vez el árbol no sube."
			if not sim.banked.is_empty():
				bank = "Te quedan %d almas:  +%d de esencia para el árbol" % [int(sim.banked["souls"]), int(sim.banked["essence"])]
			_txt(bank, Vector2(0, 438), 19, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		var ep: String = sim.epitaph()
		if ep != "":
			_txt(ep, Vector2(0, 296), 24, Color(1.0, 0.85, 0.6), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if ph == "victory" and unlock_note != "" and sim.meta_mode:
			_txt(unlock_note, Vector2(0, 332), 22, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if ph == "victory" and branch_note != "" and sim.meta_mode:
			_txt(branch_note, Vector2(0, 358), 19, Color(1.0, 0.82, 0.35), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if contract_note != "" and ph == "victory":
			_txt(contract_note, Vector2(0, 410), 18, Color(1.0, 0.75, 0.4), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		if not logros.fresh.is_empty():
			var names: Array = []
			for lid in logros.fresh:
				names.append(String(logros.def(String(lid)).get("name", "")))
			_txt("Logros: " + ", ".join(names), Vector2(0, 384), 18, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W)
		# el demonio a la izquierda: victoria con los brazos en llamas o derrota de rodillas
		draw_circle(Vector2(250, 470), 120.0, Color(1.0, 0.45, 0.15, 0.14) if ph == "victory" else Color(0.6, 0.1, 0.1, 0.12))
		draw_demon_at(Vector2(250, 590), 1.25)
		var t: Dictionary = sim.named_creature()
		if not t.is_empty():
			# Tizón a la derecha, frente al demonio
			draw_circle(Vector2(1090, 500), 100.0, Color(1.0, 0.5, 0.2, 0.07))
			Art.draw_creature(self, String(t["kind"]), Vector2(1090, 570), clock, {"scars": int(t["scars"]), "scale": 1.3})
			_txt(String(t["name"]), Vector2(990, 596), 18, Color(1.0, 0.85, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 200.0)


## Estadísticas de la partida para la pantalla final.
func _run_stats_line() -> String:
	var best: Dictionary = {}
	for c in sim.creatures:
		if best.is_empty() or int(c["kills"]) > int(best["kills"]):
			best = c
	var parts: Array = []
	if not best.is_empty() and int(best["kills"]) > 0:
		var nm: String = String(best["name"]) if best["named"] else sim.label(String(best["kind"]))
		parts.append("Mejor bestia: %s (%d bajas)" % [nm, int(best["kills"])])
	parts.append("Mejor Brasa: %d" % int(logros.run.get("brasa_best", 0)))
	parts.append("Dones: %d" % sim.boons.size())
	parts.append("Augurios: %d" % int(logros.run.get("augurs", 0)))
	if sim.terrain != "llano":
		parts.append(String(sim.terrain_def().get("name", "")))
	return "   ·   ".join(parts)


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




func _load_meta() -> void:
	if not FileAccess.file_exists(_pfile("meta.json")):
		return
	var f: FileAccess = FileAccess.open(_pfile("meta.json"), FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	sim.essence = int(data.get("esencia", 0))
	logros.from_save(data.get("logros_data", {}))
	sim.unlocked = logros.unlocked_boons()
	history = data.get("historial", [])
	var recs: Dictionary = data.get("records", {})
	for rk in recs:
		records[String(rk)] = int(recs[rk])
	var wins: Dictionary = data.get("asedios", {})
	for k in wins:
		siege_wins[String(k)] = int(wins[k])
	sim.won = siege_wins.keys()
	# nodos retirados o recortados devuelven su esencia (migración de «Árbol 2»)
	tree_refund = sim.load_tree(data.get("habilidades", {}), data.get("pagado", {}))
	if tree_refund > 0 or not data.has("pagado"):
		_save_meta()


func _save_meta() -> void:
	if not sim.meta_mode or _pfile("meta.json") == "":
		return
	var f: FileAccess = FileAccess.open(_pfile("meta.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"esencia": sim.essence, "habilidades": sim.skills, "pagado": sim.skill_paid, "asedios": siege_wins, "records": records, "logros_data": logros.to_save(), "historial": history}, "  "))


## Guarda la partida a medias (solo en preparación). Se recupera con «Continuar» al volver.
func save_run() -> void:
	if Engine.has_meta("sin_persistencia") or not sim.meta_mode or _pfile("partida.txt") == "":
		return
	var d: Dictionary = sim.run_save()
	if d.is_empty():
		return
	d["challenge"] = challenge
	d["logros_run"] = logros.run
	var f: FileAccess = FileAccess.open(_pfile("partida.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(d))


func _add_history() -> void:
	var mode: String = sim.siege_name().get_slice(":", 0)
	if not challenge.is_empty():
		mode = "Reto semanal"
	if sim.wrath > 0:
		mode += " · Ira %d" % sim.wrath
	var names: Array = []
	for b in sim.boons:
		names.append(String(sim.draft_def(String(b)).get("title", "")))
	var res: String = "Victoria" if sim.phase == "victory" else ("%d oleadas" % (sim.defeat_wave - 1) if sim.is_endless() else "Cae en la %d" % sim.defeat_wave)
	var entry: Dictionary = {"fecha": Time.get_date_string_from_system(), "modo": mode, "resultado": res,
		"terreno": String(sim.terrain_def().get("name", "")), "dones": names, "ruta": sim.route, "bajas": sim.kills,
		"encargo": "" if sim.contract == "" else "%s %s" % [String(sim.contract_def(sim.contract).get("name", "")), "✓" if sim.phase == "victory" and sim.contract_status() == "ok" else "✗"]}
	history.push_front(entry)
	while history.size() > 12:
		history.pop_back()
	_save_meta()


func clear_run() -> void:
	if _pfile("partida.txt") != "" and FileAccess.file_exists(_pfile("partida.txt")):
		DirAccess.remove_absolute(_pfile("partida.txt"))


# ----------------------------------------------------------------------------
# Personajes: cada uno con su árbol, sus asedios, sus récords y su partida a medias
# ----------------------------------------------------------------------------

func _make_name_edit() -> void:
	name_edit = LineEdit.new()
	name_edit.position = Vector2(440, 300)
	name_edit.size = Vector2(400, 56)
	name_edit.max_length = Perfiles.NAME_MAX
	name_edit.placeholder_text = Perfiles.DEFAULT_NAME
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.visible = false
	name_edit.text_submitted.connect(func(_t): menu._do(self, "pj_crear"))
	add_child(name_edit)


## Deja la vista sin progreso de nadie (antes de cargar otro personaje).
func _reset_profile_state() -> void:
	sim.essence = 0
	sim.skills.clear()
	sim.skill_paid.clear()
	sim.won = []
	sim.unlocked = []
	sim.seen_forms = []
	sim.week_augur = ""
	sim.between_runs = false
	sim.set_siege(0, 0)
	siege_wins.clear()
	records.clear()
	history = []
	logros = Logros.new()
	challenge = {}
	tree_refund = 0
	unlock_note = ""
	branch_note = ""
	contract_note = ""
	show_tree = false
	tree_from_menu = false
	show_bestiary = false
	selected_id = -1
	menu.sel_siege = 0
	menu.sel_wrath = 0


## Carga el personaje en uso: su progreso, su bestiario y su partida a medias si la tiene.
func _open_profile() -> void:
	_reset_profile_state()
	_load_meta()
	_load_bestiary()
	sim.reset()
	fx.clear()
	warns.clear()
	mut_anim.clear()
	poses.reset()
	menu.started = load_run()
	last_phase = "prep"


func create_character(nombre: String) -> bool:
	if perfiles == null or String(perfiles.create(nombre)) == "":
		return false
	_open_profile()
	_save_meta()
	return true


func select_character(id: String) -> bool:
	if perfiles == null or not perfiles.select(id):
		return false
	_open_profile()
	return true


func delete_character(id: String) -> bool:
	if perfiles == null:
		return false
	var was_current: bool = String(perfiles.current) == id
	if not perfiles.remove(id):
		return false
	if was_current:
		if String(perfiles.current) == "":
			_reset_profile_state()
			sim.reset()
			menu.started = false
		else:
			_open_profile()
	return true


## Árbol desde el menú: entre partidas se compra; con una partida a medias solo se mira.
func open_tree_shop() -> void:
	tree_from_menu = true
	sim.between_runs = true
	menu.open = false
	show_tree = true
	show_bestiary = false


func _close_tree() -> void:
	show_tree = false
	_respec_arm = ""
	if tree_from_menu:
		tree_from_menu = false
		sim.between_runs = false
		menu.open = true
		menu.panel = "main"


## Recupera la partida guardada. true si había una válida.
func load_run() -> bool:
	if Engine.has_meta("sin_persistencia") or not FileAccess.file_exists(_pfile("partida.txt")):
		return false
	var f: FileAccess = FileAccess.open(_pfile("partida.txt"), FileAccess.READ)
	if f == null:
		return false
	var d: Variant = str_to_var(f.get_as_text())
	if not (d is Dictionary) or not sim.run_load(d):
		return false
	challenge = d.get("challenge", {})
	logros.run = d.get("logros_run", logros.run)
	last_phase = "prep"
	return true


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
	var opts: Array = []
	for i in sim.SIEGES.size():
		if not sim.SIEGES[i].has("endless") and siege_unlocked(i):
			opts.append(i)
	var sg: int = int(opts[week % opts.size()]) if not opts.is_empty() else 0
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
