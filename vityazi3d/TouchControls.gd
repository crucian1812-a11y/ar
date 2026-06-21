extends Control

# state: 0 menu, 1 play, 2 gameover, 3 win
var state := 0

var move_vec := Vector2.ZERO
var look_dx := 0.0
var _jump := false
var _attack := false

var chosen := -1
var restart := false

# HUD state (set by Main)
var hp_frac := 1.0
var kills := 0
var wave := 1
var alive := 0
var boss_present := false

const JOY_R := 120.0
var joy_finger := -1
var joy_origin := Vector2.ZERO
var look_finger := -1

var CHARS := [
	["САША", "меч", Color(0.62, 0.20, 0.18)],
	["ГЛЕБ", "секира", Color(0.30, 0.45, 0.30)],
	["ФЕДЯ", "копьё", Color(0.28, 0.36, 0.52)],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _vp() -> Vector2:
	return get_viewport_rect().size

func _process(_delta: float) -> void:
	if state != 1:
		move_vec = Vector2.ZERO
	queue_redraw()

func consume_jump() -> bool:
	var j := _jump; _jump = false; return j

func consume_attack() -> bool:
	var a := _attack; _attack = false; return a

func consume_look() -> float:
	var l := look_dx; look_dx = 0.0; return l

func consume_chosen() -> int:
	var c := chosen; chosen = -1; return c

func consume_restart() -> bool:
	var r := restart; restart = false; return r

# ---------------- input ----------------

func _input(event: InputEvent) -> void:
	if state == 1:
		_play_input(event)
	elif state == 0:
		if event is InputEventScreenTouch and event.pressed:
			_menu_tap(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_menu_tap(event.position)
	else:
		if (event is InputEventScreenTouch and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed):
			restart = true

func _menu_tap(p: Vector2) -> void:
	for i in range(3):
		if _char_rect(i).has_point(p):
			chosen = i
			return

func _play_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: _press(event.position, event.index)
		else: _release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position, -2)
			else: _release(-2)
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag(-2, event.position, event.relative)

func _press(p: Vector2, id: int) -> void:
	if p.distance_to(_attack_center()) <= _attack_r():
		_attack = true; return
	if p.distance_to(_jump_center()) <= _jump_r():
		_jump = true; return
	if p.x < _vp().x * 0.5 and joy_finger == -1:
		joy_finger = id; joy_origin = p; move_vec = Vector2.ZERO
	elif look_finger == -1:
		look_finger = id

func _release(id: int) -> void:
	if id == joy_finger:
		joy_finger = -1; move_vec = Vector2.ZERO
	if id == look_finger:
		look_finger = -1

func _drag(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == joy_finger:
		var d := pos - joy_origin
		var l := d.length()
		if l > JOY_R:
			d = d / l * JOY_R
		move_vec = Vector2(d.x / JOY_R, -d.y / JOY_R)
	elif id == look_finger:
		look_dx += rel.x

func _attack_center() -> Vector2:
	var v := _vp(); return Vector2(v.x - 110.0, v.y - 120.0)
func _jump_center() -> Vector2:
	var v := _vp(); return Vector2(v.x - 240.0, v.y - 95.0)
func _attack_r() -> float: return 80.0
func _jump_r() -> float: return 58.0

func _char_rect(i: int) -> Rect2:
	var v := _vp()
	var w := minf(280.0, (v.x - 160.0) / 3.0)
	var h := w * 1.25
	var gap := 28.0
	var total := 3.0 * w + 2.0 * gap
	var x0 := (v.x - total) * 0.5
	return Rect2(x0 + i * (w + gap), v.y * 0.52 - h * 0.5, w, h)

# ---------------- draw ----------------

func _draw() -> void:
	match state:
		1: _draw_play()
		0: _draw_menu()
		2: _draw_end("НОВГОРОД ПАЛ", Color(0.85, 0.3, 0.25))
		3: _draw_end("ПОБЕДА!", Color(0.85, 0.7, 0.3))

func _draw_play() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	var base := joy_origin if joy_finger != -1 else Vector2(170, v.y - 150)
	draw_circle(base, JOY_R, Color(1, 1, 1, 0.10))
	draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(base + move_vec * Vector2(JOY_R, -JOY_R), 42, Color(1, 1, 1, 0.30))

	var ac := _attack_center()
	draw_circle(ac, _attack_r(), Color(0.6, 0.18, 0.16, 0.55))
	draw_arc(ac, _attack_r(), 0, TAU, 40, Color(0.85, 0.7, 0.3, 0.9), 3.0, true)
	draw_line(ac + Vector2(-20, 22), ac + Vector2(20, -22), Color.WHITE, 6.0)
	draw_line(ac + Vector2(-26, 6), ac + Vector2(-8, 26), Color.WHITE, 5.0)
	var jc := _jump_center()
	draw_circle(jc, _jump_r(), Color(0.15, 0.19, 0.24, 0.55))
	draw_arc(jc, _jump_r(), 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0, true)
	draw_colored_polygon(PackedVector2Array([jc + Vector2(0, -20), jc + Vector2(-18, 12), jc + Vector2(18, 12)]), Color.WHITE)

	var bx := 24.0; var by := 24.0; var bw := 320.0; var bh := 26.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.12, 0.15, 0.7))
	draw_rect(Rect2(bx, by, bw * hp_frac, bh), Color(0.65, 0.2, 0.16))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.85, 0.7, 0.3, 0.9), false, 2.0)
	if font:
		draw_string(font, Vector2(bx + 8, by + 19), "ВИТЯЗЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var info := "Волна %d   Враги: %d   Повержено: %d" % [wave, alive, kills]
		draw_string(font, Vector2(v.x - 24, by + 19), info, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, Color.WHITE)
		if boss_present:
			draw_string(font, Vector2(v.x * 0.5, by + 60), "⚔ ВОЕВОДА ⚔", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(0.9, 0.3, 0.3))

func _draw_menu() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.45))
	if font:
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.16), "ВИТЯЗИ НОВГОРОДА", HORIZONTAL_ALIGNMENT_CENTER, -1, 46, Color(0.9, 0.78, 0.4))
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.24), "Выбери витязя", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	for i in range(3):
		var r := _char_rect(i)
		var c: Color = CHARS[i][2]
		draw_rect(r, Color(0.12, 0.13, 0.16, 0.92))
		draw_rect(r, c, false, 4.0)
		# emblem
		var cx := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.42
		draw_circle(Vector2(cx, cy), r.size.x * 0.20, c)
		_weapon_glyph(i, Vector2(cx, cy), r.size.x * 0.16)
		if font:
			draw_string(font, Vector2(cx, r.position.y + r.size.y * 0.74), CHARS[i][0], HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color.WHITE)
			draw_string(font, Vector2(cx, r.position.y + r.size.y * 0.86), CHARS[i][1], HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.85, 0.85, 0.85))

func _weapon_glyph(i: int, c: Vector2, s: float) -> void:
	match i:
		0:  # sword
			draw_line(c + Vector2(0, s), c + Vector2(0, -s), Color.WHITE, 4.0)
			draw_line(c + Vector2(-s * 0.5, s * 0.4), c + Vector2(s * 0.5, s * 0.4), Color.WHITE, 4.0)
		1:  # axe
			draw_line(c + Vector2(s * 0.4, s), c + Vector2(s * 0.4, -s), Color.WHITE, 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.4, -s), c + Vector2(-s * 0.6, -s * 0.5), c + Vector2(s * 0.4, 0)]), Color.WHITE)
		2:  # spear
			draw_line(c + Vector2(0, s), c + Vector2(0, -s), Color.WHITE, 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(-s * 0.35, -s * 0.7), c + Vector2(s * 0.35, -s * 0.7)]), Color.WHITE)

func _draw_end(title: String, col: Color) -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.6))
	if font:
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.42), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 56, col)
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.54), "Повержено врагов: %d" % kills, HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color.WHITE)
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.66), "Коснись, чтобы вернуться в меню", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.85, 0.85, 0.85))
