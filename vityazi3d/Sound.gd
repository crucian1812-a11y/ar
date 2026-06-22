extends Node

# Procedural audio — all SFX and music synthesised in code (16-bit PCM).
const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer

var _swing: AudioStreamWAV
var _hit: AudioStreamWAV
var _jump: AudioStreamWAV
var _die: AudioStreamWAV
var _hurt: AudioStreamWAV
var _coin: AudioStreamWAV
var _buy: AudioStreamWAV
var _quest: AudioStreamWAV
var _bow: AudioStreamWAV

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -13.0
	add_child(_music)

	_swing = _whoosh(0.16, 1700.0, 700.0, 0.32)
	_hit = _clang(0.22, 0.6)
	_jump = _blip(0.16, 320.0, 680.0, 0.4)
	_die = _whoosh(0.36, 600.0, 90.0, 0.55)
	_hurt = _impact(0.18, 0.55)
	_coin = _chime([1318.0, 1760.0], 0.10, 0.5)
	_buy = _chime([523.0, 659.0, 784.0], 0.10, 0.5)
	_quest = _chime([523.0, 659.0, 784.0, 1047.0], 0.14, 0.6)
	_bow = _twang(0.26, 0.5)

	_music.stream = _make_music()
	_music.play()

func swing() -> void: _play(_swing)
func hit() -> void: _play(_hit)
func jump() -> void: _play(_jump)
func enemy_die() -> void: _play(_die)
func hurt() -> void: _play(_hurt)
func coin() -> void: _play(_coin)
func buy() -> void: _play(_buy)
func quest() -> void: _play(_quest)
func bow() -> void: _play(_bow)

func _play(s: AudioStreamWAV) -> void:
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()

# ---------------- synthesis ----------------

func _buf(n: int) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(n * 2)
	return d

func _put(data: PackedByteArray, i: int, val: float) -> void:
	var v := int(clampf(val, -1.0, 1.0) * 32767.0)
	data[i * 2] = v & 0xFF
	data[i * 2 + 1] = (v >> 8) & 0xFF

func _wav(data: PackedByteArray, loop: bool, n: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _whoosh(dur: float, f0: float, f1: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var env: float = (1.0 - t) * (1.0 - t)
		var f: float = lerp(f0, f1, t)
		phase += f / RATE
		var noise := randf() * 2.0 - 1.0
		_put(data, i, (sin(TAU * phase) * 0.45 + noise * 0.55) * env * vol)
	return _wav(data, false, n)

func _impact(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	for i in range(n):
		var t := float(i) / n
		var env: float = exp(-t * 18.0)
		var body := sin(TAU * 90.0 * (float(i) / RATE))
		_put(data, i, (body * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * env * vol)
	return _wav(data, false, n)

# metallic clang for weapon hits
func _clang(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	for i in range(n):
		var tt := float(i) / RATE
		var env := exp(-tt * 20.0)
		var s := sin(TAU * 540.0 * tt) * 0.5 + sin(TAU * 540.0 * 2.76 * tt) * 0.3 + sin(TAU * 540.0 * 5.2 * tt) * 0.2
		var transient := (randf() * 2.0 - 1.0) * exp(-tt * 70.0) * 0.6
		_put(data, i, (s * env + transient) * vol)
	return _wav(data, false, n)

func _blip(dur: float, f0: float, f1: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var env: float = sin(PI * t)
		var f: float = lerp(f0, f1, t)
		phase += f / RATE
		_put(data, i, sin(TAU * phase) * env * vol)
	return _wav(data, false, n)

# bowstring pluck
func _twang(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var env := exp(-t * 9.0)
		var f: float = lerp(440.0, 200.0, clampf(t * 3.0, 0.0, 1.0))
		phase += f / RATE
		_put(data, i, (sin(TAU * phase) * 0.7 + (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.4) * env * vol)
	return _wav(data, false, n)

# sequential bell-like notes
func _chime(freqs: Array, note: float, vol: float) -> AudioStreamWAV:
	var per := int(RATE * note)
	var n := per * freqs.size()
	var data := _buf(n)
	for k in range(freqs.size()):
		var f: float = freqs[k]
		for i in range(per):
			var t := float(i) / per
			var env := sin(PI * clampf(t * 1.1, 0.0, 1.0)) * exp(-t * 2.0)
			var s := sin(TAU * f * (float(i) / RATE)) + sin(TAU * f * 2.0 * (float(i) / RATE)) * 0.3
			_put(data, k * per + i, s * env * vol * 0.5)
	return _wav(data, true if false else false, n)

# gentle ambient: pentatonic melody + soft bass drone
func _make_music() -> AudioStreamWAV:
	var scale := [220.0, 247.0, 294.0, 330.0, 392.0, 440.0, 494.0]
	var seq := [0, 2, 4, 3, 5, 4, 2, 0, 3, 5, 6, 5, 4, 2, 3, 0]
	var bass := [110.0, 110.0, 147.0, 110.0, 165.0, 147.0, 110.0, 98.0]
	var note := 0.6
	var per := int(RATE * note)
	var n := per * seq.size()
	var data := _buf(n)
	for k in range(seq.size()):
		var f: float = scale[seq[k]]
		var bf: float = bass[k % bass.size()]
		for i in range(per):
			var t := float(i) / per
			var env := sin(PI * clampf(t, 0.0, 1.0)) * 0.55
			var mel := sin(TAU * f * (float(i) / RATE)) + sin(TAU * f * 2.0 * (float(i) / RATE)) * 0.2
			var idx := k * per + i
			var bassv := sin(TAU * bf * (float(idx) / RATE)) * 0.18
			var fifth := sin(TAU * f * 1.5 * (float(i) / RATE)) * 0.08
			_put(data, idx, mel * env * 0.45 + bassv + fifth * env)
	return _wav(data, true, n)
