extends Node
## Capturas de pantallas clave para revisión visual.
## Uso: xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/shots.tscn -- <carpeta_salida>
## Si se pasa un nombre tras la carpeta, solo hace esa captura.

var out_dir: String = "user://shots"
var only: String = ""
var main: Node = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.set_meta("sin_persistencia", true)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	await run()
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	get_viewport().warp_mouse(Vector2(1275, 715))
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("captura ", name)


func want(name: String) -> bool:
	return only == "" or only == name


func s():
	return main.sim


func spawn_all_elites() -> void:
	var kinds: Array = ["capataz", "muro", "tirador", "lumbrero", "tajo", "campana"]
	var i: int = 0
	for k in kinds:
		s()._spawn_enemy(k, i % 3)
		s().enemies[-1]["x"] = 820.0 + float(i / 3) * 160.0
		i += 1
	for k in ["campesino", "escudero", "ballestero", "clerigo", "verdugo", "inquisidor"]:
		s()._spawn_enemy(k, i % 3)
		s().enemies[-1]["x"] = 1120.0 + float(i % 2) * 60.0
		i += 1


func add_beast(kind: String) -> void:
	var spot: Dictionary = s().find_spot(String(s().B[kind].get("spot", "front")))
	if not spot.is_empty():
		s().creatures.append(s()._new_creature(kind, spot))


func run() -> void:
	if want("menu"):
		main.menu.open = true
		main.menu.panel = "main"
		await shot("menu")
		main.menu.panel = "options"
		await shot("opciones")
		main.menu.panel = "help"
		await shot("ayuda")
		main.menu.open = false
		main.menu.panel = "main"
	if want("asedios"):
		main.menu.open = true
		main.menu.panel = "siege"
		await shot("asedios")
		main.menu.open = false
		main.menu.panel = "main"
	if want("alba"):
		s().set_siege(1, 2)
		s().reset()
		for k in ["gargola", "enjambre", "garfio", "alacran"]:
			add_beast(k)
		s().start_wave()
		s().spawn_queue = [{"t": 99999.0, "lane": 0, "kind": "campesino"}]
		var i: int = 0
		for k in ["zapador", "paladin", "sacerdotisa", "ariete", "zapador", "paladin"]:
			s()._spawn_enemy(k, i % 3)
			s().enemies[-1]["x"] = 760.0 + 150.0 * float(i / 3)
			i += 1
		s()._spawn_enemy("gran_maestre", 1)
		s().enemies[-1]["x"] = 1120.0
		s().enemies[-1]["judge_t"] = 0.5
		for j in 60:
			main._process(1.0 / 30.0)
		await shot("alba")
		s().set_siege(0, 0)
	if want("tutorial"):
		main.menu.tut_step = 0
		await shot("tutorial")
		main.menu.tut_step = -1
	if want("prep"):
		await shot("prep")
	if want("bestias"):
		for k in ["alacran", "sapo", "manta", "sabueso", "ojo"]:
			add_beast(k)
		await shot("bestias")
	if want("combate"):
		s().start_wave()
		s().spawn_queue = [{"t": 99999.0, "lane": 0, "kind": "campesino"}]
		spawn_all_elites()
		for i in 20:
			s().step(1.0 / 30.0)
		await shot("combate")
		for i in 90:
			s().step(1.0 / 30.0)
		await shot("combate2")
	if want("impacto"):
		s().reset()
		s().wave_index = 2
		s().start_wave()
		var shot_done: bool = false
		for i in 400:
			if s().brasa_cd <= 0.0 and not s().enemies.is_empty():
				s().cast_brasa(s().epos(s().enemies[0]) + Vector2(-60, 0))
			if s().rayo_cd <= 0.0 and not s().enemies.is_empty():
				s().cast_rayo(s().epos(s().enemies[-1]))
			main._process(1.0 / 30.0)
			for ev in []:
				pass
			if i > 200 and main.juice.particles.size() > 40 and not shot_done:
				shot_done = true
				await shot("impacto")
		if not shot_done:
			await shot("impacto")
	if want("draft"):
		s().reset()
		s().draft_enabled = true
		s().make_draft()
		await shot("draft")
		s().draft.clear()
	if want("bestiario"):
		s().reset()
		for k in ["horno", "trueno", "sabueso", "ojo", "alacran", "sapo", "manta", "gargola", "enjambre", "garfio"]:
			s()._note_seen(k)
		main.show_bestiary = true
		await shot("bestiario")
		main.show_bestiary = false
	if want("arbol"):
		s().reset()
		main.show_tree = true
		await shot("arbol")
		main.show_tree = false
	if want("ruta"):
		s().reset()
		s().phase = "route"
		await shot("ruta")
	if want("forja"):
		s().reset()
		s().route = "verdugo"
		s().phase = "forge"
		await shot("forja")
	if want("demonio"):
		# demonio fijo frente a los clips (en el fotograma de impacto, o a media animación)
		s().reset()
		var A = main.Anim
		A.enabled = false
		main.demon_anim = A.new("demonio")
		await shot("demonio_fijo")
		A.enabled = true
		for c in ["reposo", "rayo", "brasa", "golpe"]:
			main.demon_anim = A.new("demonio")
			main.demon_anim.play(c)
			main.demon_anim.t = A.impact_delay("demonio", c) if c in ["rayo", "brasa"] else 0.6
			await shot("demonio_" + c)
		main.demon_anim = A.new("demonio")
	if want("animacion"):
		# bestias animadas en combate: Tizón y Sabuesos (carrera/mordisco), Horno, y el resto por código
		s().reset()
		for k in ["horno", "sabueso", "alacran", "ojo", "sapo"]:
			add_beast(k)
		s().start_wave()
		s().spawn_queue = [{"t": 99999.0, "lane": 0, "kind": "campesino"}]
		var j: int = 0
		for k in ["escudero", "campesino", "verdugo", "clerigo", "campesino", "escudero"]:
			s()._spawn_enemy(k, j % 3)
			s().enemies[-1]["x"] = 700.0 + 90.0 * float(j)
			j += 1
		for n in [25, 35, 30]:
			for i in n:
				main._process(1.0 / 30.0)
			main.banner_t = 0.0
			await shot("animacion_%d" % n)
	if want("victoria"):
		s().reset()
		main.demon_anim.play("victoria")
		main.demon_anim.t = 3.5
		s().kills = 87
		main.unlock_note = "Se abre: Segundo asedio: la Orden del Alba. Se abre Ira 1 en este asedio."
		s().meta_mode = true
		s().phase = "victory"
		await shot("victoria")
	if want("derrota"):
		s().reset()
		s().defeat_wave = 3
		s().phase = "defeat"
		main.demon_anim.play("derrota")
		main.demon_anim.t = 99.0
		await shot("derrota")
