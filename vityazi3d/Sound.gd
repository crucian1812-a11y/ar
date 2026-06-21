extends Node

# Procedural audio: all SFX and the ambient melody are synthesised in code
# (16-bit PCM) so the game needs no binary audio assets.

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer

var _swing: AudioStreamWAV
var _hit: AudioStreamWAV
var _jump: AudioStreamWAV
var _die: AudioStreamWAV
var _hurt: AudioStreamWAV

func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -14.0
	add_child(_music)

	_swing = _whoosh(0.18, 1500.0, 600.0, 0.5)
	_hit = _impact(0.14, 0.7)
	_jump = _blip(0.16, 320.0, 680.0, 0.45)
	_die = _whoosh(0.34, 700.0, 120.0, 0.6)
	_hurt = _impact(0.18, 0.6)

	_music.stream = _make_melody()
	_music.play()

func swing() -> void: _play(_swing)
func hit() -> void: _play(_hit)
func jump() -> void: _play(_jump)
func enemy_die() -> void: _play(_die)
func hurt() -> void: _play(_hurt)

func _play(s: AudioStreamWAV) -> void:
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()

# ---------------- synthesis ----------------

func _new_wav(samples: int) -> Array:
	var data := PackedByteArray()
	data.resize(samples * 2)
	return [data]

func _put(data: PackedByteArray, i: int, val: float) -> void:
	var v := int(clampf(val, -1.0, 1.0) * 32767.0)
	data[i * 2] = v & 0xFF
	data[i * 2 + 1] = (v >> 8) & 0xFF

func _finish(data: PackedByteArray, loop: bool, n: int) -> AudioStreamWAV:
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

# noise burst sweeping down — sword swing / death
func _whoosh(dur: float, f0: float, f1: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data: PackedByteArray = _new_wav(n)[0]
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var env: float = (1.0 - t) * (1.0 - t)
		var f: float = lerp(f0, f1, t)
		phase += f / RATE
		var tone := sin(TAU * phase)
		var noise := randf() * 2.0 - 1.0
		_put(data, i, (tone * 0.5 + noise * 0.5) * env * vol)
	return _finish(data, false, n)

# percussive impact — hit / hurt
func _impact(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data: PackedByteArray = _new_wav(n)[0]
	for i in range(n):
		var t := float(i) / n
		var env: float = exp(-t * 18.0)
		var body := sin(TAU * 90.0 * (float(i) / RATE))
		var noise := randf() * 2.0 - 1.0
		_put(data, i, (body * 0.6 + noise * 0.4) * env * vol)
	return _finish(data, false, n)

# rising sine blip — jump
func _blip(dur: float, f0: float, f1: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data: PackedByteArray = _new_wav(n)[0]
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var env: float = sin(PI * t)
		var f: float = lerp(f0, f1, t)
		phase += f / RATE
		_put(data, i, sin(TAU * phase) * env * vol)
	return _finish(data, false, n)

# gentle pentatonic loop — ambient music
func _make_melody() -> AudioStreamWAV:
	var scale := [220.0, 247.0, 294.0, 330.0, 392.0, 440.0]  # A minor pentatonic-ish
	var seq := [0, 2, 3, 2, 4, 3, 1, 0, 2, 4, 5, 4, 3, 2, 1, 0]
	var note_dur := 0.55
	var per := int(RATE * note_dur)
	var n := per * seq.size()
	var data: PackedByteArray = _new_wav(n)[0]
	for k in range(seq.size()):
		var freq: float = scale[seq[k]]
		for i in range(per):
			var t := float(i) / per
			var env: float = sin(PI * clampf(t, 0.0, 1.0)) * 0.6
			var s := sin(TAU * freq * (float(i) / RATE))
			var s2 := sin(TAU * freq * 2.0 * (float(i) / RATE)) * 0.25
			var drone := sin(TAU * 110.0 * (float(k * per + i) / RATE)) * 0.12
			_put(data, k * per + i, (s + s2) * env * 0.5 + drone)
	return _finish(data, true, n)
