extends Node3D

const WORLD := 220.0
const CELLS := 84
const AMP := 9.0
const WATER_Y := -3.0
const PLAZA := 120.0

var noise := FastNoiseLite.new()
var controls
var player

var state := "menu"            # menu / play / shop / gameover / win
var kills := 0
var alive := 0
var boss_defeated := false
var near_npc = null

# day/night
var sky_mat: ProceduralSkyMaterial
var env: Environment
var sun: DirectionalLight3D
var day_t := 0.16

var shop := [
	{"name": "Лечебное зелье (+40 HP)", "price": 25, "kind": "heal", "v": 40.0},
	{"name": "Боевой топор", "price": 70, "kind": "weapon", "v": 2},
	{"name": "Двуручный меч", "price": 150, "kind": "weapon", "v": 1},
	{"name": "Секира", "price": 175, "kind": "weapon", "v": 3},
	{"name": "Кинжал", "price": 55, "kind": "weapon", "v": 4},
	{"name": "Копьё", "price": 120, "kind": "weapon", "v": 5},
	{"name": "Арбалет (дальний бой)", "price": 170, "kind": "weapon", "v": 6},
	{"name": "Меч", "price": 60, "kind": "weapon", "v": 0},
	{"name": "Круглый щит", "price": 55, "kind": "shield", "v": 1},
	{"name": "Большой щит", "price": 130, "kind": "shield", "v": 2},
	{"name": "Шлем", "price": 50, "kind": "helmet", "v": 0},
	{"name": "Кольчуга (броня)", "price": 90, "kind": "armortier", "v": 1},
	{"name": "Латный доспех (броня)", "price": 200, "kind": "armortier", "v": 2},
	{"name": "Эликсир силы (+40 макс HP)", "price": 120, "kind": "maxhp", "v": 40.0},
]
var _inv_actions: Array = []

func _ready() -> void:
	randomize()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	noise.seed = randi()

	_build_environment()
	_build_terrain()
	_build_floor()
	_build_water()
	_scatter_trees(260)
	_build_town()
	_build_villages()
	_spawn_player()
	_setup_ui()
	state = "menu"
	controls.state = 0

	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest()

func _run_selftest() -> void:
	start_game(0)
	await get_tree().create_timer(1.5).timeout
	print("SELFTEST enemies=%d npcs=%d pickups=%d gold=%d player=%s" % [
		get_tree().get_nodes_in_group("enemy").size(),
		get_tree().get_nodes_in_group("npc").size(),
		get_tree().get_nodes_in_group("pickup").size(),
		player.gold, str(player.global_position)])
	get_tree().quit(0 if get_tree().get_nodes_in_group("enemy").size() > 0 else 1)

func terrain_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var t := clampf((d - PLAZA) / 45.0, 0.0, 1.0)
	t = t * t
	return noise.get_noise_2d(x, z) * AMP * t

# ---------------- environment / day-night ----------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.5, 0.74)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.83)
	sky_mat.ground_horizon_color = Color(0.65, 0.66, 0.62)
	sky_mat.ground_bottom_color = Color(0.36, 0.4, 0.36)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.85)
	env.fog_density = 0.0028
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -120, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

func _update_daynight(delta: float) -> void:
	day_t += delta / 150.0
	var s := sin(day_t * TAU)
	var up := clampf((s + 1.0) * 0.5, 0.0, 1.0)
	sun.rotation_degrees = Vector3(lerp(-3.0, -85.0, up), -120.0, 0.0)
	sun.light_energy = lerp(0.06, 1.2, up)
	sun.light_color = Color(1.0, 0.7, 0.5).lerp(Color(1.0, 0.96, 0.88), up)
	sky_mat.sky_top_color = Color(0.05, 0.06, 0.12).lerp(Color(0.32, 0.5, 0.74), up)
	sky_mat.sky_horizon_color = Color(0.12, 0.11, 0.2).lerp(Color(0.80, 0.82, 0.83), up)
	env.ambient_light_energy = lerp(0.2, 0.6, up)
	env.fog_light_color = Color(0.10, 0.12, 0.22).lerp(Color(0.78, 0.82, 0.85), up)

# ---------------- terrain ----------------

func _build_terrain() -> void:
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (WORLD * 2.0) / float(CELLS)
	for j in range(CELLS):
		for i in range(CELLS):
			var x0 := -WORLD + i * step
			var z0 := -WORLD + j * step
			var x1 := x0 + step
			var z1 := z0 + step
			var v00 := Vector3(x0, terrain_height(x0, z0), z0)
			var v10 := Vector3(x1, terrain_height(x1, z0), z0)
			var v01 := Vector3(x0, terrain_height(x0, z1), z1)
			var v11 := Vector3(x1, terrain_height(x1, z1), z1)
			_add_tri(stool, v00, v01, v11)
			_add_tri(stool, v00, v11, v10)
	stool.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	stool.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = stool.commit()
	mi.name = "Terrain"
	add_child(mi)

func _build_floor() -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	b.add_child(cs)
	add_child(b)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var slope := 1.0
	if n.length() > 0.0:
		slope = clampf(n.normalized().dot(Vector3.UP), 0.0, 1.0)
	for v in [a, b, c]:
		st.set_color(_ground_color(v.y, slope))
		st.add_vertex(v)

func _ground_color(h: float, slope: float) -> Color:
	if h < WATER_Y + 1.2:
		return Color(0.72, 0.66, 0.45)
	if slope < 0.78:
		return Color(0.42, 0.40, 0.37)
	return Color(0.36, 0.49, 0.28).lerp(Color(0.30, 0.43, 0.24), fmod(absf(h) * 0.7, 1.0))

func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD * 2.4, WORLD * 2.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.42, 0.55, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0, WATER_Y, 0)
	add_child(mi)

# ---------------- props ----------------

func _scatter_trees(count: int) -> void:
	for n in range(count):
		var x := randf_range(-WORLD + 8, WORLD - 8)
		var z := randf_range(-WORLD + 8, WORLD - 8)
		var d := Vector2(x, z).length()
		if d < 30.0 or d > 205.0:
			continue
		_make_tree(Vector3(x, terrain_height(x, z), z))

func _make_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	var sc := randf_range(0.8, 1.6)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.18 * sc; tm.bottom_radius = 0.26 * sc; tm.height = 2.2 * sc
	trunk.mesh = tm; trunk.material_override = _flat(Color(0.36, 0.26, 0.17)); trunk.position = Vector3(0, 1.1 * sc, 0)
	root.add_child(trunk)
	var leaves := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 1.5 * sc; cm.height = 3.0 * sc
	leaves.mesh = cm
	leaves.material_override = _flat(Color(0.20, 0.42, 0.22).lerp(Color(0.28, 0.5, 0.26), randf()))
	leaves.position = Vector3(0, 3.4 * sc, 0)
	root.add_child(leaves)
	root.rotate_y(randf() * TAU)
	add_child(root)

func _build_town() -> void:
	_church(Vector3(0, 0, -4))
	var ring := 37.0
	var seg := 20
	var gate := PI * 0.5
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		if absf(_angdiff(a, gate)) < 0.33:
			continue
		var x := cos(a) * ring
		var z := sin(a) * ring
		_wall(Vector3(x, 0, z), atan2(x, z))
	for i in range(0, seg, 5):
		var a2 := TAU * float(i) / float(seg)
		_tower(Vector3(cos(a2) * ring, 0, sin(a2) * ring))
	for s in [Vector3(-18, 0, -10), Vector3(18, 0, -10), Vector3(-20, 0, 12), Vector3(20, 0, 12)]:
		_izba(s)
	_make_npc(Vector3(8, 0, 4))      # town merchant

func _build_villages() -> void:
	for center in [Vector3(-78, 0, -34), Vector3(80, 0, 50), Vector3(-90, 0, 60), Vector3(95, 0, -40)]:
		for off in [Vector3(-6, 0, -5), Vector3(7, 0, -4), Vector3(-5, 0, 7), Vector3(8, 0, 8), Vector3(0, 0, -9)]:
			_izba(center + off)
		_make_npc(center)
	# a couple of lone landmarks for exploration
	_tower(Vector3(0, 0, 110))
	_tower(Vector3(-110, 0, 0))
	_church(Vector3(115, 0, 95))

func _make_npc(pos: Vector3) -> void:
	var npc := GameNpc.new()
	add_child(npc)
	npc.global_position = pos

func _angdiff(a: float, b: float) -> float:
	return fmod(a - b + PI, TAU) - PI

func _solid(root: Node3D, size: Vector3, center: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	sb.add_child(cs)
	root.add_child(sb)

func _wall(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(12.0, 5.0, 1.3)
	w.mesh = bm; w.material_override = _flat(Color(0.52, 0.43, 0.33)); w.position = Vector3(0, 2.5, 0)
	root.add_child(w)
	for k in [-4.0, 0.0, 4.0]:
		var mer := MeshInstance3D.new()
		var mm := BoxMesh.new(); mm.size = Vector3(1.7, 1.2, 1.6)
		mer.mesh = mm; mer.material_override = _flat(Color(0.46, 0.38, 0.30)); mer.position = Vector3(k, 5.4, 0)
		root.add_child(mer)
	_solid(root, Vector3(12.0, 5.0, 1.3), Vector3(0, 2.5, 0))

func _church(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(7, 7, 7)
	body.mesh = bm; body.material_override = _flat(Color(0.86, 0.84, 0.78)); body.position = Vector3(0, 3.5, 0)
	root.add_child(body)
	var drum := MeshInstance3D.new()
	var dc := CylinderMesh.new(); dc.top_radius = 1.1; dc.bottom_radius = 1.1; dc.height = 1.6
	drum.mesh = dc; drum.material_override = _flat(Color(0.8, 0.78, 0.72)); drum.position = Vector3(0, 7.8, 0)
	root.add_child(drum)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.5; sm.height = 2.6
	dome.mesh = sm
	var gm := _flat(Color(0.85, 0.69, 0.22)); gm.metallic = 0.6; gm.roughness = 0.3
	dome.material_override = gm; dome.position = Vector3(0, 9.4, 0)
	root.add_child(dome)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(0.1, 1.2, 0.1)
	cross.mesh = cb; cross.material_override = _flat(Color(0.9, 0.78, 0.3)); cross.position = Vector3(0, 11.2, 0)
	root.add_child(cross)
	_solid(root, Vector3(7, 7, 7), Vector3(0, 3.5, 0))

func _tower(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4, 9, 4)
	body.mesh = bm; body.material_override = _flat(Color(0.55, 0.45, 0.34)); body.position = Vector3(0, 4.5, 0)
	root.add_child(body)
	var roof := MeshInstance3D.new()
	var rc := CylinderMesh.new(); rc.top_radius = 0.0; rc.bottom_radius = 3.2; rc.height = 3.5
	roof.mesh = rc; roof.material_override = _flat(Color(0.38, 0.3, 0.24)); roof.position = Vector3(0, 10.6, 0)
	root.add_child(roof)
	_solid(root, Vector3(4, 9, 4), Vector3(0, 4.5, 0))

func _izba(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4, 3, 5)
	body.mesh = bm; body.material_override = _flat(Color(0.46, 0.34, 0.22)); body.position = Vector3(0, 1.5, 0)
	root.add_child(body)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(4.6, 2.0, 5.4)
	roof.mesh = pr; roof.material_override = _flat(Color(0.34, 0.26, 0.18)); roof.position = Vector3(0, 4.0, 0)
	root.add_child(roof)
	root.rotate_y(randf() * TAU)
	_solid(root, Vector3(4, 3, 5), Vector3(0, 1.5, 0))

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

# ---------------- actors / game flow ----------------

func _spawn_player() -> void:
	player = preload("res://Player.gd").new()
	player.main = self
	add_child(player)
	player.global_position = Vector3(0, 2.0, 12)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	controls = preload("res://TouchControls.gd").new()
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(controls)
	player.controls = controls

func start_game(id: int) -> void:
	_clear_actors()
	player.set_character(id)
	player.hp = player.max_hp
	player.gold = 80
	player.global_position = Vector3(0, 2.0, 12)
	player.velocity = Vector3.ZERO
	kills = 0; alive = 0
	boss_defeated = false
	state = "play"
	controls.state = 1
	_spawn_world_enemies()
	_spawn_pickups()

func _clear_actors() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for p in get_tree().get_nodes_in_group("proj"):
		p.queue_free()
	for pk in get_tree().get_nodes_in_group("pickup"):
		pk.queue_free()
	alive = 0

func _spawn_world_enemies() -> void:
	var camps := [Vector3(75, 0, 18), Vector3(-58, 0, 60), Vector3(22, 0, -85),
		Vector3(-80, 0, -55), Vector3(95, 0, -75), Vector3(-40, 0, 95),
		Vector3(60, 0, 95), Vector3(-105, 0, 25)]
	for c in camps:
		_spawn_camp(c, false)
	_spawn_camp(Vector3(0, 0, -110), true)   # boss camp

func _spawn_camp(center: Vector3, boss: bool) -> void:
	var n := randi_range(3, 5)
	for i in range(n):
		var r := randf()
		var k := GameEnemy.Kind.RAIDER
		if r < 0.25: k = GameEnemy.Kind.ARCHER
		elif r < 0.5: k = GameEnemy.Kind.SPEARMAN
		elif r < 0.65: k = GameEnemy.Kind.BRUTE
		var off := Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		_make_enemy(k, center + off)
	if boss:
		_make_enemy(GameEnemy.Kind.BOSS, center)

func _make_enemy(kind: int, pos: Vector3) -> void:
	var e := GameEnemy.new()
	e.kind = kind
	e.main = self
	e.home = pos
	e.gold_drop = _gold_for(kind)
	add_child(e)
	e.global_position = pos + Vector3(0, 3, 0)
	alive += 1

func _gold_for(kind: int) -> int:
	match kind:
		GameEnemy.Kind.BRUTE: return 22
		GameEnemy.Kind.BOSS: return 200
		GameEnemy.Kind.ARCHER: return 10
		GameEnemy.Kind.SPEARMAN: return 10
		_: return 8

func _spawn_pickups() -> void:
	for i in range(20):
		_make_pickup("gold", randf_range(12, 35), _rand_spot())
	for i in range(3):
		_make_pickup("weapon", randf_range(10, 24), _rand_spot())
	for i in range(3):
		_make_pickup("armor", randf_range(0.08, 0.14), _rand_spot())
	for i in range(2):
		_make_pickup("heal", 40.0, _rand_spot())

func _rand_spot() -> Vector3:
	var a := randf() * TAU
	var d := randf_range(22.0, 115.0)
	return Vector3(cos(a) * d, 1.0, sin(a) * d)

func _make_pickup(kind: String, value: float, pos: Vector3) -> void:
	var pk := GamePickup.new()
	pk.kind = kind
	pk.value = value
	pk.main = self
	add_child(pk)
	pk.global_position = pos

func on_enemy_killed(pos: Vector3, gold: int) -> void:
	kills += 1
	alive -= 1
	if player:
		player.add_gold(gold)
	if randf() < 0.35:
		_make_pickup("gold", randf_range(6, 16), pos + Vector3(0, 1, 0))
	if boss_defeated:
		_win()

func on_boss_killed() -> void:
	boss_defeated = true
	show_toast("Воевода повержен! Новгород свободен!")

func show_toast(text: String) -> void:
	if controls:
		controls.toast = text
		controls.toast_t = 2.5

func _shop_owned(item) -> bool:
	match item["kind"]:
		"weapon": return int(item["v"]) in player.owned_weapons
		"shield": return int(item["v"]) in player.owned_shields
		"helmet": return player.helmet_owned
		"armortier": return player.armor_tier >= int(item["v"])
		_: return false

func buy(index: int) -> void:
	if index < 0 or index >= shop.size():
		return
	var item = shop[index]
	if _shop_owned(item):
		show_toast("Уже куплено")
		return
	if player.gold < item["price"]:
		show_toast("Не хватает золота")
		return
	player.gold -= item["price"]
	match item["kind"]:
		"heal": player.heal(item["v"])
		"maxhp": player.add_maxhp(item["v"])
		"weapon": player.own_weapon(int(item["v"])); show_toast("Куплено! Наденьте в снаряжении (☰)")
		"shield": player.own_shield(int(item["v"])); show_toast("Куплено! Наденьте в снаряжении (☰)")
		"helmet": player.helmet_owned = true; show_toast("Шлем куплен — наденьте в снаряжении")
		"armortier": player.set_armor_tier(int(item["v"])); show_toast("Доспех надет")
	if item["kind"] in ["heal", "maxhp", "armortier"]:
		show_toast("Куплено: " + item["name"])
	_refresh_shop_state()

func _process(delta: float) -> void:
	_update_daynight(delta)

	if controls and player:
		controls.hp_frac = clampf(player.hp / player.max_hp, 0.0, 1.0)
		controls.kills = kills
		controls.gold = player.gold

	match state:
		"menu":
			var c: int = controls.consume_chosen()
			if c >= 0:
				start_game(c)
		"play":
			_update_interaction()
			if player.hp <= 0.0:
				_game_over()
				return
			if controls.consume_interact() and near_npc != null:
				_open_shop()
			if controls.consume_inventory():
				_open_inventory()
		"inv":
			var ei: int = controls.consume_equip()
			if ei >= 0 and ei < _inv_actions.size():
				var a = _inv_actions[ei]
				match a["t"]:
					"w": player.equip_weapon(a["v"])
					"s": player.equip_shield(a["v"])
					"helm": player.toggle_helmet()
				_refresh_inv()
			if controls.consume_close():
				state = "play"
				controls.state = 1
		"shop":
			var bi: int = controls.consume_buy()
			if bi >= 0:
				buy(bi)
			if controls.consume_close():
				state = "play"
				controls.state = 1
		"gameover", "win":
			if controls.consume_restart():
				_to_menu()

func _update_interaction() -> void:
	near_npc = null
	var best := 5.0
	for n in get_tree().get_nodes_in_group("npc"):
		var d: float = n.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			near_npc = n
	controls.can_interact = near_npc != null

func _open_inventory() -> void:
	_refresh_inv()
	state = "inv"
	controls.state = 5

func _refresh_inv() -> void:
	var rows := []
	var flags := []
	var acts := []
	rows.append("— ОРУЖИЕ —"); flags.append(false); acts.append({"t": "h"})
	for wi in player.owned_weapons:
		rows.append("  " + player.WEAPONS[wi]["name"])
		flags.append(wi == player.equipped_weapon)
		acts.append({"t": "w", "v": wi})
	rows.append("— ЩИТ —"); flags.append(false); acts.append({"t": "h"})
	for si in player.owned_shields:
		rows.append("  " + player.SHIELDS[si]["name"])
		flags.append(si == player.equipped_shield)
		acts.append({"t": "s", "v": si})
	if player.helmet_owned:
		rows.append("— ПРОЧЕЕ —"); flags.append(false); acts.append({"t": "h"})
		rows.append("  Шлем"); flags.append(player.helmet_on); acts.append({"t": "helm"})
	controls.inv_rows = rows
	controls.inv_flags = flags
	_inv_actions = acts
	controls.inv_stats = "Урон: %d    Броня: %d%%    HP: %d/%d    Золото: %d    (доспех: %s)" % [
		player.total_dmg(), int(player.armor * 100), int(player.hp), int(player.max_hp), player.gold,
		player.ARMOR_NAMES[player.armor_tier]]

func _open_shop() -> void:
	_refresh_shop_state()
	state = "shop"
	controls.state = 4

func _refresh_shop_state() -> void:
	var names := []
	var owned := []
	for it in shop:
		names.append("%s — %d з." % [it["name"], it["price"]])
		owned.append(_shop_owned(it))
	controls.shop_names = names
	controls.shop_owned = owned

func _game_over() -> void:
	state = "gameover"
	controls.state = 2

func _win() -> void:
	state = "win"
	controls.state = 3

func _to_menu() -> void:
	_clear_actors()
	state = "menu"
	controls.state = 0
