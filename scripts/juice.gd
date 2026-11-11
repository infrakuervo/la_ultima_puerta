extends RefCounted
## Sensación de impacto, solo vista: partículas, números de daño, destello de los golpeados,
## temblor de cámara suave (trauma con ruido) y pausa breve en los golpes grandes.
## main.gd lo alimenta con los eventos de la simulación y lo dibuja en su _draw().

var particles: Array = []      # {p, v, life, ttl, col, size, g, drag}
var numbers: Array = []        # {p, text, col, t, ttl, size, id, amount}
var flashes: Dictionary = {}   # id de enemigo -> tiempo restante del destello
var trauma: float = 0.0
var hitstop: float = 0.0
var shake_scale: float = 1.0   # opción del jugador (0 = sin temblor)
var _t: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var embers: Array = []         # brasas del ambiente

const MAX_PARTICLES: int = 600


func _init() -> void:
	_noise.seed = 7
	_noise.frequency = 1.0
	_rng.seed = 99
	for i in 26:
		embers.append({"p": Vector2(_rng.randf_range(0, 1280), _rng.randf_range(100, 600)), "s": _rng.randf_range(8.0, 24.0), "ph": _rng.randf() * TAU, "r": _rng.randf_range(1.0, 2.4)})


func update(delta: float) -> void:
	_t += delta
	hitstop = maxf(0.0, hitstop - delta)
	trauma = maxf(0.0, trauma - delta * 1.6)
	var keep: Array = []
	for p in particles:
		p["life"] += delta
		if p["life"] >= p["ttl"]:
			continue
		p["v"] = p["v"] * (1.0 - float(p["drag"]) * delta) + Vector2(0, float(p["g"])) * delta
		p["p"] += p["v"] * delta
		keep.append(p)
	particles = keep
	var keepn: Array = []
	for n in numbers:
		n["t"] += delta
		if n["t"] < n["ttl"]:
			keepn.append(n)
	numbers = keepn
	for k in flashes.keys():
		flashes[k] -= delta
		if flashes[k] <= 0.0:
			flashes.erase(k)
	for e in embers:
		e["p"].y -= e["s"] * delta
		e["p"].x += sin(_t * 0.7 + e["ph"]) * 6.0 * delta
		if e["p"].y < 90.0:
			e["p"] = Vector2(_rng.randf_range(0, 1280), 600.0)


## Desplazamiento de cámara: crece con el cuadrado del trauma y usa ruido suave, no saltos al azar.
func offset() -> Vector2:
	var k: float = trauma * trauma * shake_scale
	if k <= 0.001:
		return Vector2.ZERO
	return Vector2(_noise.get_noise_2d(_t * 28.0, 0.0), _noise.get_noise_2d(0.0, _t * 28.0)) * 14.0 * k


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func stop(sec: float) -> void:
	hitstop = maxf(hitstop, sec)


func flash(id: int, sec: float = 0.12) -> void:
	flashes[id] = sec


func flash_of(id: int) -> float:
	return clampf(float(flashes.get(id, 0.0)) / 0.12, 0.0, 1.0)


func burst(p: Vector2, n: int, col: Color, speed: float, ttl: float, size: float = 3.0, g: float = 300.0, up: float = 0.0, spread: float = TAU) -> void:
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var a: float = -PI * 0.5 + _rng.randf_range(-spread * 0.5, spread * 0.5)
		var sp: float = speed * _rng.randf_range(0.4, 1.0)
		var c: Color = col
		c = c.lightened(_rng.randf_range(-0.15, 0.2))
		particles.append({"p": p, "v": Vector2(cos(a), sin(a)) * sp + Vector2(0, -up), "life": 0.0,
			"ttl": ttl * _rng.randf_range(0.6, 1.2), "col": c, "size": size * _rng.randf_range(0.6, 1.3), "g": g, "drag": 1.5})


## Número de daño. Si el mismo enemigo recibe otro golpe enseguida, se suman en el mismo número.
func number(p: Vector2, amount: float, id: int, col: Color = Color(1.0, 0.95, 0.85), big: bool = false) -> void:
	if amount < 1.0:
		return
	for n in numbers:
		if id >= 0 and n["id"] == id and n["t"] < 0.25:
			n["amount"] += amount
			n["text"] = str(int(round(n["amount"])))
			n["t"] = minf(n["t"], 0.05)
			n["size"] = mini(30, 16 + int(n["amount"] / 12.0))
			return
	numbers.append({"p": p + Vector2(_rng.randf_range(-10, 10), 0), "text": str(int(round(amount))), "col": col, "t": 0.0,
		"ttl": 0.8 if not big else 1.1, "size": (24 if big else mini(30, 16 + int(amount / 12.0))), "id": id, "amount": amount})


func draw_back(ci: CanvasItem) -> void:
	for e in embers:
		var a: float = 0.25 + 0.2 * sin(_t * 2.0 + e["ph"])
		ci.draw_circle(e["p"], e["r"], Color(1.0, 0.55, 0.2, a))


func draw_front(ci: CanvasItem, font: Font) -> void:
	for p in particles:
		var k: float = float(p["life"]) / float(p["ttl"])
		var c: Color = p["col"]
		c.a *= 1.0 - k
		ci.draw_circle(p["p"], float(p["size"]) * (1.0 - 0.5 * k), c)
	for n in numbers:
		var k2: float = float(n["t"]) / float(n["ttl"])
		var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - float(n["t"]) / 0.08)
		var pos: Vector2 = n["p"] + Vector2(0, -38.0 * k2 - 6.0)
		var c2: Color = n["col"]
		c2.a = 1.0 - maxf(0.0, (k2 - 0.6) / 0.4)
		var sz: int = int(float(n["size"]) * pop)
		ci.draw_string_outline(font, pos + Vector2(-40, 0), String(n["text"]), HORIZONTAL_ALIGNMENT_CENTER, 80.0, sz, 4, Color(0, 0, 0, c2.a * 0.8))
		ci.draw_string(font, pos + Vector2(-40, 0), String(n["text"]), HORIZONTAL_ALIGNMENT_CENTER, 80.0, sz, c2)
