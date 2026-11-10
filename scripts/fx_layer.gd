extends Node2D
## Capa de efectos animados con mezcla aditiva (solo vista): explosiones, impactos y llamas
## grabados sobre fondo negro (el negro no suma nada, así que no hace falta recortarlos).
## Los clips son de data/anim.json (personaje "efectos"); si no hay fotogramas, spawn() no hace
## nada y la vista se queda con los efectos dibujados por código de siempre.

const Anim = preload("res://scripts/anim.gd")

var main: Node = null
var items: Array = []   # {a: Anim, p: Vector2, s: float}


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


func _process(delta: float) -> void:
	if items.is_empty():
		return
	var keep: Array = []
	for it in items:
		it["a"].update(delta)
		if it["a"].clip != "":
			keep.append(it)
	items = keep
	queue_redraw()


func _draw() -> void:
	var off: Vector2 = main.arena_offset if main != null else Vector2.ZERO
	for it in items:
		var a = it["a"]
		var tx: Texture2D = a.texture()
		if tx == null:
			continue
		var ci: Dictionary = a.info()
		var s: float = float(ci["height"]) * float(it["s"]) / float(tx.get_height())
		var anc: Vector2 = ci["anchor"]
		if anc.x < 0.0:
			anc = Vector2(tx.get_width(), tx.get_height()) * 0.5   # sin ancla: centrado en el punto
		var p: Vector2 = it["p"] + off - anc * s
		draw_texture_rect(tx, Rect2(p, Vector2(tx.get_width(), tx.get_height()) * s), false)
