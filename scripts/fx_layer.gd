extends Node2D
## Capa de efectos animados con mezcla aditiva (solo vista): explosiones, impactos y llamas
## grabados sobre fondo negro (el negro no suma nada, así que no hace falta recortarlos).
## Los clips son de data/anim.json (personaje "efectos"); si no hay fotogramas, spawn() no hace
## nada y la vista se queda con los efectos dibujados por código de siempre.

const Anim = preload("res://scripts/anim.gd")

var main: Node = null
var items: Array = []   # {a: Anim, p: Vector2, s: float, rect?: Rect2}
var loops: Array = []   # bucles que la vista vuelve a poner cada fotograma: {clip, p, s, rect?, alpha}
var clock: float = 0.0


func _ready() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Lanza un efecto en `pos` (coordenadas de la arena). Devuelve false si no hay fotogramas.
func spawn(clip: String, pos: Vector2, sc: float = 1.0) -> bool:
	var a = Anim.new("efectos")
	if not a.play(clip):
		return false
	items.append({"a": a, "p": pos, "s": sc})
	return true


## Igual que spawn(), pero el efecto se estira para llenar `rect` (Juicio a lo largo de un carril).
func spawn_rect(clip: String, rect: Rect2) -> bool:
	var a = Anim.new("efectos")
	if not a.play(clip):
		return false
	items.append({"a": a, "p": rect.get_center(), "s": 1.0, "rect": rect})
	return true


static func has(clip: String) -> bool:
	return Anim.has_clip("efectos", clip)


## Bucles: la vista los vacía y los vuelve a añadir cada fotograma (bola de la Brasa, llamas,
## santuario). Si el clip no tiene fotogramas no se añade nada y la vista dibuja lo de siempre.
func clear_loops() -> void:
	loops.clear()


func add_loop(clip: String, pos: Vector2, sc: float = 1.0, alpha: float = 1.0, phase: float = 0.0) -> void:
	if has(clip):
		loops.append({"clip": clip, "p": pos, "s": sc, "alpha": alpha, "phase": phase})


func add_loop_rect(clip: String, rect: Rect2, alpha: float = 1.0, phase: float = 0.0) -> void:
	if has(clip):
		loops.append({"clip": clip, "rect": rect, "alpha": alpha, "phase": phase})


func _process(delta: float) -> void:
	clock += delta
	var keep: Array = []
	for it in items:
		it["a"].update(delta)
		if it["a"].clip != "":
			keep.append(it)
	items = keep
	queue_redraw()


func _draw() -> void:
	var off: Vector2 = main.arena_offset if main != null else Vector2.ZERO
	for lp in loops:
		var ci0: Dictionary = Anim.clip_info("efectos", String(lp["clip"]))
		var i0: int = int((clock + float(lp["phase"])) * float(ci0["fps"])) % int(ci0["frames"])
		_blit(Anim.frame("efectos", String(lp["clip"]), i0), ci0, lp, off, float(lp["alpha"]))
	for it in items:
		var a = it["a"]
		var tx: Texture2D = a.texture()
		if tx != null:
			_blit(tx, a.info(), it, off, 1.0)


func _blit(tx: Texture2D, ci: Dictionary, it: Dictionary, off: Vector2, alpha: float) -> void:
	if tx == null:
		return
	var col: Color = Color(alpha, alpha, alpha, 1.0)   # en mezcla aditiva, oscurecer = atenuar
	if it.has("rect"):
		var r: Rect2 = it["rect"]
		draw_texture_rect(tx, Rect2(r.position + off, r.size), false, col)
		return
	var s: float = float(ci["height"]) * float(it["s"]) / float(tx.get_height())
	var anc: Vector2 = ci["anchor"]
	if anc.x < 0.0:
		anc = Vector2(tx.get_width(), tx.get_height()) * 0.5   # sin ancla: centrado en el punto
	var p: Vector2 = it["p"] + off - anc * s
	draw_texture_rect(tx, Rect2(p, Vector2(tx.get_width(), tx.get_height()) * s), false, col)
