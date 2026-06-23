extends Node3D

const WORLD := 220.0
const CELLS := 84
const AMP := 9.0
const WATER_Y := -3.0
const PLAZA := 120.0

var noise := FastNoiseLite.new()
var controls
var player

var village_centers := [Vector3(-78, 0, -34), Vector3(80, 0, 50), Vector3(-90, 0, 60), Vector3(95, 0, -40)]

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
var _bag_items: Array = []   # parallel to controls.inv_bag: [{"kind","v"}]

var quests := [
	{"title": "Очистка дорог", "desc": "Победи 6 врагов в округе.", "type": "kills", "target": 6, "reward": 70, "weapon": 7, "weapon_name": "Меч-кладенец"},
	{"title": "Казна княжества", "desc": "Накопи 200 золота.", "type": "gold", "target": 200, "reward": 90, "weapon": 9, "weapon_name": "Лук Соловья"},
	{"title": "Древние реликвии", "desc": "Собери 5 артефактов.", "type": "pickups", "target": 5, "reward": 120, "weapon": 8, "weapon_name": "Секира Перуна"},
]
var quest_idx := 0
var quest_active := false
var kills_base := 0
var pickups_collected := 0
var pickups_base := 0

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
	_scatter_ground_detail()
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
	# exercise equipment / inventory code paths
	player.own_weapon(7); player.equip_weapon(7)        # rare sword (tint path)
	player.unequip_weapon()
	player.own_shield(1); player.equip_shield(1); player.equip_shield(0)
	player.own_armor(2); player.equip_armor(2); player.unequip_armor()
	player.helmet_owned = true; player.toggle_helmet(); player.toggle_helmet()
	player.equip_weapon(player.owned_weapons[0])
	_refresh_inv()
	print("SELFTEST inv slots=%d bag=%d dmg=%d" % [controls.inv_slots.size(), controls.inv_bag.size(), player.total_dmg()])
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
		st.set_color(_ground_color(v, slope))
		st.add_vertex(v)

func _ground_color(p: Vector3, slope: float) -> Color:
	var h := p.y
	var d := Vector2(p.x, p.z).length()
	# sand by the water
	if h < WATER_Y + 1.2:
		return Color(0.74, 0.68, 0.48).lerp(Color(0.66, 0.60, 0.42), _checker(p, 1.3))
	# town square — cobblestone paving with checkered mortar
	if d < 40.0:
		var stone := Color(0.50, 0.50, 0.53).lerp(Color(0.40, 0.40, 0.44), _checker(p, 1.1))
		# main roads radiating from the kremlin stay lighter
		return stone.lerp(Color(0.58, 0.57, 0.55), 0.25 * _checker(p, 0.55))
	# dirt courtyards around the villages
	for vc in village_centers:
		var vd := Vector2(p.x - vc.x, p.z - vc.z).length()
		if vd < 16.0:
			var f := clampf(vd / 16.0, 0.0, 1.0)
			var dirt := Color(0.46, 0.37, 0.26).lerp(Color(0.40, 0.32, 0.22), _checker(p, 1.7))
			return dirt.lerp(_grass(p), f * f)
	# steep slopes show bare earth/rock
	if slope < 0.74:
		return Color(0.44, 0.40, 0.35).lerp(Color(0.36, 0.32, 0.28), _checker(p, 0.9))
	return _grass(p)

func _grass(p: Vector3) -> Color:
	var n := (noise.get_noise_2d(p.x * 2.3, p.z * 2.3) + 1.0) * 0.5
	var n2 := (noise.get_noise_2d(p.x * 9.0 + 50.0, p.z * 9.0) + 1.0) * 0.5
	var base := Color(0.27, 0.44, 0.22).lerp(Color(0.40, 0.56, 0.28), n)
	return base.lerp(Color(0.34, 0.50, 0.24), n2 * 0.4)

func _checker(p: Vector3, scale: float) -> float:
	var s := sin(p.x * scale) * sin(p.z * scale)
	return clampf(s * 0.5 + 0.5, 0.0, 1.0)

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

# ---- ground clutter (grass tufts, pebbles, flowers) via MultiMesh ----
func _scatter_ground_detail() -> void:
	_multimesh_scatter(_grass_blade_mesh(), 3000, 46.0, 200.0, 0.6, 1.5, true)
	_multimesh_scatter(_pebble_mesh(), 800, 24.0, 205.0, 0.6, 1.6, false)
	_multimesh_scatter(_flower_mesh(), 420, 50.0, 195.0, 0.7, 1.3, true)

func _multimesh_scatter(mesh: Mesh, count: int, dmin: float, dmax: float, smin: float, smax: float, grass_only: bool) -> void:
	var xforms := []
	var tries := 0
	while xforms.size() < count and tries < count * 5:
		tries += 1
		var x := randf_range(-WORLD + 10, WORLD - 10)
		var z := randf_range(-WORLD + 10, WORLD - 10)
		var d := Vector2(x, z).length()
		if d < dmin or d > dmax:
			continue
		var y := terrain_height(x, z)
		if y < WATER_Y + 1.0:
			continue
		if grass_only:
			# skip the dirt rings around villages
			var skip := false
			for vc in village_centers:
				if Vector2(x - vc.x, z - vc.z).length() < 14.0:
					skip = true
					break
			if skip:
				continue
		var b := Basis().rotated(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(smin, smax))
		xforms.append(Transform3D(b, Vector3(x, y, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _grass_blade_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.34, 0.52, 0.24)
	var coltip := Color(0.46, 0.62, 0.30)
	# three crossed blades
	for k in range(3):
		var a := float(k) * 2.1
		var dx := cos(a) * 0.08
		var dz := sin(a) * 0.08
		st.set_color(col); st.add_vertex(Vector3(-dx, 0, -dz))
		st.set_color(col); st.add_vertex(Vector3(dx, 0, dz))
		st.set_color(coltip); st.add_vertex(Vector3(dz * 0.4, 0.42, -dx * 0.4))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m)
	return st.commit()

func _pebble_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.13; sm.height = 0.18
	sm.radial_segments = 6; sm.rings = 3
	sm.material = _flat(Color(0.5, 0.48, 0.45))
	return sm

func _flower_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.09; sm.height = 0.16
	sm.radial_segments = 5; sm.rings = 3
	var m := _flat(Color(0.9, 0.85, 0.35))
	m.emission_enabled = true; m.emission = Color(0.7, 0.6, 0.2); m.emission_energy_multiplier = 0.3
	sm.material = m
	return sm

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
	_make_npc(Vector3(8, 0, 4))                 # town merchant
	_make_npc(Vector3(-8, 0, 4), "quest")       # town quest-giver
	# torches: flanking the gate, by the church and the square
	_torch(self, Vector3(cos(gate) * ring - 3, 0, sin(gate) * ring))
	_torch(self, Vector3(cos(gate) * ring + 3, 0, sin(gate) * ring))
	_torch(self, Vector3(-5, 0, 1))
	_torch(self, Vector3(5, 0, 1))
	_torch(self, Vector3(0, 0, 14))

func _build_villages() -> void:
	var vi := 0
	for center in village_centers:
		var oi := 0
		for off in [Vector3(-7, 0, -6), Vector3(8, 0, -5), Vector3(-6, 0, 8), Vector3(9, 0, 9), Vector3(0, 0, -11)]:
			_izba(center + off, oi == 0)   # one barn-style house per village
			oi += 1
		# a village well in the middle
		_well(center)
		_torch(self, center + Vector3(-3, 0, 3))
		_make_npc(center + Vector3(2, 0, 2))
		# every other village also has a quest-giver
		if vi % 2 == 1:
			_make_npc(center + Vector3(3, 0, 3), "quest")
		vi += 1
	# a couple of lone landmarks for exploration
	_tower(Vector3(0, 0, 110))
	_tower(Vector3(-110, 0, 0))
	_church(Vector3(115, 0, 95))

func _make_npc(pos: Vector3, kind := "merchant") -> void:
	var npc := GameNpc.new()
	npc.kind = kind
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

# a wall slab that is both visible and solid
func _wall_seg(root: Node3D, size: Vector3, center: Vector3, col: Color) -> void:
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	w.mesh = bm; w.material_override = _flat(col); w.position = center
	root.add_child(w)
	_solid(root, size, center)

# dark glass pane (visual only, slightly proud of the wall)
func _window(root: Node3D, size: Vector3, center: Vector3) -> void:
	var win := MeshInstance3D.new()
	var wb := BoxMesh.new(); wb.size = size
	win.mesh = wb
	var m := _flat(Color(0.14, 0.16, 0.24)); m.roughness = 0.12; m.metallic = 0.2
	m.emission_enabled = true; m.emission = Color(0.20, 0.18, 0.10); m.emission_energy_multiplier = 0.25
	win.material_override = m; win.position = center
	root.add_child(win)
	# wooden frame, slightly larger and set just behind the pane
	var fr := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(size.x * 0.9, size.y + 0.22, size.z + 0.22)
	fr.mesh = fb; fr.material_override = _flat(Color(0.30, 0.21, 0.13))
	fr.position = center - Vector3(0.02 * signf(center.x), 0.0, 0.0)
	root.add_child(fr)

func _church(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var wcol := Color(0.87, 0.85, 0.79)
	var hx := 3.6; var hz := 3.6; var hh := 7.0; var t := 0.4
	# stone floor
	var fl := MeshInstance3D.new()
	var fb := BoxMesh.new(); fb.size = Vector3(hx * 2, 0.16, hz * 2)
	fl.mesh = fb; fl.material_override = _flat(Color(0.58, 0.56, 0.52)); fl.position = Vector3(0, 0.08, 0)
	root.add_child(fl)
	# walls with a tall doorway on +Z
	_wall_seg(root, Vector3(hx * 2 + t, hh, t), Vector3(0, hh * 0.5, -hz), wcol)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(-hx, hh * 0.5, 0), wcol)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(hx, hh * 0.5, 0), wcol)
	var dw := 1.9
	var seg := (hx * 2 - dw) * 0.5
	_wall_seg(root, Vector3(seg, hh, t), Vector3(-(dw * 0.5 + seg * 0.5), hh * 0.5, hz), wcol)
	_wall_seg(root, Vector3(seg, hh, t), Vector3(dw * 0.5 + seg * 0.5, hh * 0.5, hz), wcol)
	_wall_seg(root, Vector3(dw, hh - 3.2, t), Vector3(0, hh - (hh - 3.2) * 0.5, hz), wcol)
	# tall arched windows on the sides
	for zz in [-1.6, 1.6]:
		_window(root, Vector3(0.12, 2.4, 1.0), Vector3(-hx - 0.02, 3.6, zz))
		_window(root, Vector3(0.12, 2.4, 1.0), Vector3(hx + 0.02, 3.6, zz))
	# cornice + drum + golden dome + cross
	var cornice := MeshInstance3D.new()
	var cc := BoxMesh.new(); cc.size = Vector3(hx * 2 + 0.9, 0.55, hz * 2 + 0.9)
	cornice.mesh = cc; cornice.material_override = _flat(Color(0.79, 0.77, 0.71)); cornice.position = Vector3(0, hh, 0)
	root.add_child(cornice)
	var drum := MeshInstance3D.new()
	var dc := CylinderMesh.new(); dc.top_radius = 1.1; dc.bottom_radius = 1.1; dc.height = 1.8
	drum.mesh = dc; drum.material_override = _flat(Color(0.81, 0.79, 0.73)); drum.position = Vector3(0, hh + 1.1, 0)
	root.add_child(drum)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.5; sm.height = 2.8
	dome.mesh = sm
	var gm := _flat(Color(0.86, 0.70, 0.22)); gm.metallic = 0.7; gm.roughness = 0.25
	dome.material_override = gm; dome.position = Vector3(0, hh + 2.9, 0)
	root.add_child(dome)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(0.12, 1.5, 0.12)
	cross.mesh = cb; cross.material_override = _flat(Color(0.92, 0.80, 0.32)); cross.position = Vector3(0, hh + 4.8, 0)
	root.add_child(cross)
	var cbar := MeshInstance3D.new()
	var cbm := BoxMesh.new(); cbm.size = Vector3(0.7, 0.12, 0.12)
	cbar.mesh = cbm; cbar.material_override = _flat(Color(0.92, 0.80, 0.32)); cbar.position = Vector3(0, hh + 5.0, 0)
	root.add_child(cbar)

func _tower(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4, 9, 4)
	body.mesh = bm; body.material_override = _flat(Color(0.55, 0.45, 0.34)); body.position = Vector3(0, 4.5, 0)
	root.add_child(body)
	# corner posts for a timbered look
	for sx in [-1.9, 1.9]:
		for sz in [-1.9, 1.9]:
			var post := MeshInstance3D.new()
			var pb := BoxMesh.new(); pb.size = Vector3(0.4, 9.2, 0.4)
			post.mesh = pb; post.material_override = _flat(Color(0.42, 0.33, 0.24)); post.position = Vector3(sx, 4.6, sz)
			root.add_child(post)
	# arrow-slit windows
	for sz2 in [-1.0, 1.0]:
		_window(root, Vector3(0.1, 1.2, 0.4), Vector3(2.02, 6.0, sz2))
		_window(root, Vector3(0.1, 1.2, 0.4), Vector3(-2.02, 6.0, sz2))
	var roof := MeshInstance3D.new()
	var rc := CylinderMesh.new(); rc.top_radius = 0.0; rc.bottom_radius = 3.2; rc.height = 3.5
	roof.mesh = rc; roof.material_override = _flat(Color(0.38, 0.3, 0.24)); roof.position = Vector3(0, 10.6, 0)
	root.add_child(roof)
	_solid(root, Vector3(4, 9, 4), Vector3(0, 4.5, 0))

func _well(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.1; cm.height = 1.2
	ring.mesh = cm; ring.material_override = _flat(Color(0.5, 0.5, 0.52)); ring.position = Vector3(0, 0.6, 0)
	root.add_child(ring)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.18, 2.4, 0.18)
		post.mesh = pb; post.material_override = _flat(Color(0.4, 0.3, 0.2)); post.position = Vector3(sx, 1.8, 0)
		root.add_child(post)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(2.8, 0.9, 1.6)
	roof.mesh = pr; roof.material_override = _flat(Color(0.34, 0.26, 0.18)); roof.position = Vector3(0, 3.2, 0)
	root.add_child(roof)
	_solid(root, Vector3(2.2, 1.2, 2.2), Vector3(0, 0.6, 0))

# enterable log house; big -> larger village hall
func _izba(pos: Vector3, big := false) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	root.rotate_y(randf() * TAU)
	var hx := 2.5 if big else 2.0
	var hz := 3.1 if big else 2.5
	var hh := 3.3 if big else 2.7
	var t := 0.3
	var logc := Color(0.50, 0.37, 0.24) if big else Color(0.46, 0.34, 0.22)
	# plank floor
	var fl := MeshInstance3D.new()
	var fb := BoxMesh.new(); fb.size = Vector3(hx * 2, 0.1, hz * 2)
	fl.mesh = fb; fl.material_override = _flat(Color(0.36, 0.27, 0.18)); fl.position = Vector3(0, 0.05, 0)
	root.add_child(fl)
	# walls with door gap on +Z
	_wall_seg(root, Vector3(hx * 2 + t, hh, t), Vector3(0, hh * 0.5, -hz), logc)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(-hx, hh * 0.5, 0), logc)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(hx, hh * 0.5, 0), logc)
	var dw := 1.3
	var seg := (hx * 2 - dw) * 0.5
	_wall_seg(root, Vector3(seg, hh, t), Vector3(-(dw * 0.5 + seg * 0.5), hh * 0.5, hz), logc)
	_wall_seg(root, Vector3(seg, hh, t), Vector3(dw * 0.5 + seg * 0.5, hh * 0.5, hz), logc)
	_wall_seg(root, Vector3(dw + 0.2, hh - 2.1, t), Vector3(0, hh - (hh - 2.1) * 0.5, hz), logc)
	# door-frame posts (decor)
	for dx in [-dw * 0.5 - 0.05, dw * 0.5 + 0.05]:
		var jamb := MeshInstance3D.new()
		var jb := BoxMesh.new(); jb.size = Vector3(0.14, 2.1, 0.36)
		jamb.mesh = jb; jamb.material_override = _flat(Color(0.32, 0.22, 0.14)); jamb.position = Vector3(dx, 1.05, hz)
		root.add_child(jamb)
	# shuttered windows on the sides
	for zz in [-0.9, 0.9]:
		_window(root, Vector3(0.1, 0.8, 0.8), Vector3(-hx - 0.02, 1.6, zz))
		_window(root, Vector3(0.1, 0.8, 0.8), Vector3(hx + 0.02, 1.6, zz))
	# gable roof
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(hx * 2 + 0.7, 2.2, hz * 2 + 0.7)
	roof.mesh = pr; roof.material_override = _flat(Color(0.33, 0.25, 0.17)); roof.position = Vector3(0, hh + 1.0, 0)
	root.add_child(roof)
	# chimney with a faint glow
	var ch := MeshInstance3D.new()
	var cbx := BoxMesh.new(); cbx.size = Vector3(0.5, 1.5, 0.5)
	ch.mesh = cbx; ch.material_override = _flat(Color(0.42, 0.40, 0.40)); ch.position = Vector3(hx * 0.55, hh + 1.7, -hz * 0.4)
	root.add_child(ch)
	# log-cabin corner posts
	var logend := _flat(Color(0.40, 0.29, 0.18))
	for cx in [-hx, hx]:
		for cz in [-hz, hz]:
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new(); pc.top_radius = 0.22; pc.bottom_radius = 0.24; pc.height = hh + 0.1
			post.mesh = pc; post.material_override = logend; post.position = Vector3(cx, (hh + 0.1) * 0.5, cz)
			root.add_child(post)
	# foundation sill
	var sill := MeshInstance3D.new()
	var sb := BoxMesh.new(); sb.size = Vector3(hx * 2 + 0.5, 0.4, hz * 2 + 0.5)
	sill.mesh = sb; sill.material_override = _flat(Color(0.46, 0.45, 0.43)); sill.position = Vector3(0, 0.18, 0)
	root.add_child(sill)
	# door slab, swung ajar
	var door := Node3D.new(); door.position = Vector3(-dw * 0.5, 0, hz); root.add_child(door)
	door.rotation.y = -0.7
	var slab := MeshInstance3D.new()
	var slb := BoxMesh.new(); slb.size = Vector3(dw, 2.0, 0.08)
	slab.mesh = slb; slab.material_override = _flat(Color(0.34, 0.23, 0.14)); slab.position = Vector3(dw * 0.5, 1.0, 0)
	door.add_child(slab)

func _torch(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; parent.add_child(root)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.07; pm.bottom_radius = 0.09; pm.height = 2.4
	pole.mesh = pm; pole.material_override = _flat(Color(0.32, 0.22, 0.14)); pole.position = Vector3(0, 1.2, 0)
	root.add_child(pole)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.18; fm.height = 0.4
	flame.mesh = fm
	var fmat := _flat(Color(1.0, 0.6, 0.2))
	fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.55, 0.15); fmat.emission_energy_multiplier = 2.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.mesh.material = fmat; flame.position = Vector3(0, 2.5, 0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = Vector3(0, 2.6, 0)
	light.shadow_enabled = false
	root.add_child(light)

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
	quest_idx = 0
	quest_active = false
	kills_base = 0
	pickups_collected = 0
	pickups_base = 0
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
		"armortier": return int(item["v"]) in player.owned_armors
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
		"helmet": player.helmet_owned = true; show_toast("Шлем куплен — наденьте в снаряжении (☰)")
		"armortier": player.own_armor(int(item["v"])); show_toast("Доспех куплен — наденьте в снаряжении (☰)")
	if item["kind"] in ["heal", "maxhp"]:
		show_toast("Куплено: " + item["name"])
	Sfx.buy()
	_refresh_shop_state()

func _process(delta: float) -> void:
	_update_daynight(delta)

	if controls and player:
		controls.hp_frac = clampf(player.hp / player.max_hp, 0.0, 1.0)
		controls.kills = kills
		controls.gold = player.gold
		if quest_active and quest_idx < quests.size():
			var q = quests[quest_idx]
			controls.quest_hud = "%s  %d/%d" % [q["title"], _quest_progress(), q["target"]]
		else:
			controls.quest_hud = ""

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
				if near_npc.kind == "quest":
					_open_quest()
				else:
					_open_shop()
			if controls.consume_inventory():
				_open_inventory()
		"inv":
			var si: int = controls.consume_slot()
			if si >= 0:
				_unequip_slot(si)
				_refresh_inv()
			var bi2: int = controls.consume_bag()
			if bi2 >= 0 and bi2 < _bag_items.size():
				_equip_bag(_bag_items[bi2])
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
		"quest":
			if controls.consume_quest():
				_quest_action()
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
	if near_npc != null:
		controls.interact_label = "ЗАДАНИЕ" if near_npc.kind == "quest" else "ТОРГОВЛЯ"

func _open_inventory() -> void:
	_refresh_inv()
	state = "inv"
	controls.state = 5

func _refresh_inv() -> void:
	# --- paper-doll equipment slots (0 weapon, 1 shield, 2 helmet, 3 armor) ---
	var slots := []
	# weapon
	var wname := "—"
	var wrare := false
	if player.equipped_weapon >= 0:
		wname = player.WEAPONS[player.equipped_weapon]["name"]
		wrare = player.WEAPONS[player.equipped_weapon].get("rare", false)
	else:
		wname = "Кулаки"
	slots.append({"label": "ОРУЖИЕ", "name": wname, "rare": wrare})
	# shield
	var sname := "—"
	if player.equipped_shield >= 1:
		sname = player.SHIELDS[player.equipped_shield]["name"]
	slots.append({"label": "ЩИТ", "name": sname, "rare": false})
	# helmet
	slots.append({"label": "ШЛЕМ", "name": "Шлем" if player.helmet_on else "—", "rare": false})
	# armor
	var aname := "—"
	if player.equipped_armor >= 1:
		aname = player.ARMOR_NAMES[player.equipped_armor]
	slots.append({"label": "ДОСПЕХ", "name": aname, "rare": false})
	controls.inv_slots = slots

	# --- bag: everything owned but not equipped ---
	var bag := []
	var items := []
	for wi in player.owned_weapons:
		if wi != player.equipped_weapon:
			bag.append({"name": player.WEAPONS[wi]["name"], "rare": player.WEAPONS[wi].get("rare", false), "tag": "Оружие"})
			items.append({"kind": "w", "v": wi})
	for si in player.owned_shields:
		if si >= 1 and si != player.equipped_shield:
			bag.append({"name": player.SHIELDS[si]["name"], "rare": false, "tag": "Щит"})
			items.append({"kind": "s", "v": si})
	if player.helmet_owned and not player.helmet_on:
		bag.append({"name": "Шлем", "rare": false, "tag": "Голова"})
		items.append({"kind": "helm", "v": 0})
	for ai in player.owned_armors:
		if ai != player.equipped_armor:
			bag.append({"name": player.ARMOR_NAMES[ai], "rare": false, "tag": "Доспех"})
			items.append({"kind": "armor", "v": ai})
	controls.inv_bag = bag
	_bag_items = items

	controls.inv_stats = "Урон: %d     Броня: %d%%     HP: %d/%d     Золото: %d" % [
		player.total_dmg(), int(player.armor * 100), int(player.hp), int(player.max_hp), player.gold]

func _unequip_slot(slot: int) -> void:
	match slot:
		0:
			if player.equipped_weapon >= 0:
				player.unequip_weapon()
		1:
			if player.equipped_shield >= 1:
				player.equip_shield(0)
		2:
			if player.helmet_on:
				player.toggle_helmet()
		3:
			if player.equipped_armor >= 1:
				player.unequip_armor()

func _equip_bag(it) -> void:
	match it["kind"]:
		"w": player.equip_weapon(int(it["v"]))
		"s": player.equip_shield(int(it["v"]))
		"helm":
			if not player.helmet_on:
				player.toggle_helmet()
		"armor": player.equip_armor(int(it["v"]))

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

func on_pickup() -> void:
	pickups_collected += 1

# ---------------- quests ----------------

func _quest_progress() -> int:
	if quest_idx >= quests.size():
		return 0
	var q = quests[quest_idx]
	match q["type"]:
		"kills": return kills - kills_base
		"pickups": return pickups_collected - pickups_base
		"gold": return player.gold
	return 0

func _quest_done() -> bool:
	if quest_idx >= quests.size():
		return false
	return _quest_progress() >= int(quests[quest_idx]["target"])

func _open_quest() -> void:
	_refresh_quest_dialog()
	state = "quest"
	controls.state = 6

func _quest_action() -> void:
	if quest_idx >= quests.size():
		state = "play"
		controls.state = 1
		return
	var q = quests[quest_idx]
	if not quest_active:
		quest_active = true
		if q["type"] == "kills":
			kills_base = kills
		elif q["type"] == "pickups":
			pickups_base = pickups_collected
		show_toast("Задание принято: " + q["title"])
		_refresh_quest_dialog()
	elif _quest_done():
		player.add_gold(int(q["reward"]))
		Sfx.quest()
		if q.has("weapon"):
			player.own_weapon(int(q["weapon"]))
			show_toast("Награда: +%d золота и %s! Наденьте в снаряжении (☰)" % [int(q["reward"]), q["weapon_name"]])
		else:
			show_toast("Награда получена: +%d золота" % int(q["reward"]))
		quest_idx += 1
		quest_active = false
		_refresh_quest_dialog()
	else:
		# still in progress — just close
		state = "play"
		controls.state = 1

func _refresh_quest_dialog() -> void:
	if quest_idx >= quests.size():
		controls.quest_title = "Благодарность"
		controls.quest_desc = "Все задания выполнены. Спасибо, витязь!"
		controls.quest_info = ""
		controls.quest_btn = "Закрыть"
		return
	var q = quests[quest_idx]
	controls.quest_title = q["title"]
	controls.quest_desc = q["desc"]
	if not quest_active:
		var rw := "Награда: %d золота" % int(q["reward"])
		if q.has("weapon_name"):
			rw += " + ✦ %s" % q["weapon_name"]
		controls.quest_info = rw
		controls.quest_btn = "Принять"
	elif _quest_done():
		controls.quest_info = "Выполнено!  %d/%d  (награда %d з.)" % [_quest_progress(), int(q["target"]), int(q["reward"])]
		controls.quest_btn = "Получить награду"
	else:
		controls.quest_info = "Прогресс: %d/%d" % [_quest_progress(), int(q["target"])]
		controls.quest_btn = "В пути (закрыть)"

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
