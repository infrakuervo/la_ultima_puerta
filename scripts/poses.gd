extends RefCounted
## Animación por código de bestias y enemigos, solo vista: respiración en reposo, trote al moverse,
## embestida al atacar y retroceso al recibir. También lleva los reproductores de fotogramas
## (Anim) de las bestias que los tienen (Sabueso/Tizón y Horno).
## main.gd lo actualiza cada fotograma leyendo la simulación (posiciones y enfriamientos) y le
## pasa los eventos de ataque. La simulación no sabe nada de esto.

const Anim = preload("res://scripts/anim.gd")

const ATTACK_TIME: float = 0.26      # duración de la embestida por código
const MOVE_SPEED: float = 12.0       # px/s suavizados a partir de los que se considera que anda
const CREATURE_ATTACKS: Array = ["bite", "presa", "horno_spit", "trueno_land", "sapo_spit",
	"manta_dive", "ojo_shot", "stone_break", "swarm", "hook"]
const BITE_CLIP_EVENTS: Array = ["bite", "presa", "horno_spit"]

var units: Dictionary = {}   # id -> {x, vel, attack, cd, facing, seen}
var anims: Dictionary = {}   # id de bestia -> Anim (solo las que tienen fotogramas)


func reset() -> void:
	units.clear()
	anims.clear()


func _unit(id: int, x: float) -> Dictionary:
	if not units.has(id):
		units[id] = {"x": x, "vel": 0.0, "attack": 0.0, "cd": 0.0, "facing": 1.0, "seen": true}
	return units[id]


## Lee la simulación una vez por fotograma de vista. `dt`: tiempo de juego simulado en este
## fotograma (0 fuera de combate o en pausa); `delta`: tiempo real; `rate`: velocidad x1/x2.
func update(sim, dt: float, delta: float, rate: float = 1.0) -> void:
	for u in units.values():
		u["seen"] = false
		u["attack"] = maxf(0.0, float(u["attack"]) - delta)
	for c in sim.creatures:
		var id: int = int(c["id"])
		var u: Dictionary = _unit(id, float(c["x"]))
		_track(u, float(c["x"]), dt)
		var fwd: float = 1.0
		if float(u["vel"]) < -MOVE_SPEED * 2.0:
			fwd = -1.0   # vuelve a casa: se da la vuelta mientras corre
		u["facing"] = fwd
		if Anim.character(String(c["kind"])).is_empty():
			anims.erase(id)
			continue
		var a = anims.get(id)
		if a == null or a.ch != String(c["kind"]):
			a = Anim.new(String(c["kind"]))
			anims[id] = a
		a.set_base("carrera" if moving(id) else "")
		a.update(delta * rate)
	for e in sim.enemies:
		var id2: int = int(e["id"])
		var u2: Dictionary = _unit(id2, float(e["x"]))
		_track(u2, float(e["x"]), dt)
		u2["facing"] = -1.0
		# los enemigos no avisan al atacar: el enfriamiento salta hacia arriba al golpear
		var cd: float = float(e["cd"])
		if cd > float(u2["cd"]) + 0.05 and dt > 0.0:
			u2["attack"] = ATTACK_TIME
		u2["cd"] = cd
	for id3 in units.keys():
		if not units[id3]["seen"]:
			units.erase(id3)
			anims.erase(id3)


func _track(u: Dictionary, x: float, dt: float) -> void:
	u["seen"] = true
	if dt > 0.0:
		var v: float = (x - float(u["x"])) / dt
		u["vel"] = lerpf(float(u["vel"]), v, clampf(dt * 10.0, 0.0, 1.0))
	elif dt == 0.0 and absf(x - float(u["x"])) > 0.5:
		u["vel"] = 0.0   # recolocada a mano entre oleadas: sin trote
	u["x"] = x


func on_event(ev: Dictionary, sim) -> void:
	var t: String = ev["t"]
	if not (t in CREATURE_ATTACKS) or not ev.has("id"):
		return
	var id: int = int(ev["id"])
	if units.has(id):
		units[id]["attack"] = ATTACK_TIME
	if t in BITE_CLIP_EVENTS and anims.has(id):
		anims[id].play("mordisco")


func moving(id: int) -> bool:
	return units.has(id) and absf(float(units[id]["vel"])) > MOVE_SPEED


func facing(id: int) -> float:
	return float(units[id]["facing"]) if units.has(id) else 1.0


## Fotograma animado de una bestia para Art (opts["frame"]), o {} para el sprite fijo.
func frame_of(id: int) -> Dictionary:
	var a = anims.get(id)
	return a.draw_opts() if a != null else {}


func clip_of(id: int) -> String:
	var a = anims.get(id)
	return String(a.clip) if a != null else ""


## Transformación de dibujo de una unidad con los pies en el origen: {shift, rot, scale}.
## look: 1 mira a la derecha (bestias), -1 a la izquierda (enemigos). hit: destello 0..1.
## animated: ya lleva fotogramas (sin respirar ni trotar por código).
func pose(id: int, clock: float, look: float, hit: float, windup: bool, animated: bool, attack_clip: bool) -> Dictionary:
	var u: Dictionary = units.get(id, {})
	var mv: bool = moving(id)
	var ph: float = clock * 15.0 + float(id) * 1.7
	var stride: float = sin(ph) if mv and not animated else 0.0
	var breath: float = sin(clock * 3.6 + float(id)) if not mv and not animated else 0.0
	var k: float = 1.0 - float(u.get("attack", 0.0)) / ATTACK_TIME
	var lunge: float = sin(clampf(k, 0.0, 1.0) * PI) if float(u.get("attack", 0.0)) > 0.0 and not attack_clip else 0.0
	var hk: float = clampf(hit, 0.0, 1.0)
	var wu: float = 1.0 if windup else 0.0
	var shift: Vector2 = Vector2(look * (16.0 * lunge - 9.0 * hk - 4.0 * wu), -absf(stride) * 5.0)
	var rot: float = look * (0.05 * stride + 0.10 * lunge - 0.08 * hk - 0.04 * wu)
	var sc: Vector2 = Vector2(1.0 + 0.08 * lunge + 0.05 * hk - 0.012 * breath,
		1.0 + 0.026 * breath + 0.04 * absf(stride) - 0.05 * hk - 0.08 * wu)
	return {"shift": shift, "rot": rot, "scale": sc}
