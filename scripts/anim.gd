extends RefCounted
## Animación por fotogramas, solo vista (sim.gd no sabe nada de esto).
## Datos en data/anim.json: personaje -> clip -> fps, bucle/una vez, fotograma de impacto,
## escala y pies. Los fotogramas se cargan al pedirlos y se guardan en caché.
## Si falta una carpeta o un fotograma, texture() devuelve null y la vista usa el sprite fijo.
##
## Uso: var a = Anim.new("demonio"); a.play("rayo"); a.update(delta); a.texture(); a.info()

const DATA_PATH: String = "res://data/anim.json"

static var enabled: bool = true
static var _data: Dictionary = {}
static var _loaded: bool = false
static var _count_cache: Dictionary = {}   # "pj/clip" -> nº de fotogramas encontrados
static var _tex_cache: Dictionary = {}     # ruta -> Texture2D (o null)
static var _info_cache: Dictionary = {}    # "pj/clip" -> clip_info ya calculado

var ch: String = ""
var clip: String = ""
var t: float = 0.0
var speed: float = 1.0
var done: bool = false   # un clip con hold ha llegado al último fotograma


# ----------------------------------------------------------------------------
# Datos y carga perezosa
# ----------------------------------------------------------------------------

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func character(pj: String) -> Dictionary:
	var d: Variant = data().get(pj, {})
	return d if d is Dictionary else {}


## Datos del clip con los valores del personaje ya aplicados. {} si no existe o no tiene fotogramas.
static func clip_info(pj: String, name: String) -> Dictionary:
	if not enabled or name == "":
		return {}
	var key: String = pj + "/" + name
	if _info_cache.has(key):
		return _info_cache[key]
	var out: Dictionary = _build_info(pj, name)
	_info_cache[key] = out
	return out


static func _build_info(pj: String, name: String) -> Dictionary:
	var c: Dictionary = character(pj)
	if c.is_empty() or not c.get("clips", {}).has(name):
		return {}
	var count: int = frame_count(pj, name)
	if count <= 0:
		return {}
	var raw: Dictionary = c["clips"][name]
	var anchor: Array = raw.get("anchor", c.get("anchor", [0, 0]))
	var start: int = clampi(int(raw.get("start", 1)), 1, count)
	return {
		"fps": maxf(1.0, float(raw.get("fps", 12.0))),
		"loop": bool(raw.get("loop", false)),
		"hold": bool(raw.get("hold", false)),
		"start": start,
		"impact": clampi(int(raw.get("impact", start)), start, count),
		"frames": count,
		"height": float(raw.get("height", c.get("height", 100.0))),
		"anchor": Vector2(float(anchor[0]), float(anchor[1])),
		"hand": Vector2(float(raw["hand"][0]), float(raw["hand"][1])) if raw.has("hand") else Vector2(-1, -1),
	}


static func has_clip(pj: String, name: String) -> bool:
	return not clip_info(pj, name).is_empty()


static func _path(pj: String, name: String, i: int) -> String:
	return "res://art/anim/%s/%s/%02d.png" % [String(character(pj).get("dir", pj)), name, i + 1]


static func _exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path))


## Cuenta los fotogramas seguidos que hay (01, 02...), con tope opcional "frames" en el JSON.
static func frame_count(pj: String, name: String) -> int:
	var key: String = pj + "/" + name
	if _count_cache.has(key):
		return _count_cache[key]
	var n: int = 0
	var c: Dictionary = character(pj)
	if not c.is_empty() and c.get("clips", {}).has(name):
		var cap: int = int(c["clips"][name].get("frames", 999))
		while n < cap and _exists(_path(pj, name, n)):
			n += 1
	_count_cache[key] = n
	return n


static func frame(pj: String, name: String, i: int) -> Texture2D:
	return load_tex(_path(pj, name, i))


static func load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		var gp: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(gp):
			var img: Image = Image.load_from_file(gp)
			if img != null:
				t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t


## Segundos desde que empieza el clip hasta su fotograma de impacto.
static func impact_delay(pj: String, name: String) -> float:
	var ci: Dictionary = clip_info(pj, name)
	if ci.is_empty():
		return 0.0
	return float(int(ci["impact"]) - int(ci["start"])) / float(ci["fps"])


static func clear_cache() -> void:
	_count_cache.clear()
	_tex_cache.clear()
	_info_cache.clear()
	_loaded = false
	_data = {}


# ----------------------------------------------------------------------------
# Reproductor (uno por personaje en pantalla)
# ----------------------------------------------------------------------------

func _init(pj: String) -> void:
	ch = pj
	clip = idle_clip()


func idle_clip() -> String:
	var idle: String = String(character(ch).get("idle", ""))
	return idle if has_clip(ch, idle) else ""


func info() -> Dictionary:
	return clip_info(ch, clip)


## Empieza un clip desde su primer fotograma. Devuelve false si no existe (se queda como estaba).
func play(name: String) -> bool:
	if not has_clip(ch, name):
		return false
	clip = name
	t = 0.0
	done = false
	return true


## Un clip de una vez que aún no ha acabado (o uno con hold, que no se suelta solo).
func busy() -> bool:
	var ci: Dictionary = info()
	return not ci.is_empty() and not bool(ci["loop"])


## Cambia a un clip en bucle (carrera/reposo) sin cortar un lanzamiento o un mordisco.
## name = "" vuelve al reposo (o al sprite fijo si el personaje no tiene reposo).
func set_base(name: String) -> void:
	if busy():
		return
	if name == "" or not has_clip(ch, name):
		name = idle_clip()
	if name != clip:
		clip = name
		t = 0.0
		done = false


func update(delta: float) -> void:
	var ci: Dictionary = info()
	if ci.is_empty():
		return
	t += delta * speed
	if bool(ci["loop"]):
		return
	var length: float = float(int(ci["frames"]) - int(ci["start"]) + 1) / float(ci["fps"])
	if t >= length:
		if bool(ci["hold"]):
			done = true
			t = length
		else:
			clip = idle_clip()
			t = 0.0


## Índice (desde 0) del fotograma actual dentro de la carpeta del clip, o -1 sin clip.
func index() -> int:
	var ci: Dictionary = info()
	if ci.is_empty():
		return -1
	var n: int = int(ci["frames"])
	var k: int = floori(t * float(ci["fps"]))
	if bool(ci["loop"]):
		return k % n
	return mini(int(ci["start"]) - 1 + k, n - 1)


func texture() -> Texture2D:
	var i: int = index()
	if i < 0:
		return null
	return frame(ch, clip, i)


## Datos para Art.draw_sprite (opts["frame"]), o {} para el sprite fijo.
func draw_opts() -> Dictionary:
	var tx: Texture2D = texture()
	if tx == null:
		return {}
	var ci: Dictionary = info()
	return {"tex": tx, "height": ci["height"], "anchor": ci["anchor"]}


## Punto en pantalla de la mano del clip `name`, con los pies en `feet`. Vector2.INF si no hay datos.
static func hand_at(pj: String, name: String, feet: Vector2, sc: float = 1.0) -> Vector2:
	var ci: Dictionary = clip_info(pj, name)
	if ci.is_empty() or ci["hand"].x < 0.0:
		return Vector2.INF
	var tx: Texture2D = frame(pj, name, int(ci["impact"]) - 1)
	if tx == null:
		return Vector2.INF
	var s: float = float(ci["height"]) * sc / float(tx.get_height())
	return feet + (ci["hand"] - ci["anchor"]) * s
