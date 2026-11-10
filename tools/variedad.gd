extends SceneTree
## Cuánto se parecen dos partidas seguidas: oleadas (distancia de composición), augurios y draft.
## godot --headless --path . -s res://tools/variedad.gd
const Sim = preload("res://scripts/sim.gd")

func comp(w: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for g in w["spawns"]:
		d[String(g["kind"])] = int(d.get(String(g["kind"]), 0)) + int(g["count"])
	return d

func dist(a: Dictionary, b: Dictionary) -> float:
	var keys: Dictionary = {}
	for k in a: keys[k] = true
	for k in b: keys[k] = true
	var diff: float = 0.0
	var tot: float = 0.0
	for k in keys:
		diff += absf(float(a.get(k, 0)) - float(b.get(k, 0)))
		tot += float(a.get(k, 0)) + float(b.get(k, 0))
	return diff / maxf(1.0, tot)

func _init() -> void:
	var n: int = 60
	var dsum: float = 0.0
	var same_aug: float = 0.0
	var same_draft: float = 0.0
	var cnt: int = 0
	for i in n:
		var a = Sim.new(100 + i)
		var b = Sim.new(101 + i)
		for s in [a, b]:
			s.remix_enabled = true
			s.augurs_enabled = true
			s.draft_enabled = true
			s.reset()
		for wi in range(1, 6):
			dsum += dist(comp(a.WAVES[wi]), comp(b.WAVES[wi]))
			cnt += 1
		for s2 in [a, b]:
			s2.wave_index = 1
			s2._offer_augurs()
			s2.make_draft()
		var inter: int = 0
		for x in a.augur_offer:
			if x in b.augur_offer: inter += 1
		same_aug += float(inter) / 2.0
		var di: int = 0
		for o in a.draft:
			for o2 in b.draft:
				if o["id"] == o2["id"]: di += 1
		same_draft += float(di) / 3.0
	print("distancia media de composición por oleada (0 = igual, 1 = nada en común): %.2f" % (dsum / cnt))
	print("augurios repetidos entre dos partidas: %.0f%%" % (100.0 * same_aug / n))
	print("opciones de draft repetidas (primera elección): %.0f%%" % (100.0 * same_draft / n))
	quit()
