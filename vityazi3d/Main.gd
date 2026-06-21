extends Node3D

const WORLD := 170.0
const CELLS := 70
const AMP := 7.0
const WATER_Y := -3.0
const PLAZA := 42.0
const WAVES_BEFORE_BOSS := 4

var noise := FastNoiseLite.new()
var controls
var player

var state := "menu"            # menu / play / gameover / win
var kills := 0
var wave := 0
var alive := 0
var spawn_timer := 0.0
var boss_spawned := false
var boss_defeated := false

# day/night
var sky_mat: ProceduralSkyMaterial
var env: Environment
var sun: DirectionalLight3D
var day_t := 0.18

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
	_scatter_trees(150)
	_build_town()
	_spawn_player()
	_setup_ui()
	state = "menu"
	controls.state = 0

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
	env.fog_density = 0.004
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -120, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

func _update_daynight(delta: float) -> void:
	day_t += delta / 120.0
	var s := sin(day_t * TAU)
	var up := clampf((s + 1.0) * 0.5, 0.0, 1.0)
	sun.rotation_degrees = Vector3(lerp(-3.0, -88.0, up), -120.0, 0.0)
	sun.light_energy = lerp(0.05, 1.25, up)
	sun.light_color = Color(1.0, 0.7, 0.5).lerp(Color(1.0, 0.96, 0.88), up)
	sky_mat.sky_top_color = Color(0.05, 0.06, 0.12).lerp(Color(0.32, 0.5, 0.74), up)
	sky_mat.sky_horizon_color = Color(0.12, 0.11, 0.2).lerp(Color(0.80, 0.82, 0.83), up)
	env.ambient_light_energy = lerp(0.18, 0.6, up)
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
		var h := terrain_height(x, z)
		if h < WATER_Y + 1.5:
			continue
		if Vector2(x, z).length() < 24.0:
			continue
		_make_tree(Vector3(x, h, z))

func _make_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	var sc := randf_range(0.8, 1.5)
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
	_tower(Vector3(cos(gate - 0.33) * ring, 0, sin(gate - 0.33) * ring))
	_tower(Vector3(cos(gate + 0.33) * ring, 0, sin(gate + 0.33) * ring))
	for s in [Vector3(-22, 0, -8), Vector3(-26, 0, 3), Vector3(-20, 0, 12),
			Vector3(22, 0, -10), Vector3(26, 0, 1), Vector3(20, 0, 13)]:
		_izba(s)

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
	player.global_position = Vector3(0, 2.0, 8)

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
	player.global_position = Vector3(0, 2.0, 8)
	player.velocity = Vector3.ZERO
	wave = 0; kills = 0; alive = 0
	boss_spawned = false; boss_defeated = false
	spawn_timer = 0.0
	state = "play"
	controls.state = 1
	_spawn_wave()

func _clear_actors() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for p in get_tree().get_nodes_in_group("proj"):
		p.queue_free()
	alive = 0

func _spawn_wave() -> void:
	wave += 1
	var count: int = min(5 + wave * 2, 24)
	for i in range(count):
		var r := randf()
		var k: int
		if wave >= 3 and r < 0.12:
			k = GameEnemy.Kind.BRUTE
		elif r < 0.30:
			k = GameEnemy.Kind.ARCHER
		elif r < 0.58:
			k = GameEnemy.Kind.SPEARMAN
		else:
			k = GameEnemy.Kind.RAIDER
		_make_enemy(k, randf_range(16.0, 30.0))

func _spawn_boss() -> void:
	boss_spawned = true
	_make_enemy(GameEnemy.Kind.BOSS, 18.0)
	for i in range(4):
		_make_enemy(GameEnemy.Kind.RAIDER, randf_range(14.0, 24.0))

func _make_enemy(kind: int, dist: float) -> void:
	var e := GameEnemy.new()
	e.kind = kind
	e.main = self
	add_child(e)
	var ang := randf() * TAU
	e.global_position = Vector3(cos(ang) * dist, 3.0, sin(ang) * dist)
	alive += 1

func on_enemy_killed() -> void:
	kills += 1
	alive -= 1
	if alive <= 0:
		spawn_timer = 2.5

func on_boss_killed() -> void:
	boss_defeated = true

func _process(delta: float) -> void:
	_update_daynight(delta)

	if controls and player:
		controls.hp_frac = clampf(player.hp / player.max_hp, 0.0, 1.0)
		controls.kills = kills
		controls.wave = wave
		controls.alive = alive
		controls.boss_present = boss_spawned and not boss_defeated
		controls.dbg_ecount = get_tree().get_nodes_in_group("enemy").size()
		var fe = get_tree().get_first_node_in_group("enemy")
		controls.dbg_e0 = str(fe.global_position.round()) if fe else "none"

	match state:
		"menu":
			var c: int = controls.consume_chosen()
			if c >= 0:
				start_game(c)
		"play":
			if player.hp <= 0.0:
				_game_over()
				return
			if alive <= 0 and spawn_timer > 0.0:
				spawn_timer -= delta
				if spawn_timer <= 0.0:
					if boss_defeated:
						_win()
					elif wave >= WAVES_BEFORE_BOSS and not boss_spawned:
						_spawn_boss()
					else:
						_spawn_wave()
		"gameover", "win":
			if controls.consume_restart():
				_to_menu()

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
