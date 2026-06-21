extends CharacterBody3D

var main
var controls

var max_hp := 100.0
var hp := 100.0
const SPEED := 7.0
const JUMP := 9.5
const GRAVITY := 22.0
const CAM_DIST := 7.0

# character / weapon
var char_id := 0
var weapon := 0          # 0 sword, 1 axe, 2 spear
var atk_dmg := 40.0
var atk_reach := 2.6
var atk_cd_time := 0.45

var cam_yaw := 0.0
var cam_pitch := 0.5
var cam: Camera3D
var body: Node3D
var sword_pivot: Node3D
var attack_t := -1.0
var attack_cd := 0.0
var hurt_t := 0.0

func _ready() -> void:
	add_to_group("player")
	up_direction = Vector3.UP
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(60.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	cam = Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.current = true

	set_character(0)

func set_character(id: int) -> void:
	char_id = id
	match id:
		0:  # Саша — меч
			weapon = 0; atk_dmg = 42; atk_reach = 2.6; atk_cd_time = 0.45
		1:  # Глеб — секира
			weapon = 1; atk_dmg = 62; atk_reach = 2.5; atk_cd_time = 0.62
		2:  # Федя — копьё
			weapon = 2; atk_dmg = 34; atk_reach = 3.6; atk_cd_time = 0.40
	_build_body()

func _clothes() -> Array:
	match char_id:
		1: return [Color(0.30, 0.45, 0.30), Color(0.18, 0.28, 0.18)]   # Глеб green
		2: return [Color(0.28, 0.36, 0.52), Color(0.16, 0.22, 0.34)]   # Федя blue
		_: return [Color(0.62, 0.20, 0.18), Color(0.40, 0.12, 0.12)]   # Саша crimson

func _build_body() -> void:
	if body != null:
		body.queue_free()
	body = Node3D.new()
	add_child(body)

	var cc := _clothes()
	var cloth := _mat(cc[0])
	var clothDark := _mat(cc[1])
	var skin := _mat(Color(0.86, 0.70, 0.55))
	var metal := _mat(Color(0.74, 0.77, 0.82))
	var metalDark := _mat(Color(0.45, 0.48, 0.53))
	var gold := _mat(Color(0.80, 0.66, 0.26))
	var blade := _mat(Color(0.9, 0.9, 0.86))

	_box(body, Vector3(0.62, 0.72, 0.36), Vector3(0, 1.15, 0), metal)
	_box(body, Vector3(0.64, 0.12, 0.38), Vector3(0, 0.82, 0), gold)
	_box(body, Vector3(0.22, 0.6, 0.24), Vector3(-0.2, 0.5, 0), cloth)
	_box(body, Vector3(0.22, 0.6, 0.24), Vector3(0.2, 0.5, 0), cloth)
	_box(body, Vector3(0.18, 0.5, 0.2), Vector3(-0.42, 1.2, 0), metal)
	_box(body, Vector3(0.18, 0.5, 0.2), Vector3(0.42, 1.2, 0), metal)
	_sphere(body, 0.2, Vector3(0, 1.75, 0), skin)
	_sphere(body, 0.23, Vector3(0, 1.82, 0), metal)
	var spike := MeshInstance3D.new()
	var sc := CylinderMesh.new(); sc.top_radius = 0.0; sc.bottom_radius = 0.08; sc.height = 0.25
	spike.mesh = sc; spike.material_override = metal; spike.position = Vector3(0, 2.05, 0)
	body.add_child(spike)
	# shield
	var shield := MeshInstance3D.new()
	var shm := CylinderMesh.new(); shm.top_radius = 0.32; shm.bottom_radius = 0.32; shm.height = 0.06
	shield.mesh = shm; shield.material_override = metalDark
	shield.rotation_degrees = Vector3(90, 0, 0)
	shield.position = Vector3(-0.5, 1.15, -0.18)
	body.add_child(shield)
	# weapon on a pivot (right hand)
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.5, 1.2, 0.05)
	body.add_child(sword_pivot)
	match weapon:
		0:  # sword
			var b := _box(sword_pivot, Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), blade)
			_box(sword_pivot, Vector3(0.26, 0.08, 0.08), Vector3(0, 0.05, 0), gold)
		1:  # axe
			_box(sword_pivot, Vector3(0.07, 1.0, 0.07), Vector3(0, 0.5, 0), clothDark)
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new(); hm.size = Vector3(0.4, 0.34, 0.08)
			head.mesh = hm; head.material_override = metal; head.position = Vector3(0.18, 0.85, 0)
			sword_pivot.add_child(head)
		2:  # spear
			_box(sword_pivot, Vector3(0.05, 1.7, 0.05), Vector3(0, 0.85, 0), clothDark)
			var tip := MeshInstance3D.new()
			var tm := CylinderMesh.new(); tm.top_radius = 0.0; tm.bottom_radius = 0.1; tm.height = 0.35
			tip.mesh = tm; tip.material_override = metal; tip.position = Vector3(0, 1.85, 0)
			sword_pivot.add_child(tip)
	sword_pivot.rotation_degrees = Vector3(-20, 0, 0)

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if hurt_t > 0.0: hurt_t -= delta

	if controls:
		cam_yaw -= controls.consume_look() * 0.005

	var stick: Vector2 = controls.move_vec if controls else Vector2.ZERO
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := fwd * stick.y + right * stick.x

	if dir.length() > 0.15:
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 0.25)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)

	var want_jump: bool = controls != null and controls.consume_jump()
	if is_on_floor():
		if want_jump:
			velocity.y = JUMP
			Sfx.jump()
		else:
			velocity.y = -2.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)

	if controls and controls.consume_attack() and attack_cd <= 0.0:
		attack_cd = atk_cd_time
		attack_t = 0.3
		Sfx.swing()
		_do_attack()

	move_and_slide()
	_animate(delta)
	_update_camera()

func _animate(delta: float) -> void:
	if attack_t > 0.0:
		attack_t -= delta
		var p := 1.0 - (attack_t / 0.3)
		sword_pivot.rotation_degrees.x = lerp(-110.0, 60.0, clampf(p, 0.0, 1.0))
	else:
		sword_pivot.rotation_degrees.x = lerp(sword_pivot.rotation_degrees.x, -20.0, 0.2)

func _do_attack() -> void:
	var fwd := -body.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemy"):
		var to = e.global_position - global_position
		if to.length() < atk_reach and fwd.dot(to.normalized()) > 0.2:
			e.take_damage(atk_dmg)
			Sfx.hit()

func take_damage(d: float) -> void:
	if hurt_t > 0.0:
		return
	hp -= d
	hurt_t = 0.6
	Sfx.hurt()
	if hp < 0.0:
		hp = 0.0

func knockback(dir: Vector3, force: float) -> void:
	velocity.x += dir.x * force
	velocity.z += dir.z * force

func _update_camera() -> void:
	var target := global_position + Vector3.UP * 1.6
	var horiz := CAM_DIST * cos(cam_pitch)
	var off := Vector3(sin(cam_yaw) * horiz, CAM_DIST * sin(cam_pitch), cos(cam_yaw) * horiz)
	cam.global_position = target + off
	cam.look_at(target, Vector3.UP)

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
	return m
