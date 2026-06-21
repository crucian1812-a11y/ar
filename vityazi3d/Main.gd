extends Node3D

# ---- world parameters ----
const WORLD := 170.0          # half-extent of the terrain (meters)
const CELLS := 70             # grid resolution
const AMP := 7.0              # hill height
const WATER_Y := -3.0
const PLAZA := 42.0           # radius of the flat central plaza

var noise := FastNoiseLite.new()
var controls
var player
var kills := 0
var wave := 0
var spawn_timer := 0.0
var alive := 0

func _ready() -> void:
	randomize()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	noise.seed = randi()

	_build_environment()
	_build_terrain()
	_build_water()
	_scatter_trees(150)
	_build_town()
	_spawn_player()
	_setup_ui()

	# first wave
	_spawn_wave()

func terrain_height(x: float, z: float) -> float:
	# Perfectly flat plaza in the centre, smoothly blending into gentle hills.
	var d := Vector2(x, z).length()
	var t := clampf((d - PLAZA) / 45.0, 0.0, 1.0)
	t = t * t
	return noise.get_noise_2d(x, z) * AMP * t

# ---------------- environment ----------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.74)
	sm.sky_horizon_color = Color(0.78, 0.82, 0.83)
	sm.ground_horizon_color = Color(0.65, 0.66, 0.62)
	sm.ground_bottom_color = Color(0.36, 0.4, 0.36)
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.85)
	env.fog_density = 0.0045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -120, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

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
	var mesh := stool.commit()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Terrain"
	add_child(mi)
	mi.create_trimesh_collision()

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var slope := 1.0
	if n.length() > 0.0:
		slope = clampf(n.normalized().dot(Vector3.UP), 0.0, 1.0)
	for v in [a, b, c]:
		st.set_color(_ground_color(v.y, slope))
		st.add_vertex(v)

func _ground_color(h: float, slope: float) -> Color:
	var grass := Color(0.36, 0.49, 0.28)
	var grass2 := Color(0.30, 0.43, 0.24)
	var rock := Color(0.42, 0.40, 0.37)
	var sand := Color(0.72, 0.66, 0.45)
	if h < WATER_Y + 1.2:
		return sand
	if slope < 0.78:
		return rock
	return grass.lerp(grass2, fmod(absf(h) * 0.7, 1.0))

func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD * 2.4, WORLD * 2.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.42, 0.55, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic = 0.2
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
		if Vector2(x, z).length() < 22.0:
			continue   # keep the clearing open
		_make_tree(Vector3(x, h, z))

func _make_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	var scale := randf_range(0.8, 1.5)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18 * scale
	tm.bottom_radius = 0.26 * scale
	tm.height = 2.2 * scale
	trunk.mesh = tm
	trunk.material_override = _flat(Color(0.36, 0.26, 0.17))
	trunk.position = Vector3(0, 1.1 * scale, 0)
	root.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var cm := CylinderMesh.new()      # cone (top radius 0)
	cm.top_radius = 0.0
	cm.bottom_radius = 1.5 * scale
	cm.height = 3.0 * scale
	leaves.mesh = cm
	var green := Color(0.20, 0.42, 0.22).lerp(Color(0.28, 0.5, 0.26), randf())
	leaves.material_override = _flat(green)
	leaves.position = Vector3(0, 3.4 * scale, 0)
	root.add_child(leaves)

	root.rotate_y(randf() * TAU)
	add_child(root)

func _build_town() -> void:
	# Saint-Sophia-like church with golden onion dome at the clearing centre
	_church(Vector3(0, terrain_height(0, -6), -6))
	# kremlin towers around it
	_tower(Vector3(-16, terrain_height(-16, 4), 4))
	_tower(Vector3(16, terrain_height(16, 4), 4))
	_tower(Vector3(0, terrain_height(0, 16), 16))
	# a couple of izbas (wooden houses)
	_izba(Vector3(-10, terrain_height(-10, -16), -16))
	_izba(Vector3(11, terrain_height(11, -15), -15))

func _church(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(7, 7, 7)
	body.mesh = bm; body.material_override = _flat(Color(0.86, 0.84, 0.78))
	body.position = Vector3(0, 3.5, 0); root.add_child(body)
	# drum + golden onion dome
	var drum := MeshInstance3D.new()
	var dc := CylinderMesh.new(); dc.top_radius = 1.1; dc.bottom_radius = 1.1; dc.height = 1.6
	drum.mesh = dc; drum.material_override = _flat(Color(0.8, 0.78, 0.72))
	drum.position = Vector3(0, 7.8, 0); root.add_child(drum)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.5; sm.height = 2.6
	dome.mesh = sm; dome.material_override = _flat(Color(0.85, 0.69, 0.22))
	dome.material_override.metallic = 0.6; dome.material_override.roughness = 0.3
	dome.position = Vector3(0, 9.4, 0); root.add_child(dome)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(0.1, 1.2, 0.1)
	cross.mesh = cb; cross.material_override = _flat(Color(0.9, 0.78, 0.3))
	cross.position = Vector3(0, 11.2, 0); root.add_child(cross)

func _tower(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4, 9, 4)
	body.mesh = bm; body.material_override = _flat(Color(0.55, 0.45, 0.34))
	body.position = Vector3(0, 4.5, 0); root.add_child(body)
	var roof := MeshInstance3D.new()
	var rc := CylinderMesh.new(); rc.top_radius = 0.0; rc.bottom_radius = 3.2; rc.height = 3.5
	roof.mesh = rc; roof.material_override = _flat(Color(0.38, 0.3, 0.24))
	roof.position = Vector3(0, 10.6, 0); root.add_child(roof)

func _izba(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4, 3, 5)
	body.mesh = bm; body.material_override = _flat(Color(0.46, 0.34, 0.22))
	body.position = Vector3(0, 1.5, 0); root.add_child(body)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(4.6, 2.0, 5.4)
	roof.mesh = pr; roof.material_override = _flat(Color(0.34, 0.26, 0.18))
	roof.position = Vector3(0, 4.0, 0); root.add_child(roof)
	root.rotate_y(randf() * TAU)

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

# ---------------- actors ----------------

func _spawn_player() -> void:
	player = preload("res://Player.gd").new()
	player.main = self
	add_child(player)
	player.global_position = Vector3(0, terrain_height(0, 8) + 2.0, 8)

func _spawn_wave() -> void:
	wave += 1
	var n := 3 + wave
	for i in range(n):
		var ang := randf() * TAU
		var dist := randf_range(28.0, 48.0)
		var x := cos(ang) * dist
		var z := sin(ang) * dist
		var e = preload("res://Enemy.gd").new()
		e.main = self
		add_child(e)
		e.global_position = Vector3(x, terrain_height(x, z) + 1.5, z)
		alive += 1

func on_enemy_killed() -> void:
	kills += 1
	alive -= 1
	if alive <= 0:
		spawn_timer = 3.0   # short breather before next wave

func _process(delta: float) -> void:
	if alive <= 0 and spawn_timer > 0.0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_wave()
	if controls and player:
		controls.hp_frac = clampf(player.hp / player.max_hp, 0.0, 1.0)
		controls.kills = kills
		controls.wave = wave
		controls.alive = alive
		controls.dbg_speed = Vector2(player.velocity.x, player.velocity.z).length()
		controls.dbg_floor = player.is_on_floor()

# ---------------- ui ----------------

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	controls = preload("res://TouchControls.gd").new()
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(controls)
	player.controls = controls
