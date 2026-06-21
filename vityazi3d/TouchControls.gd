extends Control

var move_vec := Vector2.ZERO
var look_dx := 0.0
var _jump := false
var _attack := false

# HUD state (set by Main)
var hp_frac := 1.0
var kills := 0
var wave := 1
var alive := 0

const JOY_R := 120.0
var joy_finger := -1
var joy_origin := Vector2.ZERO
var look_finger := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _vp() -> Vector2:
	return get_viewport_rect().size

func _process(_delta: float) -> void:
	queue_redraw()

func consume_jump() -> bool:
	var j := _jump; _jump = false; return j

func consume_attack() -> bool:
	var a := _attack; _attack = false; return a

func consume_look() -> float:
	var l := look_dx; look_dx = 0.0; return l

func _attack_center() -> Vector2:
	var v := _vp()
	return Vector2(v.x - 110.0, v.y - 120.0)

func _jump_center() -> Vector2:
	var v := _vp()
	return Vector2(v.x - 240.0, v.y - 95.0)

func _attack_r() -> float: return 80.0
func _jump_r() -> float: return 58.0

func _input(event: InputEvent) -> void:
	var v := _vp()
	if event is InputEventScreenTouch:
		if event.pressed:
			var p: Vector2 = event.position
			if p.distance_to(_attack_center()) <= _attack_r():
				_attack = true; return
			if p.distance_to(_jump_center()) <= _jump_r():
				_jump = true; return
			if p.x < v.x * 0.5 and joy_finger == -1:
				joy_finger = event.index
				joy_origin = p
				move_vec = Vector2.ZERO
			elif look_finger == -1:
				look_finger = event.index
		else:
			if event.index == joy_finger:
				joy_finger = -1
				move_vec = Vector2.ZERO
			if event.index == look_finger:
				look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_finger:
			var d: Vector2 = event.position - joy_origin
			var l := d.length()
			if l > JOY_R:
				d = d / l * JOY_R
			move_vec = Vector2(d.x / JOY_R, -d.y / JOY_R)
		elif event.index == look_finger:
			look_dx += event.relative.x

func _draw() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	# joystick
	var base := joy_origin if joy_finger != -1 else Vector2(170, v.y - 150)
	draw_circle(base, JOY_R, Color(1, 1, 1, 0.10))
	draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	var knob := base + move_vec * Vector2(JOY_R, -JOY_R)
	draw_circle(knob, 42, Color(1, 1, 1, 0.30))

	# attack button
	var ac := _attack_center()
	draw_circle(ac, _attack_r(), Color(0.6, 0.18, 0.16, 0.55))
	draw_arc(ac, _attack_r(), 0, TAU, 40, Color(0.85, 0.7, 0.3, 0.9), 3.0, true)
	draw_line(ac + Vector2(-20, 22), ac + Vector2(20, -22), Color.WHITE, 6.0)
	draw_line(ac + Vector2(-26, 6), ac + Vector2(-8, 26), Color.WHITE, 5.0)
	# jump button
	var jc := _jump_center()
	draw_circle(jc, _jump_r(), Color(0.15, 0.19, 0.24, 0.55))
	draw_arc(jc, _jump_r(), 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0, true)
	var tri := PackedVector2Array([jc + Vector2(0, -20), jc + Vector2(-18, 12), jc + Vector2(18, 12)])
	draw_colored_polygon(tri, Color.WHITE)

	# HUD: HP bar
	var bx := 24.0; var by := 24.0; var bw := 320.0; var bh := 26.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.12, 0.15, 0.7))
	draw_rect(Rect2(bx, by, bw * hp_frac, bh), Color(0.65, 0.2, 0.16))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.85, 0.7, 0.3, 0.9), false, 2.0)
	if font:
		draw_string(font, Vector2(bx + 8, by + 19), "ВИТЯЗЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var info := "Волна %d   Враги: %d   Повержено: %d" % [wave, alive, kills]
		draw_string(font, Vector2(v.x - 24, by + 19), info, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, Color.WHITE)
