extends RefCounted
## Sonidos procedurales (sin archivos de audio). Cada aviso de forma tiene un sonido propio:
## inhalar (Horno), agacharse y saltar (Trueno), campana, morder (Presa), disparo del Ojo.

const RATE: int = 22050
var streams: Dictionary = {}


func _init() -> void:
	# nombre: (f0, f1, duración, volumen, onda 0 seno/1 cuadrada/2 sierra/3 ruido, mezcla de ruido, ataque)
	streams["click"] = make(800.0, 700.0, 0.04, 0.4, 0, 0.0, 0.0)
	streams["buy"] = make(500.0, 900.0, 0.14, 0.5, 1, 0.0, 0.0)
	streams["garra"] = make(420.0, 110.0, 0.14, 0.5, 2, 0.2, 0.0)
	streams["guardia"] = make(150.0, 320.0, 0.3, 0.55, 1, 0.1, 0.05)
	streams["bite"] = make(220.0, 90.0, 0.08, 0.35, 2, 0.4, 0.0)
	streams["hit"] = make(300.0, 150.0, 0.05, 0.25, 3, 0.8, 0.0)
	streams["kill"] = make(520.0, 240.0, 0.12, 0.4, 0, 0.1, 0.0)
	streams["presa_windup"] = make(150.0, 95.0, 0.35, 0.5, 1, 0.2, 0.1)
	streams["presa"] = make(110.0, 55.0, 0.18, 0.6, 2, 0.3, 0.0)
	streams["horno_inhale"] = make(50.0, 240.0, 0.6, 0.6, 3, 0.7, 0.4)
	streams["horno_spit"] = make(320.0, 60.0, 0.45, 0.7, 3, 0.8, 0.0)
	streams["trueno_crouch"] = make(110.0, 330.0, 0.5, 0.5, 2, 0.1, 0.5)
	streams["trueno_jump"] = make(320.0, 820.0, 0.22, 0.5, 1, 0.0, 0.0)
	streams["trueno_land"] = make(130.0, 40.0, 0.38, 0.8, 3, 0.7, 0.0)
	streams["ojo_shot"] = make(950.0, 1500.0, 0.1, 0.35, 0, 0.0, 0.0)
	streams["ojo_chain"] = make(1300.0, 380.0, 0.2, 0.45, 1, 0.1, 0.0)
	streams["ojo_mark"] = make(1100.0, 1100.0, 0.12, 0.35, 0, 0.0, 0.0)
	streams["bell"] = make(660.0, 655.0, 0.8, 0.55, 4, 0.0, 0.0)
	streams["door_hit"] = make(80.0, 35.0, 0.3, 0.8, 3, 0.7, 0.0)
	streams["shot"] = make(520.0, 300.0, 0.1, 0.3, 3, 0.5, 0.0)
	streams["heal"] = make(600.0, 950.0, 0.22, 0.35, 0, 0.0, 0.1)
	streams["mutate"] = make(90.0, 900.0, 1.0, 0.7, 2, 0.15, 0.7)
	streams["horn"] = make(58.0, 52.0, 0.9, 0.7, 1, 0.1, 0.2)
	streams["revive"] = make(220.0, 440.0, 0.5, 0.5, 0, 0.0, 0.2)
	streams["down"] = make(260.0, 70.0, 0.4, 0.55, 2, 0.2, 0.0)
	streams["brasa_cast"] = make(180.0, 520.0, 0.5, 0.5, 2, 0.3, 0.2)
	streams["rayo"] = make(1700.0, 260.0, 0.16, 0.5, 1, 0.3, 0.0)
	streams["level"] = make(420.0, 900.0, 0.25, 0.45, 0, 0.0, 0.1)
	streams["win"] = make(400.0, 800.0, 1.1, 0.5, 1, 0.0, 0.0)
	streams["lose"] = make(220.0, 40.0, 1.3, 0.7, 2, 0.3, 0.0)
	# Capas (f0, f1, dur, vol, onda, ruido, ataque, retardo): élites, bestias nuevas y golpes grandes.
	streams["big_kill"] = mix([[90.0, 30.0, 0.5, 0.8, 3, 0.6, 0.0, 0.0], [300.0, 80.0, 0.3, 0.5, 2, 0.1, 0.0, 0.0]])
	streams["elite"] = mix([[110.0, 98.0, 0.7, 0.55, 1, 0.05, 0.15, 0.0], [165.0, 147.0, 0.7, 0.35, 1, 0.0, 0.15, 0.0]])
	streams["lumbrero"] = mix([[880.0, 880.0, 0.6, 0.3, 0, 0.0, 0.05, 0.0], [1320.0, 1320.0, 0.6, 0.22, 0, 0.0, 0.05, 0.08], [1760.0, 1760.0, 0.5, 0.15, 0, 0.0, 0.05, 0.16]])
	streams["tirador_aim"] = mix([[180.0, 260.0, 0.12, 0.4, 2, 0.3, 0.0, 0.0], [190.0, 280.0, 0.12, 0.4, 2, 0.3, 0.0, 0.2], [200.0, 300.0, 0.12, 0.4, 2, 0.3, 0.0, 0.4], [210.0, 320.0, 0.12, 0.4, 2, 0.3, 0.0, 0.6]])
	streams["tirador_shot"] = mix([[900.0, 120.0, 0.18, 0.6, 2, 0.2, 0.0, 0.0], [200.0, 60.0, 0.25, 0.5, 3, 0.7, 0.0, 0.0]])
	streams["tajo_wind"] = mix([[60.0, 240.0, 0.8, 0.5, 3, 0.9, 0.7, 0.0], [70.0, 110.0, 0.8, 0.3, 2, 0.0, 0.7, 0.0]])
	streams["tajo_sweep"] = mix([[500.0, 70.0, 0.35, 0.7, 3, 0.9, 0.05, 0.0], [120.0, 40.0, 0.45, 0.6, 2, 0.2, 0.0, 0.05]])
	streams["campana_ring"] = mix([[220.0, 218.0, 1.6, 0.6, 4, 0.0, 0.0, 0.0], [110.0, 109.0, 1.6, 0.4, 4, 0.0, 0.0, 0.0], [70.0, 40.0, 0.4, 0.5, 3, 0.8, 0.0, 0.0]])
	streams["alacran_grab"] = mix([[1800.0, 900.0, 0.05, 0.5, 3, 0.9, 0.0, 0.0], [1600.0, 800.0, 0.05, 0.5, 3, 0.9, 0.0, 0.09], [140.0, 70.0, 0.25, 0.5, 2, 0.2, 0.0, 0.1]])
	streams["sapo_windup"] = mix([[90.0, 150.0, 0.5, 0.5, 0, 0.0, 0.3, 0.0], [95.0, 160.0, 0.5, 0.3, 2, 0.0, 0.3, 0.0]])
	streams["sapo_spit"] = mix([[260.0, 70.0, 0.3, 0.6, 0, 0.3, 0.0, 0.0], [120.0, 50.0, 0.4, 0.5, 3, 0.6, 0.0, 0.12]])
	streams["manta_dive"] = mix([[700.0, 300.0, 0.4, 0.35, 0, 0.2, 0.3, 0.0], [710.0, 310.0, 0.4, 0.25, 0, 0.2, 0.3, 0.03]])
	streams["manta_glide"] = mix([[200.0, 1200.0, 0.5, 0.45, 3, 0.85, 0.2, 0.0], [300.0, 600.0, 0.5, 0.25, 0, 0.0, 0.2, 0.0]])


static func make(f0: float, f1: float, dur: float, vol: float, wave: int, noise_mix: float, attack: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	var phase2: float = 0.0
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = int(f0 * 31.0 + dur * 1000.0 + wave)
	for i in n:
		var k: float = float(i) / float(maxi(n - 1, 1))
		var f: float = lerpf(f0, f1, k)
		phase += TAU * f / float(RATE)
		var v: float = 0.0
		match wave:
			0:
				v = sin(phase)
			1:
				v = 1.0 if sin(phase) >= 0.0 else -1.0
				v *= 0.6
			2:
				v = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			3:
				v = rnd.randf() * 2.0 - 1.0
			4:
				# campana: parciales inarmónicos
				phase2 += TAU * f * 2.76 / float(RATE)
				v = sin(phase) * 0.6 + sin(phase2) * 0.4
		if noise_mix > 0.0 and wave != 3:
			v = lerpf(v, rnd.randf() * 2.0 - 1.0, noise_mix)
		var env: float = pow(1.0 - k, 2.0)
		if attack > 0.0 and k < attack:
			env *= k / attack
		var sample: int = int(clampf(v * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, sample)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Mezcla varias capas; cada una: [f0, f1, dur, vol, onda, ruido, ataque, retardo].
static func mix(layers: Array) -> AudioStreamWAV:
	var total: float = 0.0
	for l in layers:
		total = maxf(total, float(l[2]) + float(l[7]))
	var n: int = int(RATE * total)
	var acc: PackedFloat32Array = PackedFloat32Array()
	acc.resize(n)
	for l in layers:
		var w: AudioStreamWAV = make(float(l[0]), float(l[1]), float(l[2]), float(l[3]), int(l[4]), float(l[5]), float(l[6]))
		var off: int = int(RATE * float(l[7]))
		var cnt: int = w.data.size() / 2
		for i in cnt:
			if off + i < n:
				acc[off + i] += float(w.data.decode_s16(i * 2)) / 32000.0
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var peak: float = 0.0
	for i in n:
		peak = maxf(peak, absf(acc[i]))
	var g: float = 1.0 if peak <= 0.95 else 0.95 / peak
	for i in n:
		data.encode_s16(i * 2, int(clampf(acc[i] * g, -1.0, 1.0) * 32000.0))
	var out: AudioStreamWAV = AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = RATE
	out.stereo = false
	out.data = data
	return out
