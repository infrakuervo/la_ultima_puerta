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
		for k in ["horno", "trueno", "sabueso", "ojo", "alacran", "sapo", "manta"]:
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
	if want("victoria"):
		s().reset()
		s().kills = 87
		s().phase = "victory"
		await shot("victoria")
	if want("derrota"):
		s().reset()
		s().defeat_wave = 3
		s().phase = "defeat"
		await shot("derrota")
