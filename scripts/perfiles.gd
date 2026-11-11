extends RefCounted
## Personajes (solo vista): cada uno guarda lo suyo en una carpeta.
##   <raíz>/personajes.json                 lista, último usado y contador de ids
##   <raíz>/personajes/<id>/meta.json       esencia, árbol, asedios, récords, logros, historial
##   <raíz>/personajes/<id>/partida.txt     partida a medias
##   <raíz>/personajes/<id>/bestiario.json  formas vistas
## Las opciones (opciones.json) son generales y se quedan en la raíz.
## Si en la raíz están los archivos de antes de los personajes, se convierten en el primero.

const MAX: int = 3
const DEFAULT_NAME: String = "Demonio"
const NAME_MAX: int = 16
const FILES: Array = ["meta.json", "partida.txt", "bestiario.json"]

var root: String = "user://"
var list: Array = []          # [{id, nombre, creado}]
var current: String = ""      # id del personaje en uso ("" = ninguno todavía)
var next_n: int = 1
var migrated: bool = false    # en esta carga se convirtieron los archivos antiguos


func _init(r: String = "user://") -> void:
	root = r if r.ends_with("/") else r + "/"


func index_path() -> String:
	return root + "personajes.json"


func dir_of(id: String) -> String:
	return root + "personajes/" + id


## Ruta de un archivo del personaje en uso ("" si no hay ninguno).
func path(file: String) -> String:
	return "" if current == "" else dir_of(current) + "/" + file


func has(id: String) -> bool:
	return not get_def(id).is_empty()


func get_def(id: String) -> Dictionary:
	for c in list:
		if String(c["id"]) == id:
			return c
	return {}


func current_name() -> String:
	return String(get_def(current).get("nombre", ""))


static func clean_name(s: String) -> String:
	var t: String = s.strip_edges().replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	t = t.substr(0, NAME_MAX).strip_edges()
	return DEFAULT_NAME if t == "" else t


## Lee la lista. Sin lista pero con archivos antiguos en la raíz, los migra al primer personaje.
func load_all() -> void:
	list = []
	current = ""
	next_n = 1
	migrated = false
	if FileAccess.file_exists(index_path()):
		var f: FileAccess = FileAccess.open(index_path(), FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if typeof(d) == TYPE_DICTIONARY:
			for c in d.get("lista", []):
				if typeof(c) == TYPE_DICTIONARY and c.has("id"):
					list.append({"id": String(c["id"]), "nombre": clean_name(String(c.get("nombre", ""))), "creado": String(c.get("creado", ""))})
			next_n = maxi(1, int(d.get("siguiente", list.size() + 1)))
			current = String(d.get("ultimo", ""))
	if list.is_empty():
		_migrate_legacy()
	if not has(current):
		current = String(list[0]["id"]) if not list.is_empty() else ""


func save_index() -> void:
	DirAccess.make_dir_recursive_absolute(root + "personajes")
	var f: FileAccess = FileAccess.open(index_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"lista": list, "ultimo": current, "siguiente": next_n}, "  "))


func _migrate_legacy() -> void:
	var any: bool = false
	for fn in FILES:
		if FileAccess.file_exists(root + String(fn)):
			any = true
	if not any:
		return
	var id: String = create("")
	for fn in FILES:
		var src: String = root + String(fn)
		if not FileAccess.file_exists(src):
			continue
		var dst: String = dir_of(id) + "/" + String(fn)
		if DirAccess.rename_absolute(src, dst) != OK:
			# sin renombrar (otro disco, web): copiar y borrar
			var fin: FileAccess = FileAccess.open(src, FileAccess.READ)
			var fout: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
			if fin != null and fout != null:
				fout.store_buffer(fin.get_buffer(fin.get_length()))
				fin.close()
				fout.close()
				DirAccess.remove_absolute(src)
	migrated = true


## Crea un personaje y lo deja en uso. Devuelve su id ("" si no caben más).
func create(nombre: String) -> String:
	if list.size() >= MAX:
		return ""
	var id: String = "p%d" % next_n
	while has(id) or DirAccess.dir_exists_absolute(dir_of(id)):
		next_n += 1
		id = "p%d" % next_n
	next_n += 1
	DirAccess.make_dir_recursive_absolute(dir_of(id))
	list.append({"id": id, "nombre": clean_name(nombre), "creado": Time.get_date_string_from_system()})
	current = id
	save_index()
	return id


func select(id: String) -> bool:
	if not has(id):
		return false
	current = id
	save_index()
	return true


## Borra un personaje y todos sus archivos. Si era el que estaba en uso, pasa al primero que quede.
func remove(id: String) -> bool:
	if not has(id):
		return false
	var d: String = dir_of(id)
	var da: DirAccess = DirAccess.open(d)
	if da != null:
		for fn in da.get_files():
			DirAccess.remove_absolute(d + "/" + fn)
		DirAccess.remove_absolute(d)
	list = list.filter(func(c): return String(c["id"]) != id)
	if current == id:
		current = String(list[0]["id"]) if not list.is_empty() else ""
	save_index()
	return true


## Resumen para la pantalla de personajes, leído de su meta.json.
func summary(id: String) -> Dictionary:
	var out: Dictionary = {"esencia": 0, "rangos": 0, "asedios": 0, "ira": 0, "grieta": 0, "ultima": "", "partida": FileAccess.file_exists(dir_of(id) + "/partida.txt")}
	var p: String = dir_of(id) + "/meta.json"
	if not FileAccess.file_exists(p):
		return out
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(d) != TYPE_DICTIONARY:
		return out
	out["esencia"] = int(d.get("esencia", 0))
	var sk: Dictionary = d.get("habilidades", {})
	for k in sk:
		out["rangos"] += int(sk[k])
	var wins: Dictionary = d.get("asedios", {})
	out["asedios"] = wins.size()
	for k2 in wins:
		out["ira"] = maxi(int(out["ira"]), int(wins[k2]))
	out["grieta"] = int(d.get("records", {}).get("grieta", 0))
	var h: Array = d.get("historial", [])
	if not h.is_empty() and typeof(h[0]) == TYPE_DICTIONARY:
		out["ultima"] = "%s · %s" % [String(h[0].get("fecha", "")), String(h[0].get("resultado", ""))]
	return out
