extends Node

# Procedural audio — all SFX and music synthesised in code (16-bit PCM).
const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0

# adaptive music: two players cross-faded between mood themes
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a := true
var _mood := "calm"
var _theme_calm: AudioStreamWAV
var _theme_combat: AudioStreamWAV
var _theme_horde: AudioStreamWAV
const MUSIC_DB := -13.0
var _fade := 1.0          # 0..1 crossfade progress

var _swing: AudioStreamWAV
var _hit: AudioStreamWAV
var _jump: AudioStreamWAV
var _die: AudioStreamWAV
var _hurt: AudioStreamWAV
var _coin: AudioStreamWAV
var _buy: AudioStreamWAV
var _quest: AudioStreamWAV
var _bow: AudioStreamWAV
var _step_grass: AudioStreamWAV
var _step_stone: AudioStreamWAV
var _step_dirt: AudioStreamWAV

func _ready() -> void:
	_setup_buses()
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new(); _music_a.bus = "Music"; add_child(_music_a)
	_music_b = AudioStreamPlayer.new(); _music_b.bus = "Music"; add_child(_music_b)

	_swing = _whoosh(0.16, 1700.0, 700.0, 0.32)
	_hit = _clang(0.22, 0.6)
	_jump = _blip(0.16, 320.0, 680.0, 0.4)
	_die = _whoosh(0.36, 600.0, 90.0, 0.55)
	_hurt = _impact(0.18, 0.55)
	_coin = _chime([1318.0, 1760.0], 0.10, 0.5)
	_buy = _chime([523.0, 659.0, 784.0], 0.10, 0.5)
	_quest = _chime([523.0, 659.0, 784.0, 1047.0], 0.14, 0.6)
	_bow = _twang(0.26, 0.5)
	_step_grass = _footstep(0.10, 0.32, 1900.0)
	_step_stone = _footstep(0.08, 0.5, 3200.0)
	_step_dirt = _footstep(0.11, 0.28, 1300.0)

	_theme_calm = _make_music()
	_theme_combat = _make_combat()
	_theme_horde = _make_horde()

	_music_a.stream = _theme_calm
	_music_a.volume_db = MUSIC_DB
	_music_a.play()
	_music_b.volume_db = -60.0
	set_process(true)

func _setup_buses() -> void:
	# Master(0) + Music(1) + Sfx(2)
	AudioServer.set_bus_count(3)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, "Sfx")
	AudioServer.set_bus_send(2, "Master")
	# light room reverb on the SFX bus for a sense of space
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.5
	rv.wet = 0.10
	rv.dry = 0.92
	rv.spread = 0.6
	AudioServer.add_bus_effect(2, rv)
	# hall reverb + gentle low-pass warmth on the Music bus
	var mrv := AudioEffectReverb.new()
	mrv.room_size = 0.78
	mrv.wet = 0.22
	mrv.dry = 0.85
	mrv.spread = 0.9
	mrv.hipass = 0.05
	AudioServer.add_bus_effect(1, mrv)

func swing() -> void: _play(_swing)
func hit() -> void: _play(_hit)
func jump() -> void: _play(_jump)
func enemy_die() -> void: _play(_die)
func hurt() -> void: _play(_hurt)
func coin() -> void: _play(_coin)
func buy() -> void: _play(_buy)
func quest() -> void: _play(_quest)
func bow() -> void: _play(_bow)

func step(surface: String) -> void:
	match surface:
		"stone": _play(_step_stone)
		"dirt": _play(_step_dirt)
		_: _play(_step_grass)

# called by Main: "calm" / "combat" / "horde"
func set_mood(m: String) -> void:
	if m == _mood:
		return
	_mood = m
	var theme := _theme_calm
	if m == "combat": theme = _theme_combat
	elif m == "horde": theme = _theme_horde
	# bring in the idle player with the new theme, fade across
	var incoming := _music_b if _music_on_a else _music_a
	incoming.stream = theme
	incoming.volume_db = -60.0
	incoming.play()
	_music_on_a = not _music_on_a
	_fade = 0.0

func _process(delta: float) -> void:
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta * 0.8)
		var hi := _music_a if _music_on_a else _music_b
		var lo := _music_b if _music_on_a else _music_a
		hi.volume_db = lerp(-60.0, MUSIC_DB, _fade)
		lo.volume_db = lerp(MUSIC_DB, -60.0, _fade)

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

# ---------- richer music renderer (float mix → soft-clipped 16-bit) ----------

# add one harmonic-rich note into a float mix buffer
func _voice(mix: PackedFloat32Array, start: int, length: int, freq: float, vol: float, harm: Array, attack: float, release: float, decexp: float, vib: float) -> void:
	var n := mix.size()
	var rel_n := maxi(1, int(RATE * release))
	var att_n := maxi(1, int(RATE * attack))
	for i in range(length):
		var idx := start + i
		if idx >= n:
			break
		var t := float(i) / RATE
		var env := minf(float(i) / att_n, 1.0) * exp(-decexp * t)
		var rem := length - i
		if rem < rel_n:
			env *= float(rem) / rel_n
		var ph := TAU * freq * t + vib * sin(TAU * 5.2 * t)
		var s := 0.0
		for k in range(harm.size()):
			s += float(harm[k]) * sin(ph * float(k + 1))
		mix[idx] += s * env * vol

# percussive drum hit (kick/tom/snare-ish) into the mix
func _drum(mix: PackedFloat32Array, start: int, vol: float, p0: float, p1: float, decexp: float, noise: float) -> void:
	var n := mix.size()
	var length := int(RATE * 0.4)
	for i in range(length):
		var idx := start + i
		if idx >= n:
			break
		var t := float(i) / RATE
		var tt := clampf(t * 4.0, 0.0, 1.0)
		var pitch: float = lerp(p0, p1, tt)
		var env := exp(-decexp * t)
		var body := sin(TAU * pitch * t)
		var nz := (randf() * 2.0 - 1.0) * exp(-t * 60.0) * noise
		mix[idx] += (body * (1.0 - noise) + nz) * env * vol

func _commit_music(mix: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := mix.size()
	var data := _buf(n)
	for i in range(n):
		var s: float = mix[i] * 1.1
		s = s / (1.0 + absf(s))      # soft saturation, no harsh clipping
		_put(data, i, s)
	return _wav(data, loop, n)

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
# calm exploration: folk chord progression with гусли-like arpeggios, pad & bass
func _make_music() -> AudioStreamWAV:
	var bar := 2.2
	var bars := [
		[110.0, [220.0, 261.6, 329.6]],  # Am
		[87.3, [174.6, 220.0, 261.6]],   # F
		[130.8, [261.6, 329.6, 392.0]],  # C
		[98.0, [196.0, 246.9, 293.7]],   # G
		[110.0, [220.0, 261.6, 329.6]],  # Am
		[146.8, [220.0, 293.7, 349.2]],  # Dm
		[130.8, [261.6, 329.6, 392.0]],  # C
		[98.0, [196.0, 246.9, 293.7]],   # G
	]
	var per := int(RATE * bar)
	var n := per * bars.size()
	var mix := PackedFloat32Array(); mix.resize(n)
	var PAD := [1.0, 0.4, 0.22, 0.12]
	var PLUCK := [1.0, 0.55, 0.32, 0.18, 0.1]
	var BASS := [1.0, 0.5, 0.25]
	for b in range(bars.size()):
		var root: float = bars[b][0]
		var tri: Array = bars[b][1]
		var s0 := b * per
		_voice(mix, s0, per, root, 0.34, BASS, 0.02, 0.35, 1.1, 0.0)
		_voice(mix, s0, per, root * 2.0, 0.10, BASS, 0.04, 0.35, 0.9, 0.0)
		for tf in tri:
			_voice(mix, s0, per, float(tf), 0.10, PAD, 0.3, 0.5, 0.35, 0.012)
		# arpeggio melody, 6 plucks per bar
		var mel := [tri[0], tri[1], tri[2], float(tri[1]) * 2.0, tri[2], float(tri[0]) * 2.0]
		var step := per / 6
		for m in range(6):
			_voice(mix, s0 + m * step, step, float(mel[m]) * 2.0, 0.22, PLUCK, 0.008, 0.1, 4.5, 0.015)
	return _commit_music(mix, true)

# footstep: short low thud + surface-coloured noise burst
func _footstep(dur: float, vol: float, cutoff: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := _buf(n)
	var prev := 0.0
	var a := clampf(cutoff / RATE, 0.05, 0.95)
	for i in range(n):
		var t := float(i) / n
		var env: float = exp(-t * 16.0)
		var thud := sin(TAU * 95.0 * (float(i) / RATE)) * exp(-t * 22.0)
		# one-pole low-passed noise gives a soft "crunch" tuned by cutoff
		var nz := randf() * 2.0 - 1.0
		prev = prev + a * (nz - prev)
		_put(data, i, (thud * 0.6 + prev * 0.7) * env * vol)
	return _wav(data, false, n)

# tense combat: minor ostinato + driving eighth-note bass + kick/snare beat
func _make_combat() -> AudioStreamWAV:
	var scale := [220.0, 261.6, 293.7, 311.1, 349.2, 392.0, 415.3]   # A natural minor
	var seq := [0, 4, 3, 4, 5, 4, 3, 1, 0, 3, 4, 6, 5, 4, 3, 4]
	var bassn := [110.0, 110.0, 110.0, 98.0, 116.5, 116.5, 98.0, 87.3]
	var note := 0.34
	var per := int(RATE * note)
	var n := per * seq.size()
	var mix := PackedFloat32Array(); mix.resize(n)
	var LEAD := [1.0, 0.5, 0.3, 0.15]
	var BASS := [1.0, 0.6, 0.3]
	for k in range(seq.size()):
		var s0 := k * per
		_voice(mix, s0, per, scale[seq[k]], 0.26, LEAD, 0.006, 0.08, 3.0, 0.02)
		# two eighth-note bass pulses per step
		var bf: float = bassn[k % bassn.size()]
		_voice(mix, s0, per / 2, bf, 0.30, BASS, 0.005, 0.05, 2.5, 0.0)
		_voice(mix, s0 + per / 2, per / 2, bf, 0.24, BASS, 0.005, 0.05, 2.5, 0.0)
		# beat: kick on, snare off-beat
		_drum(mix, s0, 0.5, 150.0, 55.0, 16.0, 0.1)
		_drum(mix, s0 + per / 2, 0.32, 320.0, 180.0, 22.0, 0.7)
	return _commit_music(mix, true)

# war-drums of the horde: ominous drone + low brass + tom pattern
func _make_horde() -> AudioStreamWAV:
	var note := 0.30
	var per := int(RATE * note)
	var pattern := [1.0, 0.0, 0.6, 0.0, 1.0, 0.4, 0.7, 0.0, 1.0, 0.0, 0.6, 0.4, 1.0, 0.7, 0.5, 0.3]
	var n := per * pattern.size()
	var mix := PackedFloat32Array(); mix.resize(n)
	# sustained low drone + fifth across the whole loop
	var DRONE := [1.0, 0.5, 0.3, 0.2]
	_voice(mix, 0, n, 65.4, 0.16, DRONE, 0.5, 0.6, 0.05, 0.02)        # low C
	_voice(mix, 0, n, 98.0, 0.08, DRONE, 0.6, 0.6, 0.05, 0.02)        # fifth
	# menacing brass stabs every 4 steps
	var BRASS := [1.0, 0.7, 0.5, 0.35, 0.2]
	for s in range(0, pattern.size(), 4):
		_voice(mix, s * per, per * 2, 130.8, 0.18, BRASS, 0.03, 0.3, 1.2, 0.01)
	# tom pattern
	for k in range(pattern.size()):
		if pattern[k] > 0.0:
			_drum(mix, k * per, 0.55 * float(pattern[k]), 170.0, 68.0, 9.0, 0.45)
	return _commit_music(mix, true)
