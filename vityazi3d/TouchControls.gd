extends Control

# state: 0 menu, 1 play, 2 gameover, 3 win, 4 shop
var state := 0

var move_vec := Vector2.ZERO
var look_dx := 0.0
var _jump := false
var _attack := false

var chosen := -1
var restart := false
var _interact := false
var _buy := -1
var _close := false

# HUD state (set by Main)
var hp_frac := 1.0
var kills := 0
var gold := 0
var can_interact := false
var shop_names: Array = []
var toast := ""
var toast_t := 0.0
# inventory
var inv_rows: Array = []
var inv_flags: Array = []
var inv_stats := ""
var shop_owned: Array = []
var _inventory := false
var _equip := -1
var _dodge := false

const JOY_R := 120.0
var joy_finger := -1
var joy_origin := Vector2.ZERO
var look_finger := -1

var CHARS := [
	["САША", "меч + щит", Color(0.62, 0.20, 0.18)],
	["ГЛЕБ", "секира", Color(0.30, 0.45, 0.30)],
	["ФЕДЯ", "кинжалы", Color(0.28, 0.36, 0.52)],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _vp() -> Vector2:
	return get_viewport_rect().size

func _process(delta: float) -> void:
	if state != 1:
		move_vec = Vector2.ZERO
	if toast_t > 0.0:
		toast_t -= delta
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
func consume_interact() -> bool:
	var i := _interact; _interact = false; return i
func consume_buy() -> int:
	var b := _buy; _buy = -1; return b
func consume_close() -> bool:
	var c := _close; _close = false; return c
func consume_inventory() -> bool:
	var i := _inventory; _inventory = false; return i
func consume_equip() -> int:
	var e := _equip; _equip = -1; return e
func consume_dodge() -> bool:
	var d := _dodge; _dodge = false; return d

func _dodge_btn() -> Vector2:
	var v := _vp(); return Vector2(v.x - 182.0, v.y - 226.0)
func _dodge_r() -> float: return 46.0
func _inv_btn() -> Vector2:
	var v := _vp(); return Vector2(v.x - 60.0, 120.0)
func _inv_r() -> float: return 40.0
func _inv_row(i: int) -> Rect2:
	var p := _shop_panel()
	var rh := 44.0
	return Rect2(p.position.x + 20.0, p.position.y + 108.0 + i * (rh + 6.0), p.size.x - 40.0, rh)

# ---- geometry ----
func _attack_center() -> Vector2:
	var v := _vp(); return Vector2(v.x - 112.0, v.y - 112.0)
func _jump_center() -> Vector2:
	var v := _vp(); return Vector2(v.x - 252.0, v.y - 96.0)
func _attack_r() -> float: return 66.0
func _jump_r() -> float: return 46.0
func _interact_rect() -> Rect2:
	var v := _vp(); return Rect2(v.x * 0.5 - 110.0, v.y - 112.0, 220.0, 62.0)

func _char_rect(i: int) -> Rect2:
	var v := _vp()
	var w := minf(280.0, (v.x - 160.0) / 3.0)
	var h := w * 1.25
	var gap := 28.0
	var total := 3.0 * w + 2.0 * gap
	var x0 := (v.x - total) * 0.5
	return Rect2(x0 + i * (w + gap), v.y * 0.52 - h * 0.5, w, h)

func _shop_panel() -> Rect2:
	var v := _vp()
	var w := minf(660.0, v.x - 60.0)
	var h := minf(600.0, v.y - 40.0)
	return Rect2((v.x - w) * 0.5, (v.y - h) * 0.5, w, h)

func _shop_row(i: int) -> Rect2:
	var p := _shop_panel()
	var rh := 40.0
	return Rect2(p.position.x + 20.0, p.position.y + 72.0 + i * (rh + 6.0), p.size.x - 40.0, rh)

func _shop_close() -> Rect2:
	var p := _shop_panel()
	return Rect2(p.position.x + p.size.x - 56.0, p.position.y + 12.0, 44.0, 44.0)

# ---- input ----
func _input(event: InputEvent) -> void:
	if state == 1:
		_play_input(event)
	elif state == 0:
		if _pressed(event):
			_menu_tap(_press_pos(event))
	elif state == 4:
		if _pressed(event):
			_shop_tap(_press_pos(event))
	elif state == 5:
		if _pressed(event):
			_inv_tap(_press_pos(event))
	else:
		if _pressed(event):
			restart = true

func _inv_tap(p: Vector2) -> void:
	if _shop_close().has_point(p):
		_close = true
		return
	for i in range(inv_rows.size()):
		if _inv_row(i).has_point(p):
			_equip = i
			return

func _pressed(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and e.pressed) or \
		(e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

func _press_pos(e: InputEvent) -> Vector2:
	return e.position

func _menu_tap(p: Vector2) -> void:
	for i in range(3):
		if _char_rect(i).has_point(p):
			chosen = i
			return

func _shop_tap(p: Vector2) -> void:
	if _shop_close().has_point(p):
		_close = true
		return
	for i in range(shop_names.size()):
		if _shop_row(i).has_point(p):
			_buy = i
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
	if p.distance_to(_inv_btn()) <= _inv_r():
		_inventory = true; return
	if can_interact and _interact_rect().has_point(p):
		_interact = true; return
	if p.distance_to(_attack_center()) <= _attack_r():
		_attack = true; return
	if p.distance_to(_jump_center()) <= _jump_r():
		_jump = true; return
	if p.distance_to(_dodge_btn()) <= _dodge_r():
		_dodge = true; return
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

# ---- draw ----
func _draw() -> void:
	match state:
		1: _draw_play()
		0: _draw_menu()
		4: _draw_play(); _draw_shop()
		5: _draw_play(); _draw_inv()
		2: _draw_end("НОВГОРОД ПАЛ", Color(0.85, 0.3, 0.25))
		3: _draw_end("ПОБЕДА!", Color(0.85, 0.7, 0.3))

func _draw_play() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	if state == 1:
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
		# dodge button
		var dc := _dodge_btn()
		draw_circle(dc, _dodge_r(), Color(0.2, 0.3, 0.4, 0.55))
		draw_arc(dc, _dodge_r(), 0, TAU, 36, Color(0.7, 0.85, 1.0, 0.9), 3.0, true)
		draw_arc(dc, _dodge_r() * 0.55, 0.6, 0.6 + TAU * 0.75, 24, Color.WHITE, 4.0, true)
		# inventory button
		var iv := _inv_btn()
		draw_circle(iv, _inv_r(), Color(0.15, 0.15, 0.2, 0.7))
		draw_arc(iv, _inv_r(), 0, TAU, 32, Color(0.9, 0.85, 0.4, 0.9), 3.0, true)
		for ly in [-7.0, 0.0, 7.0]:
			draw_line(iv + Vector2(-14, ly), iv + Vector2(14, ly), Color.WHITE, 3.0)
		if can_interact:
			var ir := _interact_rect()
			draw_rect(ir, Color(0.2, 0.45, 0.25, 0.85))
			draw_rect(ir, Color(0.9, 0.85, 0.4, 0.95), false, 3.0)
			if font:
				draw_string(font, Vector2(ir.position.x, ir.position.y + 40), "ТОРГОВЛЯ", HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, 24, Color.WHITE)

	# HUD bar
	var bx := 24.0; var by := 24.0; var bw := 300.0; var bh := 26.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.12, 0.15, 0.7))
	draw_rect(Rect2(bx, by, bw * hp_frac, bh), Color(0.65, 0.2, 0.16))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.85, 0.7, 0.3, 0.9), false, 2.0)
	if font:
		draw_string(font, Vector2(bx + 8, by + 19), "ВИТЯЗЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, Vector2(v.x - 24, by + 20), "Золото: %d   Повержено: %d" % [gold, kills], HORIZONTAL_ALIGNMENT_RIGHT, -1, 20, Color(0.95, 0.85, 0.4))
		if toast_t > 0.0:
			var a := clampf(toast_t / 2.5, 0.0, 1.0)
			draw_string(font, Vector2(v.x * 0.5, by + 70), toast, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 0.7, a))

func _draw_shop() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.55))
	var p := _shop_panel()
	draw_rect(p, Color(0.12, 0.11, 0.10, 0.97))
	draw_rect(p, Color(0.85, 0.7, 0.3, 0.9), false, 3.0)
	if font:
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 42), "ЛАВКА ТОРГОВЦА", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.85, 0.4))
		draw_string(font, Vector2(p.position.x + p.size.x - 70, p.position.y + 42), "Золото: %d" % gold, HORIZONTAL_ALIGNMENT_RIGHT, -1, 20, Color.WHITE)
	# close
	var cl := _shop_close()
	draw_rect(cl, Color(0.4, 0.15, 0.13))
	if font:
		draw_string(font, cl.position + Vector2(14, 31), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for i in range(shop_names.size()):
		var r := _shop_row(i)
		var owned: bool = i < shop_owned.size() and shop_owned[i]
		draw_rect(r, Color(0.18, 0.22, 0.18) if owned else Color(0.2, 0.19, 0.17))
		draw_rect(r, Color(0.5, 0.45, 0.35), false, 1.5)
		if font:
			draw_string(font, r.position + Vector2(14, 28), str(shop_names[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.7) if owned else Color.WHITE)
			if owned:
				draw_string(font, Vector2(r.position.x + r.size.x - 16, r.position.y + 28), "✓", HORIZONTAL_ALIGNMENT_RIGHT, -1, 20, Color(0.5, 0.85, 0.45))

func _draw_inv() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.55))
	var p := _shop_panel()
	draw_rect(p, Color(0.10, 0.11, 0.13, 0.97))
	draw_rect(p, Color(0.85, 0.7, 0.3, 0.9), false, 3.0)
	if font:
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 42), "СНАРЯЖЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.85, 0.4))
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 78), inv_stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 112), "Оружие (нажми, чтобы взять):", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))
	var cl := _shop_close()
	draw_rect(cl, Color(0.4, 0.15, 0.13))
	if font:
		draw_string(font, cl.position + Vector2(14, 31), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for i in range(inv_rows.size()):
		var r := _inv_row(i)
		var equipped: bool = i < inv_flags.size() and inv_flags[i]
		var label := str(inv_rows[i])
		var is_header := label.begins_with("—")
		if not is_header:
			draw_rect(r, Color(0.22, 0.30, 0.20) if equipped else Color(0.2, 0.19, 0.17))
			draw_rect(r, Color(0.55, 0.85, 0.45) if equipped else Color(0.5, 0.45, 0.35), false, 2.0)
		if font:
			var tag := "   ✓ надето" if equipped else ""
			var col := Color(0.85, 0.78, 0.5) if is_header else Color.WHITE
			draw_string(font, r.position + Vector2(14, 34), label + tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

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
		var cx := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.42
		draw_circle(Vector2(cx, cy), r.size.x * 0.20, c)
		if font:
			draw_string(font, Vector2(cx, r.position.y + r.size.y * 0.74), CHARS[i][0], HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color.WHITE)
			draw_string(font, Vector2(cx, r.position.y + r.size.y * 0.86), CHARS[i][1], HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.85, 0.85, 0.85))

func _draw_end(title: String, col: Color) -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.6))
	if font:
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.42), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 56, col)
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.54), "Повержено врагов: %d   Золото: %d" % [kills, gold], HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
		draw_string(font, Vector2(v.x * 0.5, v.y * 0.66), "Коснись, чтобы вернуться в меню", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.85, 0.85, 0.85))
