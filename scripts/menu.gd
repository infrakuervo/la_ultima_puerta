extends RefCounted
## Menú principal, opciones (volumen, velocidad, temblor) y tutorial breve de la primera oleada.
## Solo vista: lo usa main.gd (`m`), que le pasa los clics y le pide dibujar.

const Art = preload("res://scripts/art.gd")
const OPTIONS_PATH: String = "user://opciones.json"
const W: float = 1280.0

var open: bool = true            # se empieza en el menú
var panel: String = "main"       # main | options | help
var opts: Dictionary = {"volumen": 0.8, "velocidad": 1, "temblor": true, "tutorial_hecho": false, "intro": true, "musica": 0.6, "tips": []}
var persist: bool = true
var started: bool = false        # ya hay una partida empezada (Continuar)
var sel_siege: int = 0
var sel_wrath: int = 0

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
	for pair in [["Efectos", "volumen"], ["Musica", "musica"]]:
		var bi: int = AudioServer.get_bus_index(String(pair[0]))
		if bi < 0:
			continue
		var v: float = clampf(float(opts[pair[1]]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(bi, v <= 0.001)
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
			y += 70.0
			out.append({"id": "logros", "rect": Rect2(x, y, 320, 58), "text": "Logros"})
		"options":
			var y2: float = 226.0
			out.append({"id": "vol-", "rect": Rect2(x + 150, y2, 50, 50), "text": "−"})
			out.append({"id": "vol+", "rect": Rect2(x + 290, y2, 50, 50), "text": "+"})
			y2 += 58.0
			out.append({"id": "mus-", "rect": Rect2(x + 150, y2, 50, 50), "text": "−"})
			out.append({"id": "mus+", "rect": Rect2(x + 290, y2, 50, 50), "text": "+"})
			y2 += 58.0
			out.append({"id": "spd", "rect": Rect2(x + 150, y2, 190, 50), "text": "x%d" % int(opts["velocidad"])})
			y2 += 58.0
			out.append({"id": "shake", "rect": Rect2(x + 150, y2, 190, 50), "text": "Sí" if bool(opts["temblor"]) else "No"})
			y2 += 58.0
			out.append({"id": "tut", "rect": Rect2(x + 150, y2, 190, 50), "text": "Repetir" if bool(opts["tutorial_hecho"]) else "Activado"})
			y2 += 58.0
			out.append({"id": "intro", "rect": Rect2(x + 150, y2, 190, 50), "text": "Sí" if bool(opts["intro"]) else "No"})
			out.append({"id": "back", "rect": Rect2(x, 590, 320, 58), "text": "Volver"})
		"help", "logros", "historial":
			out.append({"id": "back", "rect": Rect2(x, 640, 320, 58), "text": "Volver"})
			if panel == "logros":
				out.append({"id": "historial", "rect": Rect2(x + 350, 640, 220, 58), "text": "Historial"})
		"siege":
			for i in m.sim.SIEGES.size():
				out.append({"id": "sg:%d" % i, "rect": siege_rect(i, m.sim.SIEGES.size()), "text": "", "card": true})
			out.append({"id": "wr-", "rect": Rect2(x + 40, 470, 50, 50), "text": "−"})
			out.append({"id": "wr+", "rect": Rect2(x + 230, 470, 50, 50), "text": "+"})
			out.append({"id": "start", "rect": Rect2(x, 560, 320, 58), "text": "Empezar"})
			if m.sim.meta_mode or not persist:
				out.append({"id": "reto", "rect": Rect2(x + 350, 560, 300, 58), "text": "Reto semanal"})
			out.append({"id": "back", "rect": Rect2(x, 630, 320, 50), "text": "Volver"})
	return out


func siege_rect(i: int, n: int) -> Rect2:
	var w: float = minf(480.0, (W - 80.0 - 20.0 * float(n - 1)) / float(n))
	var x0: float = (W - (w * n + 20.0 * (n - 1))) * 0.5
	return Rect2(x0 + (w + 20.0) * i, 200, w, 230)


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
	if id.begins_with("sg:"):
		var si: int = int(id.substr(3))
		if m.siege_unlocked(si):
			sel_siege = si
			sel_wrath = m.max_wrath(si)
		return
	match id:
		"continue":
			open = false
			m.fade = 1.0
		"new":
			panel = "siege"
			sel_siege = clampi(sel_siege, 0, m.sim.SIEGES.size() - 1)
			if not m.siege_unlocked(sel_siege):
				sel_siege = 0
			sel_wrath = m.max_wrath(sel_siege)   # propone la Ira más alta abierta: invita a subir
		"wr-":
			sel_wrath = maxi(0, sel_wrath - 1)
		"wr+":
			sel_wrath = mini(m.max_wrath(sel_siege), sel_wrath + 1)
		"start", "reto":
			if id == "reto":
				m.start_challenge()
			else:
				m.start_normal(sel_siege, sel_wrath)
			panel = "main"
			open = false
			started = true
			m.speed = int(opts["velocidad"])
			m.fade = 1.0
			if not bool(opts["tutorial_hecho"]):
				tut_step = 0
				tut_t = 0.0
				m.sim.contract_offer.clear()   # primera partida: sin encargo, para no saturar
		"help":
			panel = "help"
		"logros":
			panel = "logros"
		"historial":
			panel = "historial"
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
		"mus-":
			opts["musica"] = maxf(0.0, snappedf(float(opts["musica"]) - 0.1, 0.1))
			apply(m)
		"mus+":
			opts["musica"] = minf(1.0, snappedf(float(opts["musica"]) + 0.1, 0.1))
			apply(m)
		"spd":
			opts["velocidad"] = int(opts["velocidad"]) % 3 + 1
			m.speed = int(opts["velocidad"])
		"shake":
			opts["temblor"] = not bool(opts["temblor"])
			apply(m)
		"tut":
			opts["tutorial_hecho"] = false
		"intro":
			opts["intro"] = not bool(opts["intro"])
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
		# el demonio en reposo (animado si hay fotogramas) guarda el menú
		m.draw_circle(Vector2(215, 520), 150.0, Color(1.0, 0.4, 0.12, 0.07))
		m.draw_demon_at(Vector2(215, 640), 1.55)
		m._txt("LA ÚLTIMA PUERTA", Vector2(0, 190), 72, Color(1.0, 0.72, 0.38), HORIZONTAL_ALIGNMENT_CENTER, W)
		m._txt("Defiende la puerta del Infierno. Cría bestias. Que no pase nadie.", Vector2(0, 240), 22, Color(0.9, 0.78, 0.7), HORIZONTAL_ALIGNMENT_CENTER, W)
		if m.sim.meta_mode:
			m._txt("Esencia: %d    Rangos del árbol: %d" % [m.sim.essence, m.sim.skill_points_spent()], Vector2(0, 290), 18, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W)
			if m.tree_refund > 0:
				m._txt("El árbol ha cambiado: recuperas %d de esencia de los nodos retirados." % m.tree_refund, Vector2(0, 314), 16, Color(1.0, 0.82, 0.35), HORIZONTAL_ALIGNMENT_CENTER, W)
		m._txt("Esc: menú    B: bestiario    T: árbol    F: velocidad", Vector2(0, 700), 15, Color(0.7, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER, W)
	elif panel == "options":
		m._txt("Opciones", Vector2(0, 190), 48, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		var x: float = W * 0.5 - 160.0
		var rows: Array = [["Efectos", "%d%%" % int(round(float(opts["volumen"]) * 100.0))], ["Música", "%d%%" % int(round(float(opts["musica"]) * 100.0))], ["Velocidad inicial", ""], ["Temblor de pantalla", ""], ["Tutorial", ""], ["Vídeo de inicio", ""]]
		for i in rows.size():
			var yy: float = 259.0 + 58.0 * i
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
			"Tras cada oleada eliges una recompensa: bestias, almas, esencia o un don para toda la partida.",
			"Dos dones de la misma familia despiertan una resonancia. Antes de cada oleada, un augurio",
			"opcional: más riesgo, más premio. Al empezar, un encargo opcional da esencia si lo cumples.",
			"Las almas son de la partida (reclutar y subir de nivel). La esencia es para siempre:",
			"gástala en el Árbol (T) entre oleadas o al terminar. Tras la oleada 4 eliges heraldo",
			"y Tizón muta. Ganar abre la Ira, el segundo asedio y La Grieta (sin fin).",
			"El Árbol tiene una pestaña por rama. La piedra angular (marco dorado) cambia una regla",
			"y pide algo a cambio; al final de cada rama eliges un camino y el otro se cierra.",
			"Reasignar devuelve el 75% de lo pagado, entre partidas. Ganar el segundo y el tercer",
			"asedio abre dos ramas nuevas. Cada semana hay un reto; los logros abren dones.",
		]
		for i in lines.size():
			m._txt(lines[i], Vector2(0, 198 + 31 * i), 19, Color(0.92, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	elif panel == "logros":
		m._txt("Logros", Vector2(0, 110), 44, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		var L = m.logros
		var st: Dictionary = L.stats
		m._txt("Partidas %d   Victorias %d   Oleadas %d   Bajas %d   Mejor Brasa %d   Récord en la Grieta %d" % [int(st["partidas"]), int(st["victorias"]), int(st["oleadas"]), int(st["bajas"]), int(st["mejor_brasa"]), int(m.records.get("grieta", 0))], Vector2(0, 148), 17, Color(0.75, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W)
		for i in L.list.size():
			var l: Dictionary = L.list[i]
			var col_i: int = i % 2
			var row: int = i / 2
			var p0: Vector2 = Vector2(90 + 560 * col_i, 170 + 57 * row)
			var have: bool = L.got.has(String(l["id"]))
			m.draw_rect(Rect2(p0, Vector2(540, 51)), Color(0.22, 0.12, 0.05, 0.85) if have else Color(0.08, 0.05, 0.05, 0.7))
			m.draw_rect(Rect2(p0, Vector2(540, 51)), Color(1.0, 0.8, 0.35) if have else Color(0.4, 0.3, 0.25), false, 2.0)
			m.draw_circle(p0 + Vector2(28, 25), 13.0, Color(1.0, 0.75, 0.3) if have else Color(0.25, 0.2, 0.18))
			if have:
				m.draw_polyline(PackedVector2Array([p0 + Vector2(20, 25), p0 + Vector2(26, 32), p0 + Vector2(37, 18)]), Color(0.2, 0.1, 0.05), 3.0)
			m._txt(String(l["name"]), p0 + Vector2(54, 22), 17, Color(1.0, 0.9, 0.7) if have else Color(0.65, 0.58, 0.55))
			var d: String = String(l["desc"])
			if l.has("unlock"):
				var ud: Dictionary = m.sim.draft_def(String(l["unlock"]))
				d += "  Abre: %s." % (String(ud.get("title", "")) if not ud.is_empty() else "augurio " + String(m.sim.augur_def(String(l["unlock"])).get("name", "")))
			m._txt(d, p0 + Vector2(54, 42), 13, Color(0.85, 0.8, 0.75) if have else Color(0.55, 0.5, 0.48), HORIZONTAL_ALIGNMENT_LEFT, 480.0)
	elif panel == "historial":
		m._txt("Últimas partidas", Vector2(0, 110), 40, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		if m.history.is_empty():
			m._txt("Todavía no hay partidas terminadas.", Vector2(0, 300), 20, Color(0.8, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER, W)
		for i in m.history.size():
			var h: Dictionary = m.history[i]
			var yy: float = 150.0 + 40.0 * i
			var win: bool = String(h.get("resultado", "")) == "Victoria"
			m.draw_rect(Rect2(60, yy, W - 120, 36), Color(0.15, 0.08, 0.05, 0.75) if win else Color(0.08, 0.04, 0.05, 0.7))
			m._txt(String(h.get("fecha", "")), Vector2(72, yy + 24), 14, Color(0.6, 0.55, 0.5))
			m._txt(String(h.get("modo", "")), Vector2(170, yy + 24), 16, Color(0.95, 0.85, 0.7))
			m._txt(String(h.get("resultado", "")), Vector2(430, yy + 24), 16, Color(1.0, 0.85, 0.45) if win else Color(1.0, 0.5, 0.4))
			var extra: Array = []
			if String(h.get("terreno", "")) != "":
				extra.append(String(h["terreno"]))
			if not h.get("dones", []).is_empty():
				extra.append(", ".join(h["dones"]))
			if String(h.get("encargo", "")) != "":
				extra.append(String(h["encargo"]))
			m._txt("  ·  ".join(extra), Vector2(580, yy + 24), 14, Color(0.8, 0.78, 0.85), HORIZONTAL_ALIGNMENT_LEFT, W - 660)
	elif panel == "siege":
		m._txt("Elige asedio", Vector2(0, 160), 44, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, W)
		for i in m.sim.SIEGES.size():
			var sg: Dictionary = m.sim.SIEGES[i]
			var r0: Rect2 = siege_rect(i, m.sim.SIEGES.size())
			var un: bool = m.siege_unlocked(i)
			var selc: bool = i == sel_siege
			m.draw_rect(r0, Color(0.28, 0.11, 0.08) if selc else Color(0.14, 0.07, 0.06))
			m.draw_rect(r0, Color(1.0, 0.85, 0.4) if selc else Color(0.6, 0.35, 0.22), false, 3.0 if selc else 2.0)
			var full: String = String(sg["name"])
			var title: String = full.get_slice(":", 0)
			var sub: String = full.get_slice(":", 1).strip_edges() if full.contains(":") else ""
			m._txt(title, Vector2(r0.position.x, r0.position.y + (38 if sub != "" else 46)), 22, Color(1.0, 0.9, 0.7) if un else Color(0.5, 0.45, 0.42), HORIZONTAL_ALIGNMENT_CENTER, r0.size.x)
			if sub != "":
				m._txt(sub.substr(0, 1).to_upper() + sub.substr(1), Vector2(r0.position.x, r0.position.y + 62), 17, Color(1.0, 0.7, 0.45) if un else Color(0.5, 0.42, 0.4), HORIZONTAL_ALIGNMENT_CENTER, r0.size.x)
			var count_txt: String = "Sin fin" if sg.has("endless") else "%d oleadas" % sg["waves"].size()
			m._txt(count_txt, Vector2(r0.position.x, r0.position.y + 88), 15, Color(0.85, 0.7, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r0.size.x)
			m.draw_multiline_string(m.font, r0.position + Vector2(18, 118), String(sg.get("desc", "")), HORIZONTAL_ALIGNMENT_CENTER, r0.size.x - 36, 15, 4, Color(0.85, 0.8, 0.75) if un else Color(0.45, 0.4, 0.4))
			var sid: String = String(sg["id"])
			var st_txt: String = ""
			if not un:
				# el asedio que lo abre (antes decía siempre «el primer asedio»)
				var need: String = String(m.sim.SIEGES[0]["name"])
				for sg2 in m.sim.SIEGES:
					if String(sg2["id"]) == String(m.sim.SIEGES[i].get("unlock", "")):
						need = String(sg2["name"]).get_slice(":", 0)
				st_txt = "Bloqueado: gana el %s" % need.to_lower()
			elif sg.has("endless"):
				st_txt = "Récord: %d oleadas" % int(m.records.get("grieta", 0))
			elif m.siege_wins.has(sid):
				st_txt = "Ganado (Ira %d)" % int(m.siege_wins[sid])
			if st_txt != "":
				m._txt(st_txt, Vector2(r0.position.x, r0.end.y - 18), 16, Color(0.7, 0.9, 1.0) if un else Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, r0.size.x)
		var xw: float = W * 0.5 - 160.0
		m._txt("Ira %d" % sel_wrath, Vector2(xw + 90, 505), 26, Color(1.0, 0.55, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 140.0)
		var wtxt: String = "Sin Ira: el asedio tal cual." if sel_wrath == 0 else "Enemigos +%d%% de vida y +%d%% de daño; +%d%% de esencia." % [int(round(float(m.sim.B["wrath"]["hp"]) * 100.0 * sel_wrath)), int(round(float(m.sim.B["wrath"]["dmg"]) * 100.0 * sel_wrath)), int(round(float(m.sim.B["wrath"]["essence"]) * 100.0 * sel_wrath))]
		m._txt(wtxt, Vector2(0, 545), 16, Color(0.85, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER, W)
		var ch: Dictionary = m.weekly_challenge()
		var rx: float = W * 0.5 + 190.0
		var ad: Dictionary = m.sim.augur_def(String(ch["augur"]))
		var chl: String = "%s · Ira %d · siempre %s" % [String(m.sim.SIEGES[int(ch["siege"])]["name"]).get_slice(":", 0), int(ch["wrath"]), String(ad.get("name", ""))]
		var chs: int = 15
		while chs > 11 and m.font.get_string_size(chl, HORIZONTAL_ALIGNMENT_LEFT, -1, chs).x > 300.0:
			chs -= 1
		m._txt(chl, Vector2(rx, 640), chs, Color(0.85, 0.65, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 300.0)
		var best: int = int(m.records.get(String(ch["key"]), 0))
		m._txt("Semilla común esta semana · récord %d/%d" % [best, m.sim.SIEGES[int(ch["siege"])]["waves"].size()], Vector2(rx, 662), 13, Color(0.75, 0.65, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 300.0)
		if m.max_wrath(sel_siege) == 0:
			m._txt("Aguanta 8 oleadas para abrir la Ira." if m.sim.SIEGES[sel_siege].has("endless") else "Gana este asedio para abrir la Ira.", Vector2(0, 462), 15, Color(0.7, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER, W)
	for b in buttons(m):
		if b.get("card", false):
			continue
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
	if m.show_tree or m.show_bestiary:
		return   # el cartel del tutorial no tapa el árbol ni el bestiario
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
