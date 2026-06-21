extends CharacterBody3D
class_name GameEnemy

enum Kind { RAIDER, SPEARMAN, ARCHER, BRUTE, BOSS }

var kind: int = Kind.RAIDER
var main

var hp := 60.0
var max_hp := 60.0
var speed := 3.6
var dmg := 8.0
var reach := 2.0
var atk_cd_time := 1.3
var ranged := false
var scl := 1.0

const GRAVITY := 22.0
var attack_cd := 0.0
var hurt_t := 0.0
var body: Node3D
var mats: Array[StandardMaterial3D] = []
var hp_bg: MeshInstance3D
var hp_fg: MeshInstance3D

var _cloth := Color(0.30, 0.36, 0.24)
var _dark := Color(0.22, 0.18, 0.14)
var _skin := Color(0.78, 0.62, 0.46)

func _ready() -> void:
	add_to_group("enemy")
	up_direction = Vector3.UP
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(60.0)
	_apply_kind()
	max_hp = hp
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * scl
	cap.height = 1.8 * scl
	col.shape = cap
	col.position = Vector3(0, 0.9 * scl, 0)
	add_child(col)
	body = Node3D.new()
	add_child(body)
	_build_body()
	_build_hpbar()

func _apply_kind() -> void:
	match kind:
		Kind.RAIDER:
			hp = 55; speed = 3.9; dmg = 8; reach = 2.0; atk_cd_time = 1.2
			_cloth = Color(0.32, 0.40, 0.24); _dark = Color(0.20, 0.16, 0.12)
		Kind.SPEARMAN:
			hp = 65; speed = 4.5; dmg = 11; reach = 2.9; atk_cd_time = 1.1; scl = 1.05
			_cloth = Color(0.30, 0.36, 0.46); _dark = Color(0.18, 0.22, 0.30)
		Kind.ARCHER:
			hp = 40; speed = 3.2; dmg = 7; reach = 16.0; atk_cd_time = 2.1; ranged = true
			_cloth = Color(0.52, 0.40, 0.24); _dark = Color(0.30, 0.22, 0.14)
		Kind.BRUTE:
			hp = 165; speed = 2.7; dmg = 20; reach = 2.7; atk_cd_time = 1.7; scl = 1.6
			_cloth = Color(0.42, 0.20, 0.18); _dark = Color(0.24, 0.12, 0.10)
		Kind.BOSS:
			hp = 650; speed = 3.0; dmg = 28; reach = 3.1; atk_cd_time = 1.4; scl = 2.3
			_cloth = Color(0.46, 0.16, 0.20); _dark = Color(0.24, 0.10, 0.12)

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if hurt_t > 0.0:
		hurt_t -= delta
		if hurt_t <= 0.0:
			_set_tint(false)

	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var to: Vector3 = player.global_position - global_position
		to.y = 0
		var dist := to.length()
		var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 0.15)

		if ranged:
			if dist > reach + 2.0:
				velocity.x = dir.x * speed; velocity.z = dir.z * speed
			elif dist < reach - 6.0:
				velocity.x = -dir.x * speed; velocity.z = -dir.z * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
			if dist <= reach and attack_cd <= 0.0:
				attack_cd = atk_cd_time
				_shoot(player)
		else:
			if dist > reach:
				velocity.x = dir.x * speed; velocity.z = dir.z * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
				if attack_cd <= 0.0:
					attack_cd = atk_cd_time
					player.take_damage(dmg)
					if (kind == Kind.BRUTE or kind == Kind.BOSS) and player.has_method("knockback"):
						player.knockback((player.global_position - global_position).normalized(), 7.0)
	move_and_slide()
	_update_hpbar()

func _shoot(player) -> void:
	var pr := GameProjectile.new()
	pr.dmg = dmg
	get_parent().add_child(pr)
	pr.global_position = global_position + Vector3.UP * (1.4 * scl)
	var target: Vector3 = player.global_position + Vector3.UP * 1.0
	pr.vel = (target - pr.global_position).normalized() * 18.0

func take_damage(d: float) -> void:
	hp -= d
	hurt_t = 0.15
	_set_tint(true)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var away := (global_position - player.global_position).normalized()
		velocity += away * (2.0 if kind == Kind.BOSS else 4.0)
	if hp <= 0.0:
		Sfx.enemy_die()
		if main:
			if kind == Kind.BOSS and main.has_method("on_boss_killed"):
				main.on_boss_killed()
			main.on_enemy_killed()
		queue_free()

func _set_tint(on: bool) -> void:
	for m in mats:
		m.emission_enabled = on
		m.emission = Color(0.7, 0.1, 0.1)
		m.emission_energy_multiplier = 1.5

# ---------------- hp bar ----------------

func _build_hpbar() -> void:
	hp_bg = _quad(Color(0, 0, 0, 0.6), 1.15 * scl, 0.18 * scl, 0)
	hp_fg = _quad(Color(0.85, 0.22, 0.18, 1.0), 1.05 * scl, 0.12 * scl, 1)
	var y := 2.25 * scl
	hp_bg.position = Vector3(0, y, 0)
	hp_fg.position = Vector3(0, y, 0)
	hp_bg.visible = false
	hp_fg.visible = false

func _update_hpbar() -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var show := frac < 0.999
	hp_bg.visible = show
	hp_fg.visible = show
	if show:
		var w := 1.05 * scl
		hp_fg.scale.x = frac
		hp_fg.position.x = -w * (1.0 - frac) * 0.5

func _quad(color: Color, w: float, h: float, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = prio
	m.no_depth_test = true
	mi.material_override = m
	add_child(mi)
	return mi

# ---------------- visuals ----------------

func _build_body() -> void:
	var cloth := _mat(_cloth)
	var dark := _mat(_dark)
	var skin := _mat(_skin)
	var steel := _mat(Color(0.6, 0.62, 0.64))
	var gold := _mat(Color(0.80, 0.66, 0.26))
	var u := scl
	_box(body, Vector3(0.6, 0.7, 0.34) * u, Vector3(0, 1.12, 0) * u, cloth)
	_box(body, Vector3(0.2, 0.58, 0.22) * u, Vector3(-0.18, 0.5, 0) * u, dark)
	_box(body, Vector3(0.2, 0.58, 0.22) * u, Vector3(0.18, 0.5, 0) * u, dark)
	_box(body, Vector3(0.17, 0.5, 0.18) * u, Vector3(-0.4, 1.18, 0) * u, cloth)
	_box(body, Vector3(0.17, 0.5, 0.18) * u, Vector3(0.4, 1.18, 0) * u, cloth)
	_sphere(body, 0.19 * u, Vector3(0, 1.72, 0) * u, skin)

	match kind:
		Kind.ARCHER:
			var bow := _box(body, Vector3(0.06, 0.7, 0.06) * u, Vector3(0.42, 1.2, 0.16) * u, dark)
			bow.rotation_degrees = Vector3(0, 0, 12)
			_box(body, Vector3(0.42, 0.16, 0.42) * u, Vector3(0, 1.86, 0) * u, dark)
		Kind.SPEARMAN:
			var shaft := _box(body, Vector3(0.05, 2.0, 0.05) * u, Vector3(0.44, 1.3, 0.1) * u, dark)
			shaft.rotation_degrees = Vector3(-12, 0, 0)
			_box(body, Vector3(0.12, 0.3, 0.05) * u, Vector3(0.44, 2.3, 0.34) * u, steel)
			_box(body, Vector3(0.42, 0.16, 0.42) * u, Vector3(0, 1.86, 0) * u, dark)
		Kind.BRUTE:
			var club := _box(body, Vector3(0.12, 1.0, 0.12) * u, Vector3(0.5, 1.3, 0.12) * u, dark)
			club.rotation_degrees = Vector3(-30, 0, 0)
			_box(body, Vector3(0.3, 0.34, 0.3) * u, Vector3(0.5, 1.75, 0.3) * u, dark)
			_box(body, Vector3(0.46, 0.2, 0.46) * u, Vector3(0, 1.88, 0) * u, steel)
		Kind.BOSS:
			# voevoda: cape, ornate helm, great sword
			var cape := MeshInstance3D.new()
			var cm := BoxMesh.new(); cm.size = Vector3(0.7, 1.1, 0.1) * u
			cape.mesh = cm; cape.material_override = dark; cape.position = Vector3(0, 1.1, -0.22) * u
			body.add_child(cape)
			var gs := _box(body, Vector3(0.1, 1.6, 0.1) * u, Vector3(0.6, 1.4, 0.1) * u, steel)
			gs.rotation_degrees = Vector3(-24, 0, 0)
			_box(body, Vector3(0.48, 0.22, 0.48) * u, Vector3(0, 1.9, 0) * u, gold)  # crown
			var pl := MeshInstance3D.new()
			var pm := CylinderMesh.new(); pm.top_radius = 0.0; pm.bottom_radius = 0.12 * u; pm.height = 0.4 * u
			pl.mesh = pm; pl.material_override = _mat(Color(0.7, 0.15, 0.15)); pl.position = Vector3(0, 2.15, 0) * u
			body.add_child(pl)
		_:
			var sh := _box(body, Vector3(0.06, 0.9, 0.06) * u, Vector3(0.46, 1.2, 0.1) * u, dark)
			sh.rotation_degrees = Vector3(-30, 0, 0)
			_box(body, Vector3(0.06, 0.28, 0.3) * u, Vector3(0.46, 1.6, 0.18) * u, steel)
			_box(body, Vector3(0.42, 0.16, 0.42) * u, Vector3(0, 1.86, 0) * u, dark)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, r: float, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0
	mi.mesh = m; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	mats.append(m)
	return m
