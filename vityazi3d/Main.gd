extends Node3D

const WORLD := 460.0
const CELLS := 150
const AMP := 7.0
const WATER_Y := -3.0
const CITY_FLAT := 50.0       # flat radius around a city
const VILLAGE_FLAT := 15.0    # flat radius around a village

var noise := FastNoiseLite.new()
var controls
var player

# four княжеских города
var cities := [
	{"name": "Великий Новгород", "pos": Vector3(0, 0, 0)},
	{"name": "Москва", "pos": Vector3(250, 0, 40)},
	{"name": "Владимир", "pos": Vector3(-150, 0, 220)},
	{"name": "Нижний Новгород", "pos": Vector3(150, 0, -260)},
]

# деревни на дорогах между городами
var village_centers := [
	# Новгород -> Москва
	Vector3(95, 0, 12), Vector3(175, 0, 28),
	# Новгород -> Владимир
	Vector3(-58, 0, 86), Vector3(-110, 0, 158),
	# Новгород -> Нижний
	Vector3(58, 0, -100), Vector3(108, 0, -185),
	# Москва -> Нижний
	Vector3(215, 0, -110), Vector3(190, 0, -185),
	# Москва -> Владимир
	Vector3(55, 0, 135), Vector3(-45, 0, 195),
	# Владимир -> Нижний (across)
	Vector3(0, 0, -20), Vector3(40, 0, 70),
]

var flat_zones := []          # [{"pos":Vector3,"r":float}] built in _ready

# Сарай-Бату — вражеская столица орды (открывается после всех заданий)
const SARAY_POS := Vector3(330, 0, 300)
const SARAY_FLAT := 56.0
var saray_unlocked := false
var saray_barrier: Node3D = null
var saray_near := false

# textured materials (procedural normal maps) + particle assets
var _nrm_wood: NoiseTexture2D
var _nrm_stone: NoiseTexture2D
var _nrm_soft: NoiseTexture2D
var _nrm_ground: NoiseTexture2D
var _fire_mat: StandardMaterial3D
var _smoke_mat: StandardMaterial3D
var _spark_mesh: QuadMesh
var _flame_mesh: QuadMesh
var _smoke_mesh: QuadMesh

var state := "menu"            # menu / play / shop / gameover / win
var kills := 0
var alive := 0
var boss_defeated := false
var near_npc = null
var current_region := ""
var mood_t := 0.0

# multiplayer (LAN co-op)
var net_mode := "single"        # single / host / client
var remote_players := {}        # peer_id -> RemotePlayer
var enemy_by_netid := {}        # net_id -> GameEnemy (host: real, client: proxy)
var _enemy_seq := 0
var _net_t := 0.0

# video quality (render scale etc.), persisted to user://settings.cfg
const SETTINGS_PATH := "user://settings.cfg"
var quality := "high"

# day/night
var sky_mat: ProceduralSkyMaterial
var env: Environment
var sun: DirectionalLight3D
var day_t := 0.16

var shop := []          # rebuilt each time the shop opens
var shop_sel := 0
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

	_build_flat_zones()
	_build_assets()
	_build_environment()
	_build_terrain()
	_build_floor()
	_build_water()
	_scatter_trees(420)
	_scatter_ground_detail()
	for c in cities:
		_build_city(c["pos"], c["name"])
	_build_villages()
	_build_roads()
	_build_saray_structures()
	_spawn_player()
	_setup_ui()
	_build_preview_studio()
	_setup_minimap()
	_load_settings()
	_apply_quality()
	state = "menu"
	controls.state = 0

	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest()

func _setup_minimap() -> void:
	controls.map_world = WORLD
	var cs := []
	for c in cities:
		cs.append({"pos": Vector2(c["pos"].x, c["pos"].z), "name": c["name"]})
	controls.map_cities = cs
	var vs := []
	for vc in village_centers:
		vs.append(Vector2(vc.x, vc.z))
	controls.map_villages = vs
	controls.map_saray = Vector2(SARAY_POS.x, SARAY_POS.z)

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		quality = str(cf.get_value("video", "quality", "high"))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", quality)
	cf.save(SETTINGS_PATH)

func _apply_quality() -> void:
	var vp := get_viewport()
	if quality == "low":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.7
		vp.msaa_3d = Viewport.MSAA_DISABLED
		if env: env.glow_enabled = false
		if sun: sun.shadow_enabled = false
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = Viewport.MSAA_2X
		if env: env.glow_enabled = true
		if sun: sun.shadow_enabled = true
	if controls:
		controls.quality_label = "Графика: " + ("Низкая" if quality == "low" else "Высокая")

func toggle_quality() -> void:
	quality = "high" if quality == "low" else "low"
	_apply_quality()
	_save_settings()

func _build_flat_zones() -> void:
	flat_zones.clear()
	for c in cities:
		flat_zones.append({"pos": c["pos"], "r": CITY_FLAT})
	for vc in village_centers:
		flat_zones.append({"pos": vc, "r": VILLAGE_FLAT})
	flat_zones.append({"pos": SARAY_POS, "r": SARAY_FLAT})

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
	# exercise procedural weapon build (Булава) via the equip path
	for i in range(player.WEAPONS.size()):
		if String(player.WEAPONS[i].get("model", "")).begins_with("proc:"):
			player.own_weapon(i); player.equip_weapon(i)
			break
	player.equip_weapon(0)
	# exercise shop: build, preview every item, buy boosters + a weapon
	player.gold = 99999
	_build_shop()
	for i in range(shop.size()):
		_select_shop(i)      # builds 3D preview (gltf + proc) and stats for each
	buy(shop[0]); buy(shop[0])   # strength x2
	buy(shop[1])                 # vitality
	for it in shop:
		if it["kind"] == "weapon":
			buy(it); break
	print("SELFTEST shop items=%d str=%d vit=%d dmg=%d maxhp=%d" % [shop.size(), player.str_level, player.vit_level, player.total_dmg(), int(player.max_hp)])
	# verify Сарай-Бату horde + gate unlock
	var khans := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.kind == GameEnemy.Kind.KHAN:
			khans += 1
	var barrier_before: bool = is_instance_valid(saray_barrier)
	quest_idx = quests.size()
	_update_saray()
	print("SELFTEST khan=%d barrier_before=%s unlocked=%s barrier_after=%s" % [
		khans, str(barrier_before), str(saray_unlocked), str(is_instance_valid(saray_barrier))])
	get_tree().quit(0 if get_tree().get_nodes_in_group("enemy").size() > 0 else 1)

func terrain_height(x: float, z: float) -> float:
	var t := 1.0
	for fz in flat_zones:
		var p: Vector3 = fz["pos"]
		var d := Vector2(x - p.x, z - p.z).length()
		var f := clampf((d - float(fz["r"])) / 36.0, 0.0, 1.0)
		t = minf(t, f * f)
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
	env.ambient_light_energy = 0.32
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.72, 0.76)
	env.fog_density = 0.0011
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	# restrained bloom — only genuinely bright sources (fire, glow) bloom, not the whole scene
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.7
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -120, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

func _update_daynight(delta: float) -> void:
	day_t += delta / 150.0
	var s := sin(day_t * TAU)
	var up := clampf((s + 1.0) * 0.5, 0.0, 1.0)
	sun.rotation_degrees = Vector3(lerp(-3.0, -85.0, up), -120.0, 0.0)
	sun.light_energy = lerp(0.05, 0.95, up)
	sun.light_color = Color(1.0, 0.7, 0.5).lerp(Color(1.0, 0.96, 0.88), up)
	sky_mat.sky_top_color = Color(0.05, 0.06, 0.12).lerp(Color(0.30, 0.47, 0.70), up)
	sky_mat.sky_horizon_color = Color(0.12, 0.11, 0.2).lerp(Color(0.74, 0.78, 0.80), up)
	env.ambient_light_energy = lerp(0.16, 0.4, up)
	env.fog_light_color = Color(0.10, 0.12, 0.22).lerp(Color(0.68, 0.72, 0.76), up)

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
	mat.roughness = 0.95
	mat.normal_enabled = true
	mat.normal_texture = _nrm_ground
	mat.normal_scale = 1.1
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
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
	# sand by the water
	if h < WATER_Y + 1.2:
		return Color(0.74, 0.68, 0.48).lerp(Color(0.66, 0.60, 0.42), _checker(p, 1.3))
	# city square — cobblestone paving with checkered mortar
	for c in cities:
		var cp: Vector3 = c["pos"]
		if Vector2(p.x - cp.x, p.z - cp.z).length() < 42.0:
			var stone := Color(0.50, 0.50, 0.53).lerp(Color(0.40, 0.40, 0.44), _checker(p, 1.1))
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
	_multimesh_scatter(_grass_blade_mesh(), 9000, 46.0, 430.0, 0.6, 1.5, true)
	_multimesh_scatter(_pebble_mesh(), 1800, 24.0, 440.0, 0.6, 1.6, false)
	_multimesh_scatter(_flower_mesh(), 900, 50.0, 425.0, 0.7, 1.3, true)

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
			# skip the dirt rings around villages and the paved cities
			var skip := false
			for vc in village_centers:
				if Vector2(x - vc.x, z - vc.z).length() < 14.0:
					skip = true
					break
			if not skip:
				for c in cities:
					if Vector2(x - c["pos"].x, z - c["pos"].z).length() < 42.0:
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

func _build_city(center: Vector3, cname: String) -> void:
	_church(center + Vector3(0, 0, -4))
	var ring := 37.0
	var seg := 20
	# gate faces toward the centre of the world (Новгород)
	var to_origin := Vector3.ZERO - center
	var gate := PI * 0.5
	if to_origin.length() > 1.0:
		gate = atan2(to_origin.z, to_origin.x)
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		if absf(_angdiff(a, gate)) < 0.33:
			continue
		var x := cos(a) * ring
		var z := sin(a) * ring
		_wall(center + Vector3(x, 0, z), atan2(x, z))
	for i in range(0, seg, 5):
		var a2 := TAU * float(i) / float(seg)
		_tower(center + Vector3(cos(a2) * ring, 0, sin(a2) * ring))
	for s in [Vector3(-18, 0, -10), Vector3(18, 0, -10), Vector3(-20, 0, 12), Vector3(20, 0, 12)]:
		_izba(center + s)
	_make_npc(center + Vector3(8, 0, 4))                 # merchant
	_make_npc(center + Vector3(-8, 0, 4), "quest")       # quest-giver
	# torches: by the gate, the church and the square
	var gp := Vector3(cos(gate) * ring, 0, sin(gate) * ring)
	_torch(self, center + gp + Vector3(2.5, 0, 0))
	_torch(self, center + gp + Vector3(-2.5, 0, 0))
	_torch(self, center + Vector3(-5, 0, 1))
	_torch(self, center + Vector3(5, 0, 1))
	_torch(self, center + Vector3(0, 0, 14))

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
	# lone landmarks scattered for exploration
	for lp in [Vector3(-260, 0, -120), Vector3(300, 0, 230), Vector3(-330, 0, 60), Vector3(40, 0, 340), Vector3(360, 0, -90)]:
		_tower(lp)
	_church(Vector3(-300, 0, -250))
	_church(Vector3(340, 0, 130))

# dirt roads connecting the cities (flat darker strips of pebbles)
func _build_roads() -> void:
	var links := [
		[Vector3(0, 0, 0), Vector3(250, 0, 40)],
		[Vector3(0, 0, 0), Vector3(-150, 0, 220)],
		[Vector3(0, 0, 0), Vector3(150, 0, -260)],
		[Vector3(250, 0, 40), Vector3(150, 0, -260)],
		[Vector3(250, 0, 40), Vector3(-150, 0, 220)],
	]
	for ln in links:
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var steps := int(a.distance_to(b) / 7.0)
		for i in range(steps + 1):
			var t := float(i) / float(maxi(steps, 1))
			var p := a.lerp(b, t)
			# skip inside city squares (already paved)
			var near_city := false
			for c in cities:
				if Vector2(p.x - c["pos"].x, p.z - c["pos"].z).length() < 40.0:
					near_city = true
					break
			if near_city:
				continue
			var slab := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(3.4, 0.12, 4.2)
			slab.mesh = bm
			slab.material_override = _flat(Color(0.40, 0.33, 0.24))
			slab.position = p + Vector3(0, 0.06, 0)
			slab.rotation.y = atan2(b.x - a.x, b.z - a.z)
			add_child(slab)

func _make_npc(pos: Vector3, kind := "merchant") -> void:
	var npc := GameNpc.new()
	npc.kind = kind
	add_child(npc)
	npc.global_position = pos

# ---------------- Сарай-Бату (orda capital) ----------------

func _build_saray_structures() -> void:
	var c := SARAY_POS
	# central khan's pavilion
	_khan_tent(c + Vector3(0, 0, -6))
	# ring of yurts
	var n := 9
	for i in range(n):
		var a := TAU * float(i) / float(n)
		_yurt(c + Vector3(cos(a) * 24.0, 0, sin(a) * 24.0), 1.0)
	for i in range(6):
		var a2 := randf() * TAU
		var d := randf_range(10.0, 20.0)
		_yurt(c + Vector3(cos(a2) * d, 0, sin(a2) * d), randf_range(0.7, 1.0))
	# horde banners around the camp
	for i in range(8):
		var ab := TAU * float(i) / 8.0
		_horde_banner(c + Vector3(cos(ab) * 34.0, 0, sin(ab) * 34.0))
	# spiked palisade ring (decor + solid)
	var seg := 28
	var gate := atan2((Vector3.ZERO - c).z, (Vector3.ZERO - c).x)
	for i in range(seg):
		var a3 := TAU * float(i) / float(seg)
		if absf(_angdiff(a3, gate)) < 0.28:
			continue
		var wp := c + Vector3(cos(a3) * 40.0, 0, sin(a3) * 40.0)
		_palisade(wp, atan2(cos(a3), sin(a3)))

func _yurt(pos: Vector3, sc: float) -> void:
	var root := Node3D.new(); root.position = pos; root.rotate_y(randf() * TAU); add_child(root)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.6 * sc; cm.bottom_radius = 1.7 * sc; cm.height = 1.8 * sc
	base.mesh = cm; base.material_override = _flat(Color(0.72, 0.68, 0.6)); base.position = Vector3(0, 0.9 * sc, 0)
	root.add_child(base)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.7 * sc; sm.height = 1.7 * sc
	dome.mesh = sm; dome.material_override = _flat(Color(0.66, 0.62, 0.54)); dome.position = Vector3(0, 1.8 * sc, 0)
	root.add_child(dome)
	# door flap
	var door := MeshInstance3D.new()
	var db := BoxMesh.new(); db.size = Vector3(0.7 * sc, 1.1 * sc, 0.08)
	door.mesh = db; door.material_override = _flat(Color(0.45, 0.2, 0.14)); door.position = Vector3(0, 0.6 * sc, 1.68 * sc)
	root.add_child(door)
	_solid(root, Vector3(3.2 * sc, 1.8 * sc, 3.2 * sc), Vector3(0, 0.9 * sc, 0))

func _khan_tent(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 3.4; cm.bottom_radius = 3.6; cm.height = 3.0
	base.mesh = cm; base.material_override = _flat(Color(0.5, 0.12, 0.10)); base.position = Vector3(0, 1.5, 0)
	root.add_child(base)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 3.5; sm.height = 3.6
	dome.mesh = sm; dome.material_override = _flat(Color(0.42, 0.10, 0.08)); dome.position = Vector3(0, 3.0, 0)
	root.add_child(dome)
	# golden finial
	var fin := MeshInstance3D.new()
	var fc := CylinderMesh.new(); fc.top_radius = 0.0; fc.bottom_radius = 0.5; fc.height = 1.4
	fin.mesh = fc
	var gm := _flat(Color(0.85, 0.69, 0.22)); gm.metallic = 0.7; gm.roughness = 0.25
	fin.material_override = gm; fin.position = Vector3(0, 5.4, 0)
	root.add_child(fin)
	_solid(root, Vector3(6.8, 3.0, 6.8), Vector3(0, 1.5, 0))

func _horde_banner(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.06; pm.bottom_radius = 0.08; pm.height = 4.2
	pole.mesh = pm; pole.material_override = _flat(Color(0.3, 0.22, 0.14)); pole.position = Vector3(0, 2.1, 0)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	var fb := BoxMesh.new(); fb.size = Vector3(0.06, 1.1, 1.5)
	flag.mesh = fb; flag.material_override = _flat(Color(0.7, 0.12, 0.10)); flag.position = Vector3(0, 3.6, 0.75)
	root.add_child(flag)

func _palisade(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation.y = yaw; add_child(root)
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(9.2, 4.0, 0.7)
	w.mesh = bm; w.material_override = _flat(Color(0.34, 0.26, 0.18)); w.position = Vector3(0, 2.0, 0)
	root.add_child(w)
	for k in [-3.0, 0.0, 3.0]:
		var spike := MeshInstance3D.new()
		var sc := CylinderMesh.new(); sc.top_radius = 0.0; sc.bottom_radius = 0.45; sc.height = 1.1
		spike.mesh = sc; spike.material_override = _flat(Color(0.30, 0.23, 0.16)); spike.position = Vector3(k, 4.4, 0)
		root.add_child(spike)
	_solid(root, Vector3(9.2, 4.0, 0.7), Vector3(0, 2.0, 0))

func _rebuild_saray_barrier() -> void:
	if is_instance_valid(saray_barrier):
		saray_barrier.queue_free()
	saray_barrier = Node3D.new()
	add_child(saray_barrier)
	var c := SARAY_POS
	var n := 18
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var wp := c + Vector3(cos(a) * 48.0, 0, sin(a) * 48.0)
		# translucent magical wall
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(18.0, 9.0, 0.6)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.1, 0.12, 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true; m.emission = Color(0.8, 0.15, 0.12); m.emission_energy_multiplier = 0.6
		mi.material_override = m
		mi.position = wp + Vector3(0, 4.5, 0)
		mi.rotation.y = atan2(cos(a), sin(a))
		saray_barrier.add_child(mi)
		# collision
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(18.0, 9.0, 0.6)
		cs.shape = bs
		sb.position = wp + Vector3(0, 4.5, 0)
		sb.rotation.y = atan2(cos(a), sin(a))
		sb.add_child(cs)
		saray_barrier.add_child(sb)

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
	w.mesh = bm; w.material_override = _stone(Color(0.52, 0.43, 0.33)); w.position = Vector3(0, 2.5, 0)
	root.add_child(w)
	for k in [-4.0, 0.0, 4.0]:
		var mer := MeshInstance3D.new()
		var mm := BoxMesh.new(); mm.size = Vector3(1.7, 1.2, 1.6)
		mer.mesh = mm; mer.material_override = _stone(Color(0.46, 0.38, 0.30)); mer.position = Vector3(k, 5.4, 0)
		root.add_child(mer)
	_solid(root, Vector3(12.0, 5.0, 1.3), Vector3(0, 2.5, 0))

# a wall slab that is both visible and solid; defaults to timbered wood
func _wall_seg(root: Node3D, size: Vector3, center: Vector3, col: Color, mat: StandardMaterial3D = null) -> void:
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	w.mesh = bm
	w.material_override = mat if mat != null else _wood(col)
	w.position = center
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
	var pmat := _plaster(wcol)
	# stone floor
	var fl := MeshInstance3D.new()
	var fb := BoxMesh.new(); fb.size = Vector3(hx * 2, 0.16, hz * 2)
	fl.mesh = fb; fl.material_override = _stone(Color(0.58, 0.56, 0.52)); fl.position = Vector3(0, 0.08, 0)
	root.add_child(fl)
	# walls with a tall doorway on +Z
	_wall_seg(root, Vector3(hx * 2 + t, hh, t), Vector3(0, hh * 0.5, -hz), wcol, pmat)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(-hx, hh * 0.5, 0), wcol, pmat)
	_wall_seg(root, Vector3(t, hh, hz * 2), Vector3(hx, hh * 0.5, 0), wcol, pmat)
	var dw := 1.9
	var seg := (hx * 2 - dw) * 0.5
	_wall_seg(root, Vector3(seg, hh, t), Vector3(-(dw * 0.5 + seg * 0.5), hh * 0.5, hz), wcol, pmat)
	_wall_seg(root, Vector3(seg, hh, t), Vector3(dw * 0.5 + seg * 0.5, hh * 0.5, hz), wcol, pmat)
	_wall_seg(root, Vector3(dw, hh - 3.2, t), Vector3(0, hh - (hh - 3.2) * 0.5, hz), wcol)
	# tall arched windows on the sides
	for zz in [-1.6, 1.6]:
		_window(root, Vector3(0.12, 2.4, 1.0), Vector3(-hx - 0.02, 3.6, zz))
		_window(root, Vector3(0.12, 2.4, 1.0), Vector3(hx + 0.02, 3.6, zz))
	# cornice + drum + golden dome + cross
	var cornice := MeshInstance3D.new()
	var cc := BoxMesh.new(); cc.size = Vector3(hx * 2 + 0.9, 0.55, hz * 2 + 0.9)
	cornice.mesh = cc; cornice.material_override = _stone(Color(0.79, 0.77, 0.71)); cornice.position = Vector3(0, hh, 0)
	root.add_child(cornice)
	var drum := MeshInstance3D.new()
	var dc := CylinderMesh.new(); dc.top_radius = 1.1; dc.bottom_radius = 1.1; dc.height = 1.8
	drum.mesh = dc; drum.material_override = _plaster(Color(0.81, 0.79, 0.73)); drum.position = Vector3(0, hh + 1.1, 0)
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
	body.mesh = bm; body.material_override = _stone(Color(0.55, 0.45, 0.34)); body.position = Vector3(0, 4.5, 0)
	root.add_child(body)
	# corner posts for a timbered look
	for sx in [-1.9, 1.9]:
		for sz in [-1.9, 1.9]:
			var post := MeshInstance3D.new()
			var pb := BoxMesh.new(); pb.size = Vector3(0.4, 9.2, 0.4)
			post.mesh = pb; post.material_override = _wood(Color(0.42, 0.33, 0.24)); post.position = Vector3(sx, 4.6, sz)
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
	ring.mesh = cm; ring.material_override = _stone(Color(0.5, 0.5, 0.52)); ring.position = Vector3(0, 0.6, 0)
	root.add_child(ring)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.18, 2.4, 0.18)
		post.mesh = pb; post.material_override = _wood(Color(0.4, 0.3, 0.2)); post.position = Vector3(sx, 1.8, 0)
		root.add_child(post)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(2.8, 0.9, 1.6)
	roof.mesh = pr; roof.material_override = _wood(Color(0.34, 0.26, 0.18)); roof.position = Vector3(0, 3.2, 0)
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
	fl.mesh = fb; fl.material_override = _wood(Color(0.36, 0.27, 0.18)); fl.position = Vector3(0, 0.05, 0)
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
	roof.mesh = pr; roof.material_override = _wood(Color(0.33, 0.25, 0.17)); roof.position = Vector3(0, hh + 1.0, 0)
	root.add_child(roof)
	# chimney with rising smoke
	var ch := MeshInstance3D.new()
	var cbx := BoxMesh.new(); cbx.size = Vector3(0.5, 1.5, 0.5)
	ch.mesh = cbx; ch.material_override = _stone(Color(0.42, 0.40, 0.40)); ch.position = Vector3(hx * 0.55, hh + 1.7, -hz * 0.4)
	root.add_child(ch)
	var smoke := _make_smoke()
	smoke.position = Vector3(hx * 0.55, hh + 2.6, -hz * 0.4)
	root.add_child(smoke)
	# log-cabin corner posts
	var logend := _wood(Color(0.40, 0.29, 0.18))
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
	pole.mesh = pm; pole.material_override = _wood(Color(0.32, 0.22, 0.14)); pole.position = Vector3(0, 1.2, 0)
	root.add_child(pole)
	# glowing ember core
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.14; fm.height = 0.3
	flame.mesh = fm
	var fmat := _flat(Color(1.0, 0.6, 0.2))
	fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.55, 0.15); fmat.emission_energy_multiplier = 2.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.mesh.material = fmat; flame.position = Vector3(0, 2.45, 0)
	root.add_child(flame)
	# animated fire particles
	var fire := _make_fire(1.0)
	fire.position = Vector3(0, 2.5, 0)
	root.add_child(fire)
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

# ---------------- procedural textures & particle assets ----------------

func _build_assets() -> void:
	_nrm_wood = _norm_tex(0.09, 2.2, 4)
	_nrm_stone = _norm_tex(0.05, 2.6, 3)
	_nrm_soft = _norm_tex(0.04, 1.0, 3)
	_nrm_ground = _norm_tex(0.12, 1.6, 4)
	# additive glow material for fire / sparks (vertex colour driven by particles)
	_fire_mat = StandardMaterial3D.new()
	_fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_mat.vertex_color_use_as_albedo = true
	_fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fire_mat.billboard_keep_scale = true
	_fire_mat.disable_receive_shadows = true
	# soft alpha material for smoke / dust
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.vertex_color_use_as_albedo = true
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_smoke_mat.billboard_keep_scale = true
	_smoke_mat.disable_receive_shadows = true
	_spark_mesh = QuadMesh.new(); _spark_mesh.size = Vector2(0.14, 0.14); _spark_mesh.material = _fire_mat
	_flame_mesh = QuadMesh.new(); _flame_mesh.size = Vector2(0.5, 0.5); _flame_mesh.material = _fire_mat
	_smoke_mesh = QuadMesh.new(); _smoke_mesh.size = Vector2(0.7, 0.7); _smoke_mesh.material = _smoke_mat

func _norm_tex(freq: float, bump: float, oct: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = oct
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = bump
	t.noise = n
	return t

func _tex_mat(c: Color, nrm: NoiseTexture2D, rough: float, tile: float, nscale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.normal_enabled = true
	m.normal_texture = nrm
	m.normal_scale = nscale
	m.uv1_scale = Vector3(tile, tile, tile)
	return m

func _wood(c: Color) -> StandardMaterial3D:
	return _tex_mat(c, _nrm_wood, 0.9, 2.5, 1.1)

func _stone(c: Color) -> StandardMaterial3D:
	return _tex_mat(c, _nrm_stone, 0.95, 3.0, 1.3)

func _plaster(c: Color) -> StandardMaterial3D:
	return _tex_mat(c, _nrm_soft, 0.85, 2.0, 0.6)

# continuous flame for torches/braziers
func _make_fire(scale: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.65
	p.mesh = _flame_mesh
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.4, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5 * scale
	p.scale_amount_max = 0.95 * scale
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.95))
	ramp.set_color(1, Color(0.9, 0.25, 0.08, 0.0))
	ramp.add_point(0.5, Color(1.0, 0.5, 0.12, 0.8))
	p.color_ramp = ramp
	return p

# rising smoke for chimneys
func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 2.4
	p.mesh = _smoke_mesh
	p.direction = Vector3.UP
	p.spread = 16.0
	p.gravity = Vector3(0.4, 1.1, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.5, 0.5, 0.0))
	ramp.set_color(1, Color(0.35, 0.35, 0.35, 0.0))
	ramp.add_point(0.25, Color(0.55, 0.55, 0.55, 0.45))
	p.color_ramp = ramp
	return p

# one-shot spark burst at a hit location, auto-frees
func spawn_hit_sparks(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.95
	p.amount = 14
	p.lifetime = 0.4
	p.mesh = _spark_mesh
	p.direction = Vector3.UP
	p.spread = 90.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.55, 1.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

# ---------------- weapon visuals & 3D item preview ----------------

func make_weapon_visual(w) -> Node3D:
	var mp := String(w.get("model", ""))
	var inst: Node3D
	if mp.begins_with("proc:"):
		inst = _build_proc_weapon(mp.substr(5), w.get("tint", Color(0.72, 0.74, 0.78)))
	elif mp != "":
		inst = load(mp).instantiate()
		if w.has("tint"):
			_tint_node(inst, w["tint"], w.get("rare", false))
	else:
		inst = Node3D.new()
	return inst

func _tint_node(node: Node, col: Color, glow: bool) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = 0.85 if glow else 0.55
		m.roughness = 0.25 if glow else 0.4
		if glow:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 0.5
		node.material_override = m
	for c in node.get_children():
		_tint_node(c, col, glow)

func _build_proc_weapon(kind: String, col: Color) -> Node3D:
	var root := Node3D.new()
	var steel := StandardMaterial3D.new(); steel.albedo_color = col; steel.metallic = 0.85; steel.roughness = 0.3
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.32, 0.22, 0.13); wood.roughness = 0.9
	match kind:
		"helmet":
			var dome := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.42
			dome.mesh = sm; dome.material_override = steel; dome.position = Vector3(0, 0.32, 0)
			root.add_child(dome)
			var tip := MeshInstance3D.new()
			var tc := CylinderMesh.new(); tc.top_radius = 0.0; tc.bottom_radius = 0.07; tc.height = 0.18
			tip.mesh = tc; tip.material_override = steel; tip.position = Vector3(0, 0.56, 0)
			root.add_child(tip)
			var rim := MeshInstance3D.new()
			var rc := CylinderMesh.new(); rc.top_radius = 0.34; rc.bottom_radius = 0.34; rc.height = 0.07
			rim.mesh = rc; rim.material_override = _flat(Color(0.4, 0.3, 0.18)); rim.position = Vector3(0, 0.2, 0)
			root.add_child(rim)
			var nasal := MeshInstance3D.new()
			var nb := BoxMesh.new(); nb.size = Vector3(0.07, 0.22, 0.05)
			nasal.mesh = nb; nasal.material_override = steel; nasal.position = Vector3(0, 0.18, 0.32)
			root.add_child(nasal)
		"mail", "plate":
			var plate := kind == "plate"
			var bcol := col if plate else Color(0.45, 0.46, 0.5)
			var bm := StandardMaterial3D.new(); bm.albedo_color = bcol; bm.metallic = 0.7; bm.roughness = 0.6 if not plate else 0.3
			var torso := MeshInstance3D.new()
			if plate:
				var tb := BoxMesh.new(); tb.size = Vector3(0.62, 0.7, 0.34)
				torso.mesh = tb
			else:
				var tc2 := CylinderMesh.new(); tc2.top_radius = 0.32; tc2.bottom_radius = 0.36; tc2.height = 0.74
				torso.mesh = tc2
			torso.material_override = bm; torso.position = Vector3(0, 0.4, 0)
			root.add_child(torso)
			for sxx in [-1.0, 1.0]:
				var sh := MeshInstance3D.new()
				var ss := SphereMesh.new(); ss.radius = 0.16; ss.height = 0.26
				sh.mesh = ss; sh.material_override = bm; sh.position = Vector3(sxx * 0.34, 0.72, 0)
				root.add_child(sh)
			var collar := MeshInstance3D.new()
			var cc2 := CylinderMesh.new(); cc2.top_radius = 0.16; cc2.bottom_radius = 0.2; cc2.height = 0.12
			collar.mesh = cc2; collar.material_override = bm; collar.position = Vector3(0, 0.8, 0)
			root.add_child(collar)
		_:
			# mace / morning-star
			var handle := MeshInstance3D.new()
			var hc := CylinderMesh.new(); hc.top_radius = 0.035; hc.bottom_radius = 0.045; hc.height = 0.62
			handle.mesh = hc; handle.material_override = wood; handle.position = Vector3(0, 0.31, 0)
			root.add_child(handle)
			var head := MeshInstance3D.new()
			var sm2 := SphereMesh.new(); sm2.radius = 0.11; sm2.height = 0.22
			head.mesh = sm2; head.material_override = steel; head.position = Vector3(0, 0.66, 0)
			root.add_child(head)
			for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, 1, 0)]:
				var stud := MeshInstance3D.new()
				var sb := BoxMesh.new(); sb.size = Vector3(0.075, 0.075, 0.075)
				stud.mesh = sb; stud.material_override = steel; stud.position = Vector3(0, 0.66, 0) + d * 0.12
				root.add_child(stud)
	return root

var preview_vp: SubViewport
var preview_holder: Node3D

func _build_preview_studio() -> void:
	# headless has no rendering scenario; skip (preview falls back to icons)
	if DisplayServer.get_name() == "headless":
		return
	preview_vp = SubViewport.new()
	preview_vp.size = Vector2i(340, 340)
	preview_vp.transparent_bg = true
	preview_vp.own_world_3d = true
	preview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview_vp)
	preview_vp.world_3d = World3D.new()
	var we := WorldEnvironment.new()
	var pe := Environment.new()
	pe.background_mode = Environment.BG_COLOR
	pe.background_color = Color(0.10, 0.11, 0.14, 0.0)
	pe.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	pe.ambient_light_color = Color(0.55, 0.56, 0.62)
	pe.ambient_light_energy = 1.0
	we.environment = pe
	preview_vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0.0, 0.5, 2.6)
	preview_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.45, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -45, 0)
	key.light_energy = 1.4
	preview_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 130, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.7, 0.8, 1.0)
	preview_vp.add_child(rim)
	preview_holder = Node3D.new()
	preview_vp.add_child(preview_holder)
	if controls:
		controls.preview_tex = preview_vp.get_texture()

func _clear_preview() -> void:
	if preview_holder:
		for c in preview_holder.get_children():
			c.queue_free()

func set_preview_weapon(w) -> void:
	_clear_preview()
	if preview_holder == null:
		return
	var inst := make_weapon_visual(w)
	inst.transform = Transform3D.IDENTITY
	preview_holder.add_child(inst)
	preview_holder.rotation = Vector3.ZERO
	# auto-frame: scale so the model's largest dimension fits, centre on the camera target
	var ab := _node_aabb(inst)
	if ab.size.length() > 0.0001:
		var maxd: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		var s := 1.2 / maxd
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(0, 0.45, 0) - ab.get_center() * s

func _node_aabb(root: Node) -> AABB:
	var has := false
	var out := AABB()
	var inv := (root as Node3D).global_transform.affine_inverse()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a := (inv * mi.global_transform) * mi.mesh.get_aabb()
		if not has:
			out = a; has = true
		else:
			out = out.merge(a)
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		var ra := (root as MeshInstance3D).mesh.get_aabb()
		out = ra if not has else out.merge(ra)
	return out

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
	current_region = ""
	saray_unlocked = false
	saray_near = false
	quest_idx = 0
	quest_active = false
	kills_base = 0
	pickups_collected = 0
	pickups_base = 0
	state = "play"
	controls.state = 1
	mood_t = 0.0
	Sfx.set_mood("calm")
	_rebuild_saray_barrier()
	# enemies: single-player or host are authoritative; clients receive them over the network
	if net_mode != "client":
		_spawn_world_enemies()
	_spawn_pickups()
	if Net.active:
		_net_t = 0.0

func _clear_actors() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for p in get_tree().get_nodes_in_group("proj"):
		p.queue_free()
	for pk in get_tree().get_nodes_in_group("pickup"):
		pk.queue_free()
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()
	enemy_by_netid.clear()
	_enemy_seq = 0
	alive = 0

# ---------------- networking (LAN co-op) ----------------

func _net_tick(delta: float) -> void:
	if not Net.active:
		return
	_net_t -= delta
	if _net_t > 0.0:
		return
	_net_t = 0.06
	var mv: Vector3 = player.velocity
	var moving := Vector2(mv.x, mv.z).length() > 0.6
	var yaw: float = player.model.rotation.y if player.model else 0.0
	rpc("_net_player_state", Net.my_id(), player.global_position.x, player.global_position.y,
		player.global_position.z, yaw, moving, clampf(player.hp / player.max_hp, 0.0, 1.0), player.char_id)
	if Net.is_host:
		var arr := []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.net_id < 0:
				continue
			var em: float = 1.0 if e.velocity.length() > 0.5 else 0.0
			arr.append([e.net_id, e.global_position.x, e.global_position.z,
				(e.model.rotation.y if e.model else 0.0), clampf(e.hp / e.max_hp, 0.0, 1.0), int(e.kind), em])
		rpc("_net_enemies", arr)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _net_player_state(id: int, px: float, py: float, pz: float, yaw: float, moving: bool, hpf: float, cid: int) -> void:
	if id == Net.my_id():
		return
	var rp = remote_players.get(id)
	if rp == null or not is_instance_valid(rp):
		rp = preload("res://RemotePlayer.gd").new()
		rp.peer_id = id
		rp.main = self
		add_child(rp)
		rp.setup(int(cid))
		rp.global_position = Vector3(px, py, pz)
		remote_players[id] = rp
		if Net.is_host:
			rp.add_to_group("player")    # host enemies will target remote players too
	rp.target_pos = Vector3(px, py, pz)
	rp.target_yaw = yaw
	rp.moving = moving
	rp.hp_frac = hpf

@rpc("authority", "unreliable", "call_remote")
func _net_enemies(arr: Array) -> void:
	if Net.is_host:
		return
	var seen := {}
	for entry in arr:
		var nid := int(entry[0])
		seen[nid] = true
		var e = enemy_by_netid.get(nid)
		if e == null or not is_instance_valid(e):
			e = GameEnemy.new()
			e.kind = int(entry[5])
			e.main = self
			e.net_proxy = true
			e.net_id = nid
			add_child(e)
			e.global_position = Vector3(entry[1], 0.0, entry[2])
			enemy_by_netid[nid] = e
		e.net_target = Vector3(entry[1], 0.0, entry[2])
		e.net_yaw = float(entry[3])
		e.net_hpfrac = float(entry[4])
		e.net_moving = float(entry[6]) > 0.5
	for nid in enemy_by_netid.keys():
		if not seen.has(nid):
			if is_instance_valid(enemy_by_netid[nid]):
				enemy_by_netid[nid].queue_free()
			enemy_by_netid.erase(nid)

func client_hit_enemy(net_id: int, d: float) -> void:
	if Net.active and not Net.is_host:
		rpc_id(1, "_net_request_hit", net_id, d)

@rpc("any_peer", "reliable", "call_remote")
func _net_request_hit(net_id: int, d: float) -> void:
	if not Net.is_host:
		return
	var e = enemy_by_netid.get(net_id)
	if is_instance_valid(e):
		e.take_damage(d)

func host_damage_remote(peer_id: int, d: float) -> void:
	if Net.is_host:
		rpc_id(peer_id, "_net_apply_damage", d)

@rpc("authority", "reliable", "call_remote")
func _net_apply_damage(d: float) -> void:
	if player:
		player.take_damage(d)

func _spawn_world_enemies() -> void:
	var camps := [
		Vector3(120, 0, 25), Vector3(60, 0, -130), Vector3(205, 0, -60),
		Vector3(-80, 0, 120), Vector3(-210, 0, 150), Vector3(90, 0, 185),
		Vector3(215, 0, 150), Vector3(-40, 0, -185), Vector3(30, 0, 260),
		Vector3(-265, 0, -40), Vector3(305, 0, -150), Vector3(160, 0, -340),
		Vector3(-130, 0, 295), Vector3(265, 0, 285),
	]
	for c in camps:
		_spawn_camp(c, false)
	_spawn_camp(Vector3(-300, 0, -250), true)   # воевода fortress (mid boss)
	_spawn_saray_horde()

func _spawn_saray_horde() -> void:
	var c := SARAY_POS
	# a large eastern army garrisoning the camp
	for i in range(10):
		var a := TAU * float(i) / 10.0
		_make_enemy(GameEnemy.Kind.MONGOL, c + Vector3(cos(a) * 20.0, 0, sin(a) * 20.0))
	for i in range(6):
		var a2 := TAU * float(i) / 6.0
		_make_enemy(GameEnemy.Kind.MONGOL_ARCHER, c + Vector3(cos(a2) * 28.0, 0, sin(a2) * 28.0))
	for i in range(4):
		var a3 := TAU * float(i) / 4.0
		_make_enemy(GameEnemy.Kind.MONGOL_HEAVY, c + Vector3(cos(a3) * 12.0, 0, sin(a3) * 12.0))
	# Мамай — super-boss in front of his pavilion
	_make_enemy(GameEnemy.Kind.KHAN, c + Vector3(0, 0, 4))

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
	e.net_id = _enemy_seq
	_enemy_seq += 1
	add_child(e)
	e.global_position = pos + Vector3(0, 3, 0)
	enemy_by_netid[e.net_id] = e
	alive += 1

func _gold_for(kind: int) -> int:
	match kind:
		GameEnemy.Kind.BRUTE: return 22
		GameEnemy.Kind.BOSS: return 200
		GameEnemy.Kind.ARCHER: return 10
		GameEnemy.Kind.SPEARMAN: return 10
		GameEnemy.Kind.MONGOL: return 24
		GameEnemy.Kind.MONGOL_ARCHER: return 26
		GameEnemy.Kind.MONGOL_HEAVY: return 45
		GameEnemy.Kind.KHAN: return 600
		_: return 8

func _spawn_pickups() -> void:
	for i in range(46):
		_make_pickup("gold", randf_range(12, 35), _rand_spot())
	for i in range(6):
		_make_pickup("weapon", randf_range(10, 24), _rand_spot())
	for i in range(5):
		_make_pickup("armor", randf_range(0.08, 0.14), _rand_spot())
	for i in range(5):
		_make_pickup("heal", 40.0, _rand_spot())

func _rand_spot() -> Vector3:
	for attempt in range(12):
		var a := randf() * TAU
		var d := randf_range(40.0, 380.0)
		var p := Vector3(cos(a) * d, 1.0, sin(a) * d)
		var ok := true
		for c in cities:
			if Vector2(p.x - c["pos"].x, p.z - c["pos"].z).length() < 38.0:
				ok = false
				break
		if ok:
			return p
	return Vector3(70, 1.0, 70)

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

func on_boss_killed() -> void:
	boss_defeated = true
	show_toast("Воевода повержен! Но главный враг — Мамай в Сарай-Бату.")

func on_khan_killed() -> void:
	# defeating Мамай is the true victory
	_win()

func show_toast(text: String) -> void:
	if controls:
		controls.toast = text
		controls.toast_t = 2.5

func _build_shop() -> void:
	shop = []
	shop.append({"kind": "booster_str"})
	shop.append({"kind": "booster_vit"})
	shop.append({"kind": "heal", "v": 40.0, "name": "Лечебное зелье", "price": 25})
	shop.append({"kind": "helmet", "v": 0, "name": "Шлем", "price": 50})
	shop.append({"kind": "armortier", "v": 1, "name": "Кольчуга", "price": 90})
	shop.append({"kind": "armortier", "v": 2, "name": "Латный доспех", "price": 200})
	shop.append({"kind": "shield", "v": 1, "name": player.SHIELDS[1]["name"], "price": int(player.SHIELDS[1]["price"])})
	shop.append({"kind": "shield", "v": 2, "name": player.SHIELDS[2]["name"], "price": int(player.SHIELDS[2]["price"])})
	# weapons (non-rare, with a price), sorted cheapest first
	var ws := []
	for i in range(player.WEAPONS.size()):
		var w = player.WEAPONS[i]
		if w.get("rare", false) or not w.has("price"):
			continue
		ws.append(i)
	ws.sort_custom(func(a, b): return int(player.WEAPONS[a]["price"]) < int(player.WEAPONS[b]["price"]))
	for i in ws:
		shop.append({"kind": "weapon", "v": i})

func _shop_name(item) -> String:
	match item["kind"]:
		"booster_str": return "Сила  (ур. %d/%d)" % [player.str_level, player.STR_MAX]
		"booster_vit": return "Здоровье  (ур. %d/%d)" % [player.vit_level, player.VIT_MAX]
		"weapon": return String(player.WEAPONS[int(item["v"])]["name"])
		_: return String(item["name"])

func _shop_price(item) -> int:
	match item["kind"]:
		"booster_str": return 80 + player.str_level * 45
		"booster_vit": return 70 + player.vit_level * 40
		"weapon": return int(player.WEAPONS[int(item["v"])]["price"])
		_: return int(item["price"])

func _shop_owned(item) -> bool:
	match item["kind"]:
		"weapon": return int(item["v"]) in player.owned_weapons
		"shield": return int(item["v"]) in player.owned_shields
		"helmet": return player.helmet_owned
		"armortier": return int(item["v"]) in player.owned_armors
		"booster_str": return not player.can_buy_strength()
		"booster_vit": return not player.can_buy_vitality()
		_: return false

func _shop_icon(item) -> String:
	# "" -> rendered as a 3D model; otherwise a flat vector icon
	match item["kind"]:
		"weapon", "shield", "helmet", "armortier": return ""
		"heal": return "heal"
		"booster_str": return "str"
		"booster_vit": return "vit"
		_: return "heal"

func _shop_stats(item) -> Array:
	var s := []
	match item["kind"]:
		"weapon":
			var w = player.WEAPONS[int(item["v"])]
			s.append("Класс:  " + String(w["cls"]))
			s.append("Урон:  %d" % int(w["dmg"]))
			s.append("Досягаемость:  %.1f м" % float(w["reach"]))
			s.append("Скорость:  %.1f уд/с" % (1.0 / float(w["cd"])))
			s.append("Хват:  " + ("двуручный" if w.get("two", false) else "одноручный"))
			if w.get("ranged", false):
				s.append("• дальний бой")
			if w.has("tint") and not w.get("rare", false):
				s.append("• улучшенная ковка")
		"shield":
			s.append("Тип:  щит")
			s.append("Броня:  +%d%%" % int(float(player.SHIELDS[int(item["v"])]["armor"]) * 100))
			s.append("(нельзя с двуручным)")
		"helmet":
			s.append("Тип:  шлем")
			s.append("Броня:  +6%")
		"armortier":
			s.append("Тип:  доспех")
			s.append("Броня:  +%d%%" % int(player.ARMOR_TIERS[int(item["v"])] * 100))
		"heal":
			s.append("Мгновенно лечит 40 HP")
		"booster_str":
			s.append("+%d к урону за уровень" % int(player.STR_STEP))
			s.append("Текущий бонус:  +%d" % int(player.str_level * player.STR_STEP))
		"booster_vit":
			s.append("+%d к макс. HP за уровень" % int(player.VIT_STEP))
			s.append("Текущий бонус:  +%d HP" % int(player.vit_level * player.VIT_STEP))
	return s

func buy(item) -> void:
	if _shop_owned(item):
		show_toast("Уже куплено")
		return
	var price := _shop_price(item)
	if player.gold < price:
		show_toast("Не хватает золота")
		return
	player.gold -= price
	match item["kind"]:
		"heal": player.heal(40.0); show_toast("Зелье выпито: +40 HP")
		"booster_str": player.buy_strength(); show_toast("Сила повышена! Урон +%d" % int(player.STR_STEP))
		"booster_vit": player.buy_vitality(); show_toast("Здоровье повышено! Макс. HP +%d" % int(player.VIT_STEP))
		"weapon": player.own_weapon(int(item["v"])); show_toast("Куплено! Наденьте в снаряжении (☰)")
		"shield": player.own_shield(int(item["v"])); show_toast("Куплено! Наденьте в снаряжении (☰)")
		"helmet": player.helmet_owned = true; show_toast("Шлем куплен — наденьте в снаряжении (☰)")
		"armortier": player.own_armor(int(item["v"])); show_toast("Доспех куплен — наденьте в снаряжении (☰)")
	Sfx.buy()
	_refresh_shop_state()
	_select_shop(shop_sel)

func _process(delta: float) -> void:
	_update_daynight(delta)
	if preview_holder and (state == "shop" or state == "inv"):
		preview_holder.rotate_y(delta * 0.9)

	if controls and player:
		controls.hp_frac = clampf(player.hp / player.max_hp, 0.0, 1.0)
		controls.kills = kills
		controls.gold = player.gold
		controls.player_pos = Vector2(player.global_position.x, player.global_position.z)
		if player.model:
			controls.player_yaw = player.model.rotation.y
		if quest_active and quest_idx < quests.size():
			var q = quests[quest_idx]
			controls.quest_hud = "%s  %d/%d" % [q["title"], _quest_progress(), q["target"]]
		else:
			controls.quest_hud = ""

	match state:
		"menu":
			if controls.consume_quality():
				toggle_quality()
			var nm: int = controls.consume_net()
			if nm == 0:
				net_mode = "single"; Net.leave()
			elif nm == 1:
				net_mode = "host"; Net.host()
			elif nm == 2:
				net_mode = "client"; Net.discover()
			var jip: String = controls.consume_join_ip()
			if jip != "":
				net_mode = "client"
				Net.join(jip)
			controls.net_mode = net_mode
			controls.net_status = Net.status
			var c: int = controls.consume_chosen()
			if c >= 0:
				if net_mode == "client" and not Net.connected:
					show_toast("Сначала подключитесь к игре по Wi-Fi")
				else:
					start_game(c)
		"play":
			_update_interaction()
			_update_region()
			_update_saray()
			_update_mood(delta)
			_net_tick(delta)
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
				_clear_preview()
		"shop":
			var sel: int = controls.consume_shop_select()
			if sel >= 0 and sel < shop.size():
				_select_shop(sel)
			if controls.consume_shop_buy():
				buy(shop[shop_sel])
			if controls.consume_close():
				state = "play"
				controls.state = 1
				_clear_preview()
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

func _update_region() -> void:
	var rname := ""
	for c in cities:
		if player.global_position.distance_to(c["pos"]) < 46.0:
			rname = c["name"]
			break
	if rname == "" and player.global_position.distance_to(SARAY_POS) < 52.0:
		rname = "Сарай-Бату"
	if rname != current_region:
		current_region = rname
		if rname != "" and rname != "Сарай-Бату":
			show_toast("Вы прибыли в город: " + rname)
	controls.region = current_region

func surface_at(pos: Vector3) -> String:
	for c in cities:
		if Vector2(pos.x - c["pos"].x, pos.z - c["pos"].z).length() < 42.0:
			return "stone"
	for vc in village_centers:
		if Vector2(pos.x - vc.x, pos.z - vc.z).length() < 14.0:
			return "dirt"
	if Vector2(pos.x - SARAY_POS.x, pos.z - SARAY_POS.z).length() < 45.0:
		return "dirt"
	return "grass"

func _update_mood(delta: float) -> void:
	mood_t -= delta
	if mood_t > 0.0:
		return
	mood_t = 0.3
	var mood := "calm"
	if player.global_position.distance_to(SARAY_POS) < 115.0:
		mood = "horde"
	else:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.global_position.distance_to(player.global_position) < 26.0:
				mood = "combat"
				break
	Sfx.set_mood(mood)

func _update_saray() -> void:
	if saray_unlocked:
		return
	# unlock once every villager quest is complete (grants the super-weapons)
	if quest_idx >= quests.size():
		saray_unlocked = true
		if is_instance_valid(saray_barrier):
			saray_barrier.queue_free()
		show_toast("Врата Сарай-Бату пали! Иди и сокруши Мамая!")
		return
	var near: bool = player.global_position.distance_to(SARAY_POS) < 95.0
	if near and not saray_near:
		show_toast("Сарай-Бату под защитой. Сначала выполни все задания витязей.")
	saray_near = near

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
			bag.append({"name": player.WEAPONS[wi]["name"], "rare": player.WEAPONS[wi].get("rare", false), "tag": String(player.WEAPONS[wi].get("cls", "Оружие"))})
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

	# equipped-weapon 3D preview + its stat lines
	if player.equipped_weapon >= 0:
		var w = player.WEAPONS[player.equipped_weapon]
		set_preview_weapon(w)
		controls.inv_is3d = true
		var ws := ["Урон:  %d" % int(w["dmg"]), "Скорость:  %.1f уд/с" % (1.0 / float(w["cd"])), "Досягаемость:  %.1f м" % float(w["reach"])]
		if w.get("ranged", false):
			ws.append("• дальний бой")
		controls.inv_weapon_name = String(w["name"])
		controls.inv_weapon_stats = ws
	else:
		_clear_preview()
		controls.inv_is3d = false
		controls.inv_weapon_name = "Кулаки"
		controls.inv_weapon_stats = ["Урон:  %d" % int(player.atk_dmg)]
	# stat-upgrade levels for display
	controls.inv_upgrades = "Сила ур.%d   •   Здоровье ур.%d" % [player.str_level, player.vit_level]

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
	_build_shop()
	shop_sel = 0
	controls.shop_scroll = 0
	_refresh_shop_state()
	_select_shop(0)
	state = "shop"
	controls.state = 4

func _refresh_shop_state() -> void:
	var rows := []
	for it in shop:
		var st := "buy"
		if _shop_owned(it):
			st = "owned"
		elif player.gold < _shop_price(it):
			st = "poor"
		rows.append({"name": _shop_name(it), "price": _shop_price(it), "state": st})
	controls.shop_rows = rows

func _select_shop(i: int) -> void:
	if i < 0 or i >= shop.size():
		return
	shop_sel = i
	var item = shop[i]
	controls.shop_sel = i
	var icon := _shop_icon(item)
	if icon == "":
		controls.shop_is3d = true
		match item["kind"]:
			"weapon": set_preview_weapon(player.WEAPONS[int(item["v"])])
			"shield": set_preview_weapon({"model": player.SHIELDS[int(item["v"])]["model"]})
			"helmet": set_preview_weapon({"model": "proc:helmet", "tint": Color(0.62, 0.64, 0.72)})
			"armortier": set_preview_weapon({"model": ("proc:mail" if int(item["v"]) == 1 else "proc:plate"), "tint": Color(0.6, 0.62, 0.68)})
	else:
		controls.shop_is3d = false
		controls.shop_icon = icon
		_clear_preview()
	controls.shop_sel_name = _shop_name(item)
	controls.shop_sel_price = _shop_price(item)
	controls.shop_stats = _shop_stats(item)
	controls.shop_rare = item["kind"] == "weapon" and player.WEAPONS[int(item["v"])].has("tint")
	if _shop_owned(item):
		controls.shop_buy_text = "Максимум" if item["kind"].begins_with("booster") else "Уже куплено"
		controls.shop_buy_state = "owned"
	elif player.gold < _shop_price(item):
		controls.shop_buy_text = "Не хватает золота"
		controls.shop_buy_state = "poor"
	else:
		controls.shop_buy_text = "Купить за %d з." % _shop_price(item)
		controls.shop_buy_state = "ok"

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
