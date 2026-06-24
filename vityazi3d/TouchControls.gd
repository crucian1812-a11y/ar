extends Control

# state: 0 menu, 1 play, 2 gameover, 3 win, 4 shop, 5 inventory, 6 quest
var state := 0

var move_vec := Vector2.ZERO
var look_dx := 0.0
var _jump := false
var _attack := false

var chosen := -1
var restart := false
var quality_label := "Графика: Высокая"
var _quality := false
var net_mode := "single"
var net_status := ""
var _net := -1
var _interact := false
var _close := false

# HUD state (set by Main)
var hp_frac := 1.0
var kills := 0
var gold := 0
var can_interact := false
var region := ""
# minimap
var map_world := 460.0
var map_cities: Array = []     # [{pos:Vector2, name}]
var map_villages: Array = []   # [Vector2]
var map_saray := Vector2.ZERO
var player_pos := Vector2.ZERO
var player_yaw := 0.0
var toast := ""
var toast_t := 0.0

# shared 3D item preview (rendered by Main's SubViewport)
var preview_tex: Texture2D = null

# shop (list + preview + stats)
var shop_rows: Array = []      # [{name, price, state}]  state: buy/owned/poor
var shop_sel := 0
var shop_scroll := 0
var shop_is3d := false
var shop_icon := "heal"
var shop_stats: Array = []
var shop_sel_name := ""
var shop_sel_price := 0
var shop_buy_text := "Купить"
var shop_buy_state := "ok"
var shop_rare := false
var _shop_select := -1
var _shop_buy := false

# inventory (paper-doll + bag, Diablo-style)
var inv_slots: Array = []   # [{label,name,rare}] order: 0 weapon, 1 shield, 2 helmet, 3 armor
var inv_bag: Array = []      # [{name,rare,tag}]
var inv_stats := ""
var inv_is3d := false
var inv_weapon_name := ""
var inv_weapon_stats: Array = []
var inv_upgrades := ""
var _inventory := false
var _slot := -1
var _bag := -1
var _dodge := false
# quests
var interact_label := "ТОРГОВЛЯ"
var quest_hud := ""
var quest_title := ""
var quest_desc := ""
var quest_info := ""
var quest_btn := "Принять"
var _quest := false

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
func consume_quality() -> bool:
	var q := _quality; _quality = false; return q
func consume_net() -> int:
	var n := _net; _net = -1; return n
func consume_restart() -> bool:
	var r := restart; restart = false; return r
func consume_interact() -> bool:
	var i := _interact; _interact = false; return i
func consume_shop_select() -> int:
	var s := _shop_select; _shop_select = -1; return s
func consume_shop_buy() -> bool:
	var b := _shop_buy; _shop_buy = false; return b
func consume_close() -> bool:
	var c := _close; _close = false; return c
func consume_inventory() -> bool:
	var i := _inventory; _inventory = false; return i
func consume_slot() -> int:
	var s := _slot; _slot = -1; return s
func consume_bag() -> int:
	var b := _bag; _bag = -1; return b
func consume_dodge() -> bool:
	var d := _dodge; _dodge = false; return d
func consume_quest() -> bool:
	var q := _quest; _quest = false; return q

func _dodge_btn() -> Vector2:
	var v := _vp(); return Vector2(v.x - 182.0, v.y - 226.0)
func _dodge_r() -> float: return 46.0
func _inv_btn() -> Vector2:
	var v := _vp(); return Vector2(v.x - 60.0, 120.0)
func _inv_r() -> float: return 40.0
func _inv_doll_x() -> float:
	var p := _shop_panel()
	return p.position.x + p.size.x * 0.25

func _slot_rect(i: int) -> Rect2:
	var p := _shop_panel()
	var sx := _inv_doll_x()
	var top := p.position.y + 96.0
	match i:
		0: return Rect2(sx - 182.0, top + 150.0, 116.0, 54.0)   # weapon (left hand)
		1: return Rect2(sx + 66.0, top + 150.0, 116.0, 54.0)    # shield (right hand)
		2: return Rect2(sx - 58.0, top + 14.0, 116.0, 54.0)     # helmet (head)
		3: return Rect2(sx - 58.0, top + 226.0, 116.0, 54.0)    # armor (torso)
	return Rect2()

func _bag_cell(i: int) -> Rect2:
	var p := _shop_panel()
	var cols := 3
	var bx := p.position.x + p.size.x * 0.52
	var by := p.position.y + 150.0
	var cw := 92.0; var ch := 58.0; var gap := 8.0
	var r := i / cols
	var c := i % cols
	return Rect2(bx + c * (cw + gap), by + r * (ch + gap), cw, ch)

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

func _quality_btn() -> Rect2:
	var v := _vp()
	return Rect2(v.x * 0.5 - 150.0, v.y * 0.88, 300.0, 52.0)

func _net_btn(i: int) -> Rect2:
	var v := _vp()
	var w := minf(240.0, (v.x - 120.0) / 3.0)
	var gap := 16.0
	var total := 3.0 * w + 2.0 * gap
	var x0 := (v.x - total) * 0.5
	return Rect2(x0 + i * (w + gap), v.y * 0.30, w, 46.0)

func _shop_panel() -> Rect2:
	var v := _vp()
	var w := minf(800.0, v.x - 36.0)
	var h := minf(580.0, v.y - 28.0)
	return Rect2((v.x - w) * 0.5, (v.y - h) * 0.5, w, h)

const SHOP_ROW_H := 34.0
func _shop_list_rect() -> Rect2:
	var p := _shop_panel()
	return Rect2(p.position.x + 18.0, p.position.y + 64.0, p.size.x * 0.46, p.size.y - 132.0)
func _shop_visible_rows() -> int:
	return int(_shop_list_rect().size.y / SHOP_ROW_H)
func _shop_row_rect(k: int) -> Rect2:
	var l := _shop_list_rect()
	return Rect2(l.position.x, l.position.y + k * SHOP_ROW_H, l.size.x, SHOP_ROW_H - 4.0)
func _shop_scroll_up() -> Rect2:
	var l := _shop_list_rect()
	return Rect2(l.position.x, l.position.y + l.size.y + 8.0, l.size.x * 0.5 - 4.0, 38.0)
func _shop_scroll_down() -> Rect2:
	var l := _shop_list_rect()
	return Rect2(l.position.x + l.size.x * 0.5 + 4.0, l.position.y + l.size.y + 8.0, l.size.x * 0.5 - 4.0, 38.0)
func _shop_preview_rect() -> Rect2:
	var p := _shop_panel()
	return Rect2(p.position.x + p.size.x * 0.50, p.position.y + 64.0, p.size.x * 0.5 - 18.0, p.size.y * 0.46)
func _shop_buy_rect() -> Rect2:
	var p := _shop_panel()
	return Rect2(p.position.x + p.size.x * 0.50, p.position.y + p.size.y - 70.0, p.size.x * 0.5 - 18.0, 52.0)

func _shop_close() -> Rect2:
	var p := _shop_panel()
	return Rect2(p.position.x + p.size.x - 56.0, p.position.y + 12.0, 44.0, 44.0)

func _quest_panel() -> Rect2:
	var v := _vp()
	var w := minf(560.0, v.x - 60.0)
	var h := minf(340.0, v.y - 40.0)
	return Rect2((v.x - w) * 0.5, (v.y - h) * 0.5, w, h)

func _quest_btn_rect() -> Rect2:
	var p := _quest_panel()
	return Rect2(p.position.x + 24.0, p.position.y + p.size.y - 74.0, p.size.x - 48.0, 54.0)

func _quest_close() -> Rect2:
	var p := _quest_panel()
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
	elif state == 6:
		if _pressed(event):
			_quest_tap(_press_pos(event))
	else:
		if _pressed(event):
			restart = true

func _quest_tap(p: Vector2) -> void:
	if _quest_close().has_point(p):
		_close = true
		return
	if _quest_btn_rect().has_point(p):
		_quest = true
		return

func _inv_tap(p: Vector2) -> void:
	if _shop_close().has_point(p):
		_close = true
		return
	for i in range(4):
		if _slot_rect(i).has_point(p):
			_slot = i
			return
	for i in range(inv_bag.size()):
		if _bag_cell(i).has_point(p):
			_bag = i
			return

func _pressed(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and e.pressed) or \
		(e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

func _press_pos(e: InputEvent) -> Vector2:
	return e.position

func _menu_tap(p: Vector2) -> void:
	if _quality_btn().has_point(p):
		_quality = true
		return
	for i in range(3):
		if _net_btn(i).has_point(p):
			_net = i
			return
	for i in range(3):
		if _char_rect(i).has_point(p):
			chosen = i
			return

func _shop_tap(p: Vector2) -> void:
	if _shop_close().has_point(p):
		_close = true
		return
	if _shop_buy_rect().has_point(p):
		_shop_buy = true
		return
	var vis := _shop_visible_rows()
	if _shop_scroll_up().has_point(p):
		shop_scroll = maxi(0, shop_scroll - vis)
		return
	if _shop_scroll_down().has_point(p):
		shop_scroll = mini(maxi(0, shop_rows.size() - vis), shop_scroll + vis)
		return
	for k in range(vis):
		var idx := shop_scroll + k
		if idx >= shop_rows.size():
			break
		if _shop_row_rect(k).has_point(p):
			_shop_select = idx
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
		6: _draw_play(); _draw_quest()
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
			var icol := Color(0.2, 0.45, 0.25, 0.85) if interact_label == "ТОРГОВЛЯ" else Color(0.45, 0.32, 0.12, 0.9)
			draw_rect(ir, icol)
			draw_rect(ir, Color(0.9, 0.85, 0.4, 0.95), false, 3.0)
			if font:
				draw_string(font, Vector2(ir.position.x, ir.position.y + 40), interact_label, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, 24, Color.WHITE)

	# HUD bar
	var bx := 24.0; var by := 24.0; var bw := 300.0; var bh := 26.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.12, 0.15, 0.7))
	draw_rect(Rect2(bx, by, bw * hp_frac, bh), Color(0.65, 0.2, 0.16))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.85, 0.7, 0.3, 0.9), false, 2.0)
	if font:
		draw_string(font, Vector2(bx + 8, by + 19), "ВИТЯЗЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, Vector2(bx, by + 20), "Золото: %d   Повержено: %d" % [gold, kills], HORIZONTAL_ALIGNMENT_RIGHT, v.x - bx - 26.0, 20, Color(0.95, 0.85, 0.4))
		if region != "":
			draw_string(font, Vector2(0, by + 18), "⌖ " + region, HORIZONTAL_ALIGNMENT_CENTER, v.x, 18, Color(0.85, 0.9, 1.0))
		if quest_hud != "":
			draw_string(font, Vector2(bx + 4, by + bh + 24), "✦ " + quest_hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 0.9, 0.55))
		if toast_t > 0.0:
			var a := clampf(toast_t / 2.5, 0.0, 1.0)
			draw_string(font, Vector2(0, by + 70), toast, HORIZONTAL_ALIGNMENT_CENTER, v.x, 24, Color(1, 1, 0.7, a))
	_draw_minimap()

func _draw_shop() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.6))
	var p := _shop_panel()
	draw_rect(p, Color(0.12, 0.11, 0.10, 0.98))
	draw_rect(p, Color(0.85, 0.7, 0.3, 0.9), false, 3.0)
	if font:
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 42), "ЛАВКА ТОРГОВЦА", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.85, 0.4))
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 42), "Золото: %d" % gold, HORIZONTAL_ALIGNMENT_RIGHT, p.size.x * 0.46 - 20.0, 20, Color(0.95, 0.85, 0.4))
	var cl := _shop_close()
	draw_rect(cl, Color(0.4, 0.15, 0.13))
	if font:
		draw_string(font, cl.position + Vector2(14, 31), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

	# ---- item list (left) ----
	var vis := _shop_visible_rows()
	for k in range(vis):
		var idx := shop_scroll + k
		if idx >= shop_rows.size():
			break
		var row: Dictionary = shop_rows[idx]
		var r := _shop_row_rect(k)
		var st := String(row.get("state", "buy"))
		var selrow := idx == shop_sel
		draw_rect(r, Color(0.26, 0.24, 0.16) if selrow else Color(0.18, 0.17, 0.15))
		draw_rect(r, Color(0.95, 0.8, 0.35) if selrow else Color(0.4, 0.38, 0.32), false, 2.0 if selrow else 1.0)
		if font:
			var nmcol := Color.WHITE
			if st == "owned": nmcol = Color(0.55, 0.85, 0.5)
			elif st == "poor": nmcol = Color(0.7, 0.55, 0.55)
			draw_string(font, r.position + Vector2(10, 23), String(row.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 86, 16, nmcol)
			var ptxt := "✓" if st == "owned" else ("%d з." % int(row.get("price", 0)))
			var pcol := Color(0.55, 0.85, 0.5) if st == "owned" else (Color(0.95, 0.85, 0.4) if st != "poor" else Color(0.8, 0.45, 0.4))
			draw_string(font, Vector2(r.position.x, r.position.y + 23), ptxt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10.0, 16, pcol)
	# scroll buttons
	var su := _shop_scroll_up()
	var sd := _shop_scroll_down()
	draw_rect(su, Color(0.2, 0.2, 0.24)); draw_rect(sd, Color(0.2, 0.2, 0.24))
	draw_rect(su, Color(0.5, 0.5, 0.55), false, 1.5); draw_rect(sd, Color(0.5, 0.5, 0.55), false, 1.5)
	if font:
		draw_string(font, su.position + Vector2(0, 27), "▲", HORIZONTAL_ALIGNMENT_CENTER, su.size.x, 20, Color.WHITE)
		draw_string(font, sd.position + Vector2(0, 27), "▼", HORIZONTAL_ALIGNMENT_CENTER, sd.size.x, 20, Color.WHITE)

	# ---- detail panel (right) ----
	var pr := _shop_preview_rect()
	draw_rect(pr, Color(0.07, 0.08, 0.11))
	draw_rect(pr, Color(0.95, 0.8, 0.35) if shop_rare else Color(0.45, 0.45, 0.5), false, 2.0)
	if shop_is3d and preview_tex != null:
		draw_texture_rect(preview_tex, pr, false)
	else:
		_draw_item_icon(pr, shop_icon)
	if font:
		var ncol := Color(1.0, 0.85, 0.35) if shop_rare else Color.WHITE
		draw_string(font, Vector2(pr.position.x, pr.position.y + pr.size.y + 26), shop_sel_name, HORIZONTAL_ALIGNMENT_LEFT, pr.size.x, 20, ncol)
		var sy := pr.position.y + pr.size.y + 52
		for line in shop_stats:
			draw_string(font, Vector2(pr.position.x + 4, sy), String(line), HORIZONTAL_ALIGNMENT_LEFT, pr.size.x, 16, Color(0.82, 0.84, 0.88))
			sy += 22
	# buy button
	var br := _shop_buy_rect()
	var bcol := Color(0.2, 0.42, 0.22)
	if shop_buy_state == "owned": bcol = Color(0.22, 0.28, 0.22)
	elif shop_buy_state == "poor": bcol = Color(0.36, 0.2, 0.18)
	draw_rect(br, bcol)
	draw_rect(br, Color(0.6, 0.85, 0.5) if shop_buy_state == "ok" else Color(0.5, 0.45, 0.4), false, 2.5)
	if font:
		draw_string(font, Vector2(br.position.x, br.position.y + 34), shop_buy_text, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 22, Color.WHITE)

func _map_pt(w: Vector2, m: Rect2) -> Vector2:
	var nx := clampf(w.x / map_world * 0.5 + 0.5, 0.0, 1.0)
	var ny := clampf(w.y / map_world * 0.5 + 0.5, 0.0, 1.0)
	return m.position + Vector2(nx * m.size.x, ny * m.size.y)

func _draw_minimap() -> void:
	if state != 1:
		return
	var v := _vp()
	var font := ThemeDB.fallback_font
	var s := 168.0
	var m := Rect2(v.x - s - 16.0, 150.0, s, s)
	draw_rect(m, Color(0.07, 0.09, 0.12, 0.72))
	draw_rect(m, Color(0.85, 0.7, 0.3, 0.85), false, 2.0)
	for vc in map_villages:
		draw_circle(_map_pt(vc, m), 2.6, Color(0.6, 0.78, 0.55))
	for c in map_cities:
		var pt := _map_pt(c["pos"], m)
		draw_rect(Rect2(pt.x - 4, pt.y - 4, 8, 8), Color(0.95, 0.85, 0.4))
	var sp := _map_pt(map_saray, m)
	draw_rect(Rect2(sp.x - 4, sp.y - 4, 8, 8), Color(0.85, 0.22, 0.18))
	# player arrow (heading)
	var pp := _map_pt(player_pos, m)
	var fwd := Vector2(sin(player_yaw), cos(player_yaw))
	var rgt := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([pp + fwd * 7.0, pp - fwd * 4.0 + rgt * 4.0, pp - fwd * 4.0 - rgt * 4.0]), Color.WHITE)
	if font:
		draw_string(font, Vector2(m.position.x + 6, m.position.y + 16), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.85, 0.95))

func _draw_item_icon(r: Rect2, icon: String) -> void:
	var c := r.position + r.size * 0.5
	var s := minf(r.size.x, r.size.y) * 0.28
	match icon:
		"heal":
			draw_rect(Rect2(c.x - s * 0.35, c.y - s, s * 0.7, s * 1.8), Color(0.8, 0.2, 0.25))
			draw_rect(Rect2(c.x - s * 0.18, c.y - s * 1.25, s * 0.36, s * 0.3), Color(0.6, 0.45, 0.3))
		"str":
			draw_circle(c, s * 0.5, Color(0.85, 0.4, 0.25))
			draw_rect(Rect2(c.x - s, c.y - s * 0.18, s * 2.0, s * 0.36), Color(0.7, 0.7, 0.75))
		"vit":
			var pts := PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(-s * 0.5, -s), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.5, -s), c + Vector2(s, 0)])
			draw_colored_polygon(pts, Color(0.85, 0.25, 0.3))
		"helmet":
			draw_circle(c + Vector2(0, s * 0.1), s * 0.7, Color(0.6, 0.62, 0.7))
			draw_rect(Rect2(c.x - s * 0.7, c.y + s * 0.1, s * 1.4, s * 0.4), Color(0.5, 0.52, 0.6))
		"armor":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s * 0.7, s), c + Vector2(0, s * 1.2), c + Vector2(-s * 0.7, s)]), Color(0.5, 0.6, 0.78))

func _draw_inv() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.55))
	var p := _shop_panel()
	draw_rect(p, Color(0.10, 0.11, 0.13, 0.97))
	draw_rect(p, Color(0.85, 0.7, 0.3, 0.9), false, 3.0)
	if font:
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 40), "СНАРЯЖЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.85, 0.4))
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 70), inv_stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	var cl := _shop_close()
	draw_rect(cl, Color(0.4, 0.15, 0.13))
	if font:
		draw_string(font, cl.position + Vector2(14, 31), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

	if font and inv_upgrades != "":
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 94), inv_upgrades, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.78, 0.5))

	# ---- central equipped-weapon preview, framed by the slots ----
	var sx := _inv_doll_x()
	var top := p.position.y + 110.0
	var ipr := Rect2(sx - 66, top + 64, 132, 150)
	draw_rect(ipr, Color(0.07, 0.08, 0.11))
	var pwrare: bool = inv_slots.size() > 0 and bool(inv_slots[0].get("rare", false))
	draw_rect(ipr, Color(0.95, 0.8, 0.35) if pwrare else Color(0.4, 0.4, 0.46), false, 2.0)
	if inv_is3d and preview_tex != null:
		draw_texture_rect(preview_tex, ipr, false)
	elif font:
		draw_string(font, ipr.position + Vector2(0, ipr.size.y * 0.5), "Кулаки", HORIZONTAL_ALIGNMENT_CENTER, ipr.size.x, 16, Color(0.6, 0.6, 0.65))

	# ---- equipment slots ----
	for i in range(4):
		var sd: Dictionary = inv_slots[i] if i < inv_slots.size() else {"label": "", "name": "—", "rare": false}
		var r := _slot_rect(i)
		var nm := String(sd.get("name", "—"))
		var filled := nm != "—"
		var rare: bool = bool(sd.get("rare", false))
		draw_rect(r, Color(0.16, 0.15, 0.13) if filled else Color(0.12, 0.12, 0.15))
		var border := Color(0.95, 0.8, 0.3) if rare else (Color(0.62, 0.56, 0.42) if filled else Color(0.34, 0.34, 0.4))
		draw_rect(r, border, false, 2.5)
		if font:
			draw_string(font, r.position + Vector2(8, 18), String(sd.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 13, Color(0.68, 0.68, 0.74))
			var ncol := Color(1.0, 0.85, 0.35) if rare else (Color.WHITE if filled else Color(0.5, 0.5, 0.55))
			draw_string(font, r.position + Vector2(8, 44), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 15, ncol)
	# weapon name + stats below the doll (clear of the bottom armour slot)
	if font:
		var wn := Color(1.0, 0.85, 0.35) if pwrare else Color.WHITE
		draw_string(font, Vector2(p.position.x + 20, p.position.y + 398), inv_weapon_name, HORIZONTAL_ALIGNMENT_LEFT, p.size.x * 0.46, 18, wn)
		var yy := p.position.y + 424.0
		for line in inv_weapon_stats:
			draw_string(font, Vector2(p.position.x + 24, yy), String(line), HORIZONTAL_ALIGNMENT_LEFT, p.size.x * 0.46, 15, Color(0.82, 0.84, 0.88))
			yy += 21.0
		draw_string(font, Vector2(p.position.x + 20, yy + 6), "Слот → снять  •  мешок → надеть", HORIZONTAL_ALIGNMENT_LEFT, p.size.x * 0.46, 13, Color(0.6, 0.6, 0.66))

	# ---- bag ----
	var bx := p.position.x + p.size.x * 0.52
	if font:
		draw_string(font, Vector2(bx, p.position.y + 128), "МЕШОК — нажми, чтобы надеть", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.85, 0.78, 0.5))
	for i in range(12):
		var rc := _bag_cell(i)
		if rc.position.y + rc.size.y > p.position.y + p.size.y - 12:
			break
		var has_item := i < inv_bag.size()
		var rare2 := has_item and bool(inv_bag[i].get("rare", false))
		draw_rect(rc, Color(0.20, 0.18, 0.12) if rare2 else (Color(0.17, 0.18, 0.16) if has_item else Color(0.13, 0.13, 0.15)))
		draw_rect(rc, Color(0.95, 0.8, 0.3) if rare2 else (Color(0.55, 0.5, 0.4) if has_item else Color(0.32, 0.32, 0.36)), false, 2.0)
		if has_item and font:
			var it: Dictionary = inv_bag[i]
			draw_string(font, rc.position + Vector2(6, 16), String(it.get("tag", "")), HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 8, 11, Color(0.6, 0.6, 0.66))
			var ncol2 := Color(1.0, 0.85, 0.35) if rare2 else Color.WHITE
			draw_string(font, rc.position + Vector2(6, 40), String(it.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 8, 13, ncol2)

func _draw_quest() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.55))
	var p := _quest_panel()
	draw_rect(p, Color(0.10, 0.13, 0.11, 0.97))
	draw_rect(p, Color(0.5, 0.85, 0.45, 0.9), false, 3.0)
	var cl := _quest_close()
	draw_rect(cl, Color(0.4, 0.15, 0.13))
	if font:
		draw_string(font, cl.position + Vector2(14, 31), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(font, Vector2(p.position.x + 24, p.position.y + 46), "ЗАДАНИЕ ЖИТЕЛЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.9, 0.5))
		draw_string(font, Vector2(p.position.x + 24, p.position.y + 92), quest_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		draw_string(font, Vector2(p.position.x + 24, p.position.y + 134), quest_desc, HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 48, 20, Color(0.88, 0.88, 0.85))
		draw_string(font, Vector2(p.position.x + 24, p.position.y + 176), quest_info, HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 48, 20, Color(0.95, 0.85, 0.4))
	var br := _quest_btn_rect()
	draw_rect(br, Color(0.22, 0.42, 0.22))
	draw_rect(br, Color(0.6, 0.9, 0.5, 0.95), false, 3.0)
	if font:
		draw_string(font, Vector2(br.position.x, br.position.y + 36), quest_btn, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 24, Color.WHITE)

func _draw_menu() -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.45))
	if font:
		draw_string(font, Vector2(0, v.y * 0.16), "ВИТЯЗИ НОВГОРОДА", HORIZONTAL_ALIGNMENT_CENTER, v.x, 46, Color(0.9, 0.78, 0.4))
		draw_string(font, Vector2(0, v.y * 0.24), "Выбери витязя", HORIZONTAL_ALIGNMENT_CENTER, v.x, 24, Color.WHITE)
	# network mode buttons
	var nlabels := ["Одиночная", "Создать Wi-Fi", "Найти игру"]
	var nmodes := ["single", "host", "client"]
	for i in range(3):
		var nb := _net_btn(i)
		var sel: bool = net_mode == nmodes[i]
		draw_rect(nb, Color(0.20, 0.26, 0.20) if sel else Color(0.14, 0.15, 0.18, 0.95))
		draw_rect(nb, Color(0.6, 0.9, 0.5, 0.95) if sel else Color(0.5, 0.55, 0.65, 0.85), false, 2.0)
		if font:
			draw_string(font, Vector2(nb.position.x, nb.position.y + 30), nlabels[i], HORIZONTAL_ALIGNMENT_CENTER, nb.size.x, 19, Color.WHITE)
	if font and net_status != "":
		draw_string(font, Vector2(0, v.y * 0.30 + 70.0), net_status, HORIZONTAL_ALIGNMENT_CENTER, v.x, 18, Color(0.7, 0.85, 1.0))
	for i in range(3):
		var r := _char_rect(i)
		var c: Color = CHARS[i][2]
		draw_rect(r, Color(0.12, 0.13, 0.16, 0.92))
		draw_rect(r, c, false, 4.0)
		var cx := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.42
		draw_circle(Vector2(cx, cy), r.size.x * 0.20, c)
		if font:
			draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.74), CHARS[i][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color.WHITE)
			draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.86), CHARS[i][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.85, 0.85, 0.85))
	# graphics quality toggle
	var qb := _quality_btn()
	draw_rect(qb, Color(0.14, 0.16, 0.20, 0.95))
	draw_rect(qb, Color(0.55, 0.6, 0.7, 0.9), false, 2.0)
	if font:
		draw_string(font, Vector2(qb.position.x, qb.position.y + 34), quality_label + "  ⟳", HORIZONTAL_ALIGNMENT_CENTER, qb.size.x, 22, Color(0.88, 0.9, 0.95))

func _draw_end(title: String, col: Color) -> void:
	var v := _vp()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0, 0, 0, 0.6))
	if font:
		draw_string(font, Vector2(0, v.y * 0.42), title, HORIZONTAL_ALIGNMENT_CENTER, v.x, 56, col)
		draw_string(font, Vector2(0, v.y * 0.54), "Повержено врагов: %d   Золото: %d" % [kills, gold], HORIZONTAL_ALIGNMENT_CENTER, v.x, 24, Color.WHITE)
		draw_string(font, Vector2(0, v.y * 0.66), "Коснись, чтобы вернуться в меню", HORIZONTAL_ALIGNMENT_CENTER, v.x, 22, Color(0.85, 0.85, 0.85))
