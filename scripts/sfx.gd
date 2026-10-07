extends Node
## Sound-effect bank. The sounds are short enough to synthesize when the game starts, so the
## game has no audio files at all.

const RATE := 22050

var muted := false

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 11
	_streams = {
		"shoot": _wav(_sweep(900.0, 320.0, 0.09, 0.13, true)),
		"flak": _wav(_sweep(620.0, 240.0, 0.07, 0.08, true)),
		"hit": _wav(_sweep(320.0, 160.0, 0.05, 0.16, true)),
		"pop": _wav(_mix(_noise(0.18, 0.6, 16.0, 0.35), _sweep(520.0, 90.0, 0.18, 0.18, true))),
		"boom": _wav(_mix(_noise(0.55, 0.14, 6.0, 0.8), _sweep(150.0, 40.0, 0.55, 0.3, false))),
		"crunch": _wav(_mix(_noise(0.32, 0.3, 9.0, 0.55), _sweep(110.0, 50.0, 0.3, 0.25, false))),
		"hurt": _wav(_sweep(420.0, 70.0, 0.45, 0.24, true)),
		"bomb": _wav(_sweep(760.0, 380.0, 0.13, 0.05, false)),
		"beam": _wav(_sweep(1900.0, 180.0, 0.4, 0.16, true)),
		"zap": _wav(_mix(_noise(0.2, 0.9, 10.0, 0.2), _sweep(2400.0, 900.0, 0.2, 0.08, true))),
		"missile": _wav(_noise(0.45, 0.07, 5.0, 0.7)),
		"dome": _wav(_tones([1318.5, 1975.5], 0.0, 0.25, 12.0, 0.12)),
		"hail": _wav(_noise(1.2, 0.5, 2.0, 0.22)),
		"ui": _wav(_tones([1200.0], 0.0, 0.06, 40.0, 0.2)),
		"pick": _wav(_tones([523.3, 659.3, 784.0, 1046.5], 0.06, 0.6, 6.0, 0.15)),
		"wave": _wav(_tones([392.0, 392.0, 523.3, 659.3], 0.11, 0.8, 5.0, 0.15)),
		"clear": _wav(_tones([659.3, 784.0, 987.8, 1318.5], 0.08, 0.9, 4.0, 0.15)),
		"crate": _wav(_tones([987.8, 1318.5, 1568.0], 0.05, 0.4, 8.0, 0.15)),
		"repair": _wav(_tones([440.0, 554.4, 659.3], 0.07, 0.45, 8.0, 0.14)),
		"over": _wav(_tones([392.0, 349.2, 311.1, 196.0], 0.24, 1.6, 2.5, 0.2)),
		"alarm": _wav(_sweep(520.0, 880.0, 0.5, 0.12, true)),
		"march0": _wav(_sweep(98.0, 92.0, 0.1, 0.4, false)),
		"march1": _wav(_sweep(87.3, 82.0, 0.1, 0.4, false)),
		"march2": _wav(_sweep(77.8, 73.0, 0.1, 0.4, false)),
		"march3": _wav(_sweep(73.4, 69.0, 0.1, 0.4, false)),
	}
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null or muted:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * seconds))
	return b


## Bell-like notes, each starting `gap` seconds after the one before.
func _tones(freqs: Array, gap: float, seconds: float, decay: float, vol: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for k in freqs.size():
		var from := int(k * gap * RATE)
		var w := TAU * float(freqs[k]) / RATE
		for i in range(from, b.size()):
			var t := float(i - from) / RATE
			b[i] += sin(w * (i - from)) * exp(-t * decay) * minf(t * 400.0, 1.0) * vol
	return b


## A note sliding from one pitch to another: lasers, thumps and sirens. `square` makes it buzzy.
func _sweep(from_hz: float, to_hz: float, seconds: float, vol: float, square: bool) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ph := 0.0
	for i in b.size():
		var u := float(i) / b.size()
		ph += TAU * lerpf(from_hz, to_hz, u) / RATE
		var s := sin(ph)
		if square:
			s = signf(s) * 0.6 + s * 0.4
		b[i] = s * (1.0 - u) * minf(u * 60.0, 1.0) * vol
	return b


func _noise(seconds: float, lp_amount: float, decay: float, vol: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += lp_amount * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * exp(-t * decay) * minf(t * 200.0, 1.0) * vol
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a if a.size() >= b.size() else b
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
