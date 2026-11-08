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
	streams["win"] = make(400.0, 800.0, 1.1, 0.5, 1, 0.0, 0.0)
	streams["lose"] = make(220.0, 40.0, 1.3, 0.7, 2, 0.3, 0.0)


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
