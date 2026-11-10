extends RefCounted
## Música procedural en tiempo real (sin archivos): se sintetiza muestra a muestra en un
## AudioStreamGenerator, así nunca suena igual dos veces.
## - Drone grave (dos sierras desafinadas con filtro) sobre una progresión frigia de 4 compases.
## - Campanas que improvisan sobre la escala (más presentes en calma).
## - En combate entran bajo en corcheas, bombo y caja; el tempo sube con la intensidad.
## main.gd pone `target` (0 = menú/calma, 1 = combate fuerte) y llama a update() cada fotograma.

const RATE: float = 22050.0
const SCALE: Array = [0, 1, 4, 5, 7, 8, 10]          # frigio dominante (re, mi bemol, fa#, sol, la, si bemol, do)
const PROG: Array = [0, 1, 0, -2]                    # i - bII - i - bVII
const BASS_PAT: Array = [1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1]
const ROOT: int = 38                                 # re grave (MIDI)

var player: AudioStreamPlayer = null
var playback: AudioStreamGeneratorPlayback = null
var target: float = 0.0
var intensity: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _beat: float = 0.0
var _step: int = -1
var _bar: int = 0
var _chord: int = 0
var _t: float = 0.0
# drone
var _pd1: float = 0.0
var _pd2: float = 0.0
var _pd3: float = 0.0
var _lp: float = 0.0
# campana
var _pb: float = 0.0
var _fb: float = 440.0
var _ab: float = 0.0
var _mel: int = 7
# bajo
var _pq: float = 0.0
var _fq: float = 110.0
var _aq: float = 0.0
var _lq: float = 0.0
# bombo y caja
var _pk: float = 0.0
var _fk: float = 50.0
var _ak: float = 0.0
var _as: float = 0.0
var _ls: float = 0.0


func setup(node: Node, bus: String) -> void:
	rng.randomize()
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.5
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.bus = bus
	player.volume_db = -7.0   # por debajo de los efectos: acompaña, no tapa
	node.add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func update(delta: float) -> void:
	intensity = move_toward(intensity, target, delta * 0.3)
	if playback == null:
		return
	var n: int = mini(playback.get_frames_available(), 4096)
	if n <= 0:
		return
	playback.push_buffer(render(n))


## Sintetiza `n` muestras estéreo (también lo usan las pruebas, sin reproductor).
func render(n: int) -> PackedVector2Array:
	var buf: PackedVector2Array = PackedVector2Array()
	buf.resize(n)
	var dt: float = 1.0 / RATE
	var fight: float = smoothstep(0.25, 0.7, intensity)
	var bpm: float = lerpf(64.0, 126.0, intensity)
	var beat_inc: float = dt * bpm / 60.0
	var calm_bell: float = 0.26 * (1.0 - 0.55 * fight)
	# decaimientos por muestra
	var db: float = exp(-dt / 1.1)
	var dq: float = exp(-dt / 0.16)
	var dk: float = exp(-dt / 0.22)
	var dkf: float = exp(-dt / 0.05)
	var ds: float = exp(-dt / 0.09)
	var lp_a: float = 1.0 - exp(-TAU * (220.0 + 380.0 * intensity) / RATE)
	var lq_a: float = 1.0 - exp(-TAU * 700.0 / RATE)
	for i in n:
		_t += dt
		_beat += beat_inc
		var s16: int = floori(_beat * 4.0)
		if s16 != _step:
			_step = s16
			_on_step(s16, fight)
		# drone
		var fr: float = midi(float(ROOT + _chord))
		_pd1 = fposmod(_pd1 + fr * dt, 1.0)
		_pd2 = fposmod(_pd2 + fr * 1.006 * dt, 1.0)
		_pd3 = fposmod(_pd3 + fr * 1.5 * dt, 1.0)
		var raw: float = (2.0 * _pd1 - 1.0) + (2.0 * _pd2 - 1.0) + 0.6 * (2.0 * _pd3 - 1.0)
		_lp += (raw - _lp) * lp_a
		var drone: float = _lp * 0.075 * (0.8 + 0.2 * sin(_t * 0.37))
		# campana
		_pb = fposmod(_pb + _fb * dt, 1.0)
		_ab *= db
		var bell: float = (sin(TAU * _pb) + 0.35 * sin(TAU * fposmod(_pb * 2.76, 1.0))) * _ab * calm_bell
		# bajo
		_pq = fposmod(_pq + _fq * dt, 1.0)
		_aq *= dq
		_lq += ((1.0 if _pq < 0.5 else -1.0) - _lq) * lq_a
		var bass: float = _lq * _aq * 0.2 * fight
		# bombo
		_fk = 42.0 + (_fk - 42.0) * dkf
		_pk = fposmod(_pk + _fk * dt, 1.0)
		_ak *= dk
		var kick: float = sin(TAU * _pk) * _ak * 0.55 * fight
		# caja: ruido filtrado
		_as *= ds
		_ls += (rng.randf_range(-1.0, 1.0) - _ls) * 0.45
		var snare: float = _ls * _as * 0.22 * fight
		var mix: float = clampf((drone + bell + bass + kick + snare) * 0.8, -1.0, 1.0)
		buf[i] = Vector2(mix + bell * 0.15, mix - bell * 0.15)
	return buf


func _on_step(s: int, fight: float) -> void:
	var k: int = s % 16
	if k == 0:
		_bar += 1
		_chord = int(PROG[_bar % PROG.size()])
	# campana: cada dos tiempos (más a menudo en combate), con pasos cortos sobre la escala
	if k % 8 == 0 or (fight > 0.5 and k % 4 == 2 and rng.randf() < 0.3):
		if rng.randf() < 0.85:
			_mel = clampi(_mel + rng.randi_range(-2, 2), 0, 13)
			var deg: int = int(SCALE[_mel % 7]) + 12 * (_mel / 7)
			_fb = midi(float(ROOT + 24 + _chord + deg))
			_ab = 1.0
	if fight <= 0.01:
		return
	if BASS_PAT[k] == 1:
		var off: int = 12
		if k == 7 or k == 15:
			off = 19 if rng.randf() < 0.5 else 13
		_fq = midi(float(ROOT + off + _chord))
		_aq = 1.0
	if k == 0 or k == 8 or (k == 10 and fight > 0.7):
		_fk = 150.0
		_ak = 1.0
	if k == 4 or k == 12 or (_bar % 4 == 3 and k >= 13 and fight > 0.6):
		_as = 1.0 if k < 13 else 0.7
