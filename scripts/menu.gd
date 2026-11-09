extends RefCounted
## Menú principal, opciones (volumen, velocidad, temblor) y tutorial breve de la primera oleada.
## Solo vista: lo usa main.gd (`m`), que le pasa los clics y le pide dibujar.

const Art = preload("res://scripts/art.gd")
const OPTIONS_PATH: String = "user://opciones.json"
const W: float = 1280.0

var open: bool = true            # se empieza en el menú
var panel: String = "main"       # main | options | help
var opts: Dictionary = {"volumen": 0.8, "velocidad": 1, "temblor": true, "tutorial_hecho": false}
var persist: bool = true
var started: bool = false        # ya hay una partida empezada (Continuar)

# Tutorial
var tut_step: int = -1
var tut_t: float = 0.0


func load_options() -> void:
	if not persist or not FileAccess.file_exists(OPTIONS_PATH):
		return
	var f: FileAccess = FileAccess.open(OPTIONS_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			opts[k] = d[k]


func save_options() -> void:
	if not persist:
		return
	var f: FileAccess = FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(opts, "  "))


func apply(m) -> void:
	var v: float = clampf(float(opts["volumen"]), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)
	m.juice.shake_scale = 1.0 if bool(opts["temblor"]) else 0.0


# --- botones ---------------------------------------------------------------------

func buttons(m) -> Array:
	var out: Array = []
	var x: float = W * 0.5 - 160.0
	match panel:
		"main":
			var y: float = 330.0
			if started and m.sim.phase != "victory" and m.sim.phase != "defeat":
				out.append({"id": "continue", "rect": Rect2(x, y, 320, 58), "text": "Continuar"})
				y += 70.0
				out.append({"id": "new", "rect": Rect2(x, y, 320, 58), "text": "Nueva partida"})
			else:
				out.append({"id": "new", "rect": Rect2(x, y, 320, 58), "text": "Jugar"})
			y += 70.0
			out.append({"id": "help", "rect": Rect2(x, y, 320, 58), "text": "Cómo se juega"})
			y += 70.0
			out.append({"id": "options", "rect": Rect2(x, y, 320, 58), "text": "Opciones"})
		"options":
			var y2: float = 250.0
			out.append({"id": "vol-", "rect": Rect2(x + 150, y2, 50, 50), "text": "−"})
			out.append({"id": "vol+", "rect": Rect2(x + 290, y2, 50, 50), "text": "+"})
			y2 += 80.0
			out.append({"id": "spd", "rect": Rect2(x + 150, y2, 190, 50), "text": "x%d" % int(opts["velocidad"])})
			y2 += 80.0
			out.append({"id": "shake", "rect": Rect2(x + 150, y2, 190, 50), "text": "Sí" if bool(opts["temblor"]) else "No"})
			y2 += 80.0
			out.append({"id": "tut", "rect": Rect2(x + 150, y2, 190, 50), "text": "Repetir" if bool(opts["tutorial_hecho"]) else "Activado"})
			out.append({"id": "back", "rect": Rect2(x, 590, 320, 58), "text": "Volver"})
		"help":
			out.append({"id": "back", "rect": Rect2(x, 600, 320, 58), "text": "Volver"})
	return out


func press(m, p: Vector2) -> bool:
	if not open:
		return false
	for b in buttons(m):
		if b["rect"].has_point(p):
			_do(m, String(b["id"]))
			m._play("click")
			return true
	return true


func _do(m, id: String) -> void:
	match id:
		"continue":
			open = false
			m.fade = 1.0
		"new":
			if started:
				m._restart()
			open = false
			started = true
			m.speed = int(opts["velocidad"])
			m.fade = 1.0
			if not bool(opts["tutorial_hecho"]):
				tut_step = 0
				tut_t = 0.0
		"help":
			panel = "help"
		"options":
			panel = "options"
		"back":
			panel = "main"
			save_options()
		"vol-":
			opts["volumen"] = maxf(0.0, snappedf(float(opts["volumen"]) - 0.1, 0.1))
			apply(m)
		"vol+":
			opts["volumen"] = minf(1.0, snappedf(float(opts["volumen"]) + 0.1, 0.1))
			apply(m)
		"spd":
			opts["velocidad"] = 3 - int(opts["velocidad"])
			m.speed = int(opts["velocidad"])
		"shake":
			opts["temblor"] = not bool(opts["temblor"])
			apply(m)
		"tut":
			opts["tutorial_hecho"] = false
	save_options()


func toggle(m) -> void:
	open = not open
	panel = "main"
	if not open:
		m.fade = 0.6


# --- dibujo ----------------------------------------------------------------------

func draw(m) -> void:
	if not open:
		return
	var bg: Texture2D = Art.background()
	if bg != null:
		m.draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false, Color(0.55, 0.45, 0.5))
	else:
		m.draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.03, 0.04))
	m.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.0, 0.02, 0.55))
	m.juice.draw_back(m)
	if panel == "main":
		m._txt("LA ÚLTIMA PUERTA", Vector2(0, 190), 72, Color(1.0, 0.72, 0.38), HORIZONTAL_ALIGNMENT_CENTER, W)
		m._txt("Defiende la puerta del Infierno. Cría bestias. Que no pase nadie.", Vector2(0, 240), 22, Color(0.9, 0.78, 0.7), HORIZONTAL_ALIGNMENT_CENTER, W)
		if m.sim.meta_mode:
			m._txt("Esencia: %d    Rangos del árbol: %d" % [m.sim.essence, m.sim.skill_points_spent()], Vector2(0, 290), 18, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W)
		m._txt("Esc: menú    B: bestiario    T: árbol    F: velocidad", Vector2(0, 700), 15, Color(0.7, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER, W)
	elif panel == "options":
		m._txt("Opciones", Vector2(0, 190), 48, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		var x: float = W * 0.5 - 160.0
		var rows: Array = [["Volumen", "%d%%" % int(round(float(opts["volumen"]) * 100.0))], ["Velocidad inicial", ""], ["Temblor de pantalla", ""], ["Tutorial", ""]]
		for i in rows.size():
			var yy: float = 283.0 + 80.0 * i
			m._txt(rows[i][0], Vector2(x - 160, yy), 22, Color(0.95, 0.88, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 290.0)
			if rows[i][1] != "":
				m._txt(rows[i][1], Vector2(x + 200, yy), 22, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	elif panel == "help":
		m._txt("Cómo se juega", Vector2(0, 150), 44, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		var lines: Array = [
			"Los humanos entran por la derecha y quieren romper la Puerta (izquierda).",
			"Entre oleadas, arrastra tus bestias: la vanguardia frena, la retaguardia dispara.",
			"En combate, clic lanza el hechizo: la Brasa cae al rato en un área; el Rayo es inmediato.",
			"Clic derecho, rueda o teclas 1/2 cambian de hechizo. Mantén pulsado para repetir.",
			"Tras cada oleada eliges una recompensa: bestias gratis, almas o esencia.",
			"Las almas son de la partida (reclutar y subir de nivel). La esencia es para siempre:",
			"gástala en el Árbol (T) entre oleadas o al terminar. Tras la oleada 4 eliges heraldo,",
			"y Tizón muta. Si gana el primer asedio, se abre el siguiente.",
		]
		for i in lines.size():
			m._txt(lines[i], Vector2(0, 230 + 40 * i), 20, Color(0.92, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	for b in buttons(m):
		var r: Rect2 = b["rect"]
		var hov: bool = r.has_point(m.mouse_pos)
		m.draw_rect(r, Color(0.36, 0.14, 0.09) if hov else Color(0.24, 0.09, 0.07))
		m.draw_rect(r, Color(1.0, 0.8, 0.4) if hov else Color(0.8, 0.45, 0.25), false, 2.0)
		m._txt(String(b["text"]), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 9), 24, Color(1.0, 0.92, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# --- tutorial --------------------------------------------------------------------

func tut_event(m, ev: Dictionary) -> void:
	if tut_step < 0:
		return
	var t: String = String(ev["t"])
	if tut_step == 0 and t == "wave_start":
		_tut_next(1)
	elif tut_step == 1 and t == "brasa_cast":
		_tut_next(2)
	elif tut_step == 2 and t == "rayo":
		_tut_next(3)
	elif tut_step <= 3 and t == "draft":
		_tut_next(4)
	elif tut_step == 4 and t == "draft_pick":
		_tut_next(5)
	elif tut_step <= 4 and t == "defeat":
		_finish()


func _tut_next(n: int) -> void:
	tut_step = n
	tut_t = 0.0


func _finish() -> void:
	tut_step = -1
	opts["tutorial_hecho"] = true
	save_options()


func tut_update(delta: float) -> void:
	if tut_step < 0:
		return
	tut_t += delta
	if tut_step == 3 and tut_t > 5.0:
		tut_step = 30   # en espera de la elección
	elif tut_step == 5 and tut_t > 7.0:
		_finish()


func tut_draw(m) -> void:
	if tut_step < 0 or open:
		return
	var text: String = ""
	var hl: Rect2 = Rect2()
	match tut_step:
		0:
			text = "Arrastra a Tizón para colocarlo (la vanguardia frena a los humanos).\nCuando quieras, pulsa «Iniciar oleada» o Espacio."
			hl = Rect2(1030, 624, 230, 72)
		1:
			text = "Haz clic sobre los campesinos: la Brasa cae a los 1,5 s.\nApunta un poco por delante de ellos."
		2:
			text = "Clic derecho (o tecla 2) cambia al Rayo: es instantáneo.\nÚsalo para rematar a los que se escapan."
			hl = Rect2(180, 624, 150, 72)
		3:
			text = "Mantén pulsado para repetir el hechizo en cuanto se recargue.\n¡Que nadie toque la Puerta!"
		4:
			text = "Tras cada oleada eliges una recompensa:\nbestias gratis, almas o esencia."
		5:
			text = "La esencia se queda para siempre: gástala en el Árbol (T).\nLas almas sirven para reclutar y subir de nivel en esta partida."
			hl = Rect2(340, 624, 150, 72)
	if text == "":
		return
	var box: Rect2 = Rect2(300, 92, 680, 74)
	if tut_step == 4:
		box.position.y = 512
	var pulse: float = 0.5 + 0.5 * sin(m.clock * 5.0)
	m.draw_rect(box, Color(0.06, 0.03, 0.02, 0.9))
	m.draw_rect(box, Color(1.0, 0.8, 0.35, 0.6 + 0.4 * pulse), false, 2.0)
	m.draw_multiline_string(m.font, box.position + Vector2(16, 28), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 32, 18, -1, Color(1.0, 0.93, 0.82))
	if hl.size.x > 0.0:
		m.draw_rect(hl.grow(4.0 + 3.0 * pulse), Color(1.0, 0.85, 0.3, 0.9), false, 3.0)
