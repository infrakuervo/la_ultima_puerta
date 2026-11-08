extends RefCounted
## Arte provisional: siluetas dibujadas con polígonos. Tres siluetas distinguibles
## para las criaturas de la ruta (Sabueso: bajo y alargado; Horno: ancho y redondo
## con fogón; Trueno: alto y espinoso con campana). Los enemigos miran a la izquierda.

const OUTLINE: Color = Color(0.04, 0.02, 0.03)


static func _poly(ci: CanvasItem, pts: Array, pos: Vector2, sx: float, sy: float, col: Color) -> void:
	var arr: PackedVector2Array = PackedVector2Array()
	for p in pts:
		arr.append(pos + Vector2(p[0] * sx, p[1] * sy))
	ci.draw_colored_polygon(arr, col)
	var closed: PackedVector2Array = arr.duplicate()
	closed.append(arr[0])
	ci.draw_polyline(closed, OUTLINE, 2.0)


static func _eye(ci: CanvasItem, p: Vector2, col: Color, r: float) -> void:
	ci.draw_circle(p, r, col)


## Sprites del pack de la Fosa (art/sprites/*.png). Si falta alguno se usa la silueta provisional.
const SPRITE_H: Dictionary = {
	"sabueso": 78.0, "horno": 100.0, "trueno": 120.0, "ojo": 90.0, "demonio": 190.0,
	"campesino": 90.0, "escudero": 96.0, "ballestero": 90.0, "clerigo": 108.0,
	"verdugo": 140.0, "inquisidor": 150.0,
}
const SPRITE_LIFT: Dictionary = {"ojo": 44.0}
static var _tex_cache: Dictionary = {}


static func tex(key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t: Texture2D = null
	var path: String = "res://art/sprites/%s.png" % key
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		var gp: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(gp):
			var img: Image = Image.load_from_file(gp)
			if img != null:
				img.generate_mipmaps()
				t = ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


static var _bg_tex: Texture2D = null
static var _bg_tried: bool = false


static func background() -> Texture2D:
	if _bg_tried:
		return _bg_tex
	_bg_tried = true
	var path: String = "res://art/fondo-fosa.jpg"
	if ResourceLoader.exists(path):
		_bg_tex = load(path)
	else:
		var gp: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(gp):
			var img: Image = Image.load_from_file(gp)
			if img != null:
				_bg_tex = ImageTexture.create_from_image(img)
	return _bg_tex


## Dibuja un sprite con los pies en `pos`. opts: scale, alpha, flash, squash, bob, glow
static func draw_sprite(ci: CanvasItem, key: String, pos: Vector2, t: float, opts: Dictionary) -> bool:
	var tx: Texture2D = tex(key)
	if tx == null:
		return false
	var sc: float = float(opts.get("scale", 1.0))
	var base: String = key.get_slice("_", 0)
	var h: float = float(SPRITE_H[base]) * sc
	var w: float = h * float(tx.get_width()) / float(tx.get_height())
	var squash: float = float(opts.get("squash", 1.0))
	var alpha: float = float(opts.get("alpha", 1.0))
	var flash: float = float(opts.get("flash", 0.0))
	var bob: float = float(opts.get("bob", 0.0))
	var lift: float = float(SPRITE_LIFT.get(base, 0.0)) * sc
	if base == "ojo":
		bob += sin(t * 2.6) * 5.0
	# sombra elíptica en el suelo
	var sw: float = maxf(w * 0.34, 26.0)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(pos + Vector2(cos(a) * sw, 4.0 + sin(a) * sw * 0.28))
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.38 * alpha))
	var glow: float = float(opts.get("glow", 0.0))
	if glow > 0.0:
		ci.draw_circle(pos + Vector2(0, -h * 0.5 - lift), (h * 0.55 + 30.0 * glow), Color(1.0, 0.55, 0.2, 0.25 * glow))
	var hh: float = h * squash
	var rect: Rect2 = Rect2(pos.x - w * 0.5, pos.y - hh - lift + bob, w, hh)
	var col: Color = Color(1, 1, 1, alpha).lerp(Color(1.6, 1.5, 1.3, alpha), flash)
	ci.draw_texture_rect(tx, rect, false, col)
	var scars: int = int(opts.get("scars", 0))
	for i in scars:
		ci.draw_line(pos + Vector2(-w * 0.18 + i * 7.0, -hh * 0.62 - lift), pos + Vector2(-w * 0.18 + i * 7.0 + 8.0, -hh * 0.62 + 12.0 - lift), Color(1.0, 0.85, 0.5, 0.9 * alpha), 2.0)
	return true


## kind: sabueso | horno | trueno | ojo. opts: scale, hambre, scars, crouch, fallen, flash, glow
static func draw_creature(ci: CanvasItem, kind: String, pos: Vector2, t: float, opts: Dictionary) -> void:
	var s: float = float(opts.get("scale", 1.0))
	var scars: int = int(opts.get("scars", 0))
	var flash: float = float(opts.get("flash", 0.0))
	var fallen: bool = bool(opts.get("fallen", false))
	var glow: float = float(opts.get("glow", 0.0))
	if SPRITE_H.has(kind):
		var so: Dictionary = {"scale": s, "alpha": 0.35 if fallen else 1.0, "flash": flash, "glow": glow, "scars": scars,
			"squash": 0.86 if bool(opts.get("crouch", false)) else 1.0, "bob": sin(t * 5.0) * 1.5}
		if draw_sprite(ci, kind, pos, t, so):
			if int(opts.get("hambre", 0)) > 0:
				for i in int(opts.get("hambre", 0)):
					ci.draw_circle(pos + Vector2(-16 + i * 12, -34 * s), 4.0, Color(1.0, 0.6, 0.2))
			return
	var bob: float = sin(t * 5.0) * 1.5
	var p: Vector2 = pos + Vector2(0, bob)
	var alpha: float = 0.35 if fallen else 1.0
	# sombra
	ci.draw_circle(pos + Vector2(0, 4), 26.0 * s, Color(0, 0, 0, 0.35 * alpha))
	if glow > 0.0:
		ci.draw_circle(p + Vector2(0, -34 * s), (50.0 + 30.0 * glow) * s, Color(1.0, 0.55, 0.2, 0.25 * glow))
	match kind:
		"sabueso":
			var body: Color = Color(0.55, 0.52, 0.5, alpha).lerp(Color(1, 1, 1, alpha), flash)
			var pts: Array = [[-36, -18], [-12, -32], [20, -30], [40, -24], [54, -32], [64, -24], [58, -14],
				[42, -12], [32, 0], [22, 0], [20, -10], [-12, -10], [-18, 0], [-28, 0], [-32, -10], [-46, -26]]
			_poly(ci, pts, p, s, s, body)
			_eye(ci, p + Vector2(52, -24) * s, Color(1.0, 0.6, 0.1, alpha), 3.0 * s)
			# brasas en la escoria
			ci.draw_circle(p + Vector2(-4, -22) * s, 3.0 * s, Color(1.0, 0.45, 0.1, alpha))
			ci.draw_circle(p + Vector2(14, -18) * s, 2.0 * s, Color(1.0, 0.6, 0.2, alpha))
		"horno":
			var squash: float = 1.0 + 0.06 * sin(t * 3.0)
			var body2: Color = Color(0.5, 0.2, 0.14, alpha).lerp(Color(1, 1, 1, alpha), flash)
			var pts2: Array = [[-40, 0], [-46, -30], [-34, -62], [-6, -78], [26, -70], [46, -48], [52, -30],
				[44, -14], [50, 0], [34, 0], [30, -8], [-18, -8], [-24, 0]]
			_poly(ci, pts2, p, s, s * squash, body2)
			# fauces abiertas
			_poly(ci, [[40, -48], [64, -56], [64, -20], [40, -26]], p, s, s, Color(0.15, 0.02, 0.02, alpha))
			ci.draw_circle(p + Vector2(58, -38) * s, 5.0 * s, Color(1.0, 0.7, 0.2, alpha))
			# brasero a la espalda: hambre = brasas encendidas
			_poly(ci, [[-30, -72], [-8, -72], [-12, -86], [-26, -86]], p, s, s, Color(0.25, 0.2, 0.2, alpha))
			var hambre: int = int(opts.get("hambre", 0))
			for i in 4:
				var lit: bool = i < hambre
				var c2: Color = Color(1.0, 0.65, 0.15, alpha) if lit else Color(0.3, 0.12, 0.08, alpha)
				ci.draw_circle(p + Vector2(-26 + i * 9, -92) * s, 4.0 * s, c2)
			_eye(ci, p + Vector2(36, -58) * s, Color(1.0, 0.9, 0.4, alpha), 3.0 * s)
		"trueno":
			var crouch: bool = bool(opts.get("crouch", false))
			var sy: float = 0.72 if crouch else 1.0
			var body3: Color = Color(0.35, 0.38, 0.62, alpha).lerp(Color(1, 1, 1, alpha), flash)
			var pts3: Array = [[-34, 0], [-30, -30], [-40, -50], [-24, -46], [-18, -66], [-6, -48], [4, -72],
				[16, -50], [30, -60], [46, -50], [62, -52], [66, -40], [52, -34], [40, -24], [34, 0], [26, 0],
				[22, -20], [-10, -20], [-14, 0]]
			_poly(ci, pts3, p, s, s * sy, body3)
			# campana del Inquisidor en el lomo
			_poly(ci, [[-6, -52], [8, -52], [12, -38], [-10, -38]], p, s, s * sy, Color(0.85, 0.75, 0.3, alpha))
			ci.draw_circle(p + Vector2(1, -36 * sy) * s, 3.0 * s, Color(0.95, 0.9, 0.5, alpha))
			# chispas
			var spark: float = 0.5 + 0.5 * sin(t * 18.0)
			ci.draw_line(p + Vector2(30, -62 * sy) * s, p + Vector2(40, -78 * sy) * s, Color(0.7, 0.85, 1.0, alpha * spark), 2.0)
			_eye(ci, p + Vector2(54, -44 * sy) * s, Color(0.7, 0.9, 1.0, alpha), 3.0 * s)
		"ojo":
			var hover: Vector2 = p + Vector2(0, -62 + sin(t * 2.0) * 5.0) * s
			for i in 5:
				var a: float = -0.9 + i * 0.45
				ci.draw_line(hover, hover + Vector2(sin(a + t) * 14, 30 + cos(a * 2.0 + t) * 6) * s, Color(0.55, 0.45, 0.2, alpha), 2.0)
			ci.draw_circle(hover, 24.0 * s, Color(0.78, 0.66, 0.28, alpha).lerp(Color(1, 1, 1, alpha), flash))
			ci.draw_arc(hover, 24.0 * s, 0.0, TAU, 24, OUTLINE, 2.0)
			ci.draw_circle(hover + Vector2(6, 0) * s, 11.0 * s, Color(0.95, 0.92, 0.8, alpha))
			ci.draw_circle(hover + Vector2(9, 0) * s, 5.0 * s, Color(0.1, 0.05, 0.02, alpha))
	# cicatrices (Tizón conserva el nombre y suma marcas)
	for i in mini(scars, 5):
		var sx0: float = -10.0 + i * 9.0
		ci.draw_line(p + Vector2(sx0, -30 - (i % 2) * 4) * s, p + Vector2(sx0 + 8, -18) * s, Color(0.9, 0.12, 0.12, alpha), 2.0)


## kind: campesino | escudero | ballestero | clerigo | verdugo | inquisidor
static func draw_enemy(ci: CanvasItem, kind: String, pos: Vector2, t: float, opts: Dictionary) -> void:
	var flash: float = float(opts.get("flash", 0.0))
	var burning: bool = bool(opts.get("burning", false))
	var bump: float = float(opts.get("bump", 0.0))
	var esp: String = String(opts.get("sprite", ""))
	if esp != "":
		var eo2: Dictionary = {"flash": flash, "scale": float(opts.get("scale", 1.0)), "bob": -absf(sin(t * 6.0 + bump * 6.0)) * 3.0}
		if burning:
			eo2["flash"] = maxf(flash, 0.25 + 0.15 * sin(t * 14.0))
		if draw_sprite(ci, esp, pos, t, eo2):
			return
		kind = esp.get_slice("_", 0)
	if SPRITE_H.has(kind):
		var eo: Dictionary = {"flash": flash, "bob": -absf(sin(t * 6.0 + bump * 6.0)) * 3.0}
		if burning:
			eo["flash"] = maxf(flash, 0.25 + 0.15 * sin(t * 14.0))
		var vk: String = kind
		var vi: int = int(opts.get("variant", 0))
		eo["scale"] = float(opts.get("scale", 1.0))
		if vi > 0 and tex("%s_v%02d" % [kind, vi]) != null:
			vk = "%s_v%02d" % [kind, vi]
		if draw_sprite(ci, vk, pos, t, eo):
			return
	var p: Vector2 = pos + Vector2(0, absf(sin(t * 6.0 + bump * 6.0)) * -2.0)
	var skin: Color = Color(0.85, 0.7, 0.55).lerp(Color(1, 1, 1), flash)
	var cloth: Color = Color(0.4, 0.33, 0.22)
	if burning:
		cloth = cloth.lerp(Color(1.0, 0.4, 0.1), 0.5)
	match kind:
		"campesino":
			ci.draw_circle(pos + Vector2(0, 3), 14.0, Color(0, 0, 0, 0.3))
			_poly(ci, [[-8, 0], [-10, -26], [0, -32], [10, -26], [8, 0]], p, 1.0, 1.0, cloth)
			ci.draw_circle(p + Vector2(0, -38), 7.0, skin)
			ci.draw_line(p + Vector2(-14, -4), p + Vector2(-16, -52), Color(0.5, 0.35, 0.2), 2.0)
			ci.draw_line(p + Vector2(-20, -52), p + Vector2(-12, -52), Color(0.7, 0.7, 0.7), 2.0)
		"escudero":
			ci.draw_circle(pos + Vector2(0, 3), 18.0, Color(0, 0, 0, 0.3))
			_poly(ci, [[-10, 0], [-12, -30], [0, -38], [12, -30], [10, 0]], p, 1.0, 1.0, Color(0.45, 0.47, 0.5))
			ci.draw_circle(p + Vector2(0, -44), 8.0, Color(0.6, 0.62, 0.66))
			_poly(ci, [[-30, -48], [-14, -48], [-14, -6], [-22, 2], [-30, -6]], p, 1.0, 1.0, Color(0.55, 0.15, 0.15).lerp(Color(1, 1, 1), flash))
		"ballestero":
			ci.draw_circle(pos + Vector2(0, 3), 14.0, Color(0, 0, 0, 0.3))
			_poly(ci, [[-8, 0], [-10, -26], [0, -32], [10, -26], [8, 0]], p, 1.0, 1.0, Color(0.25, 0.4, 0.28))
			ci.draw_circle(p + Vector2(0, -38), 7.0, skin)
			ci.draw_line(p + Vector2(-26, -26), p + Vector2(6, -26), Color(0.4, 0.28, 0.15), 3.0)
			ci.draw_line(p + Vector2(-26, -36), p + Vector2(-26, -16), Color(0.8, 0.8, 0.8), 2.0)
		"clerigo":
			ci.draw_circle(pos + Vector2(0, 3), 15.0, Color(0, 0, 0, 0.3))
			_poly(ci, [[-14, 0], [-8, -32], [0, -38], [8, -32], [14, 0]], p, 1.0, 1.0, Color(0.92, 0.9, 0.78).lerp(Color(1, 1, 1), flash))
			ci.draw_circle(p + Vector2(0, -44), 7.0, skin)
			ci.draw_arc(p + Vector2(0, -56), 8.0, 0.0, TAU, 16, Color(1.0, 0.9, 0.3), 2.0)
			ci.draw_line(p + Vector2(-18, -30), p + Vector2(-18, -6), Color(0.9, 0.8, 0.3), 2.0)
			ci.draw_line(p + Vector2(-24, -22), p + Vector2(-12, -22), Color(0.9, 0.8, 0.3), 2.0)
		"verdugo":
			ci.draw_circle(pos + Vector2(0, 4), 30.0, Color(0, 0, 0, 0.35))
			_poly(ci, [[-22, 0], [-26, -50], [-12, -76], [0, -84], [12, -76], [26, -50], [22, 0]], p, 1.0, 1.0, Color(0.18, 0.12, 0.12).lerp(Color(1, 1, 1), flash))
			ci.draw_circle(p + Vector2(0, -88), 12.0, Color(0.1, 0.08, 0.08))
			ci.draw_circle(p + Vector2(-4, -88), 2.5, Color(1.0, 0.2, 0.1))
			ci.draw_line(p + Vector2(-30, -10), p + Vector2(-38, -100), Color(0.4, 0.3, 0.2), 4.0)
			_poly(ci, [[-38, -100], [-62, -92], [-60, -66], [-38, -72]], p, 1.0, 1.0, Color(0.7, 0.7, 0.72))
		"inquisidor":
			ci.draw_circle(pos + Vector2(0, 4), 28.0, Color(0, 0, 0, 0.35))
			_poly(ci, [[-20, 0], [-18, -60], [-8, -80], [8, -80], [18, -60], [20, 0]], p, 1.0, 1.0, Color(0.85, 0.82, 0.7).lerp(Color(1, 1, 1), flash))
			_poly(ci, [[-10, -80], [0, -112], [10, -80]], p, 1.0, 1.0, Color(0.8, 0.65, 0.15))
			ci.draw_circle(p + Vector2(0, -74), 8.0, skin)
			ci.draw_line(p + Vector2(-26, -10), p + Vector2(-26, -70), Color(0.5, 0.4, 0.2), 3.0)
			ci.draw_circle(p + Vector2(-26, -74), 9.0, Color(0.9, 0.8, 0.3))
		_:
			ci.draw_circle(p + Vector2(0, -20), 12.0, Color(1, 0, 1))


static func draw_door(ci: CanvasItem, rect: Rect2, hp_frac: float, shake: float) -> void:
	var r: Rect2 = Rect2(rect.position + Vector2(shake, 0), rect.size)
	ci.draw_rect(r, Color(0.22, 0.14, 0.1))
	ci.draw_rect(r, OUTLINE, false, 3.0)
	var cx: float = r.position.x + r.size.x * 0.5
	for i in 4:
		var y: float = r.position.y + 20.0 + i * (r.size.y - 40.0) / 3.0
		ci.draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(0.4, 0.3, 0.2), 4.0)
	ci.draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), OUTLINE, 3.0)
	# grietas según daño
	var cracks: int = int((1.0 - hp_frac) * 8.0)
	for i in cracks:
		var y2: float = r.position.y + 30.0 + i * 40.0
		ci.draw_line(Vector2(r.end.x - 4, y2), Vector2(r.end.x - 22 - (i % 3) * 6, y2 + 24), Color(1.0, 0.3, 0.1), 2.0)
	ci.draw_circle(Vector2(cx, r.position.y + r.size.y * 0.5), 9.0, Color(1.0, 0.45, 0.1, 0.4 + 0.5 * (1.0 - hp_frac)))
