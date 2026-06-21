extends CharacterBody3D

var main
var hp := 70.0
const SPEED := 3.6
const GRAVITY := 22.0
var attack_cd := 0.0
var hurt_t := 0.0
var body: Node3D
var mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("enemy")
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
	body = Node3D.new()
	add_child(body)
	_build_body()

func _build_body() -> void:
	var cloth := _mat(Color(0.30, 0.36, 0.24))
	var dark := _mat(Color(0.22, 0.18, 0.14))
	var skin := _mat(Color(0.78, 0.62, 0.46))
	_box(body, Vector3(0.6, 0.7, 0.34), Vector3(0, 1.12, 0), cloth)
	_box(body, Vector3(0.2, 0.58, 0.22), Vector3(-0.18, 0.5, 0), dark)
	_box(body, Vector3(0.2, 0.58, 0.22), Vector3(0.18, 0.5, 0), dark)
	_box(body, Vector3(0.17, 0.5, 0.18), Vector3(-0.4, 1.18, 0), cloth)
	_box(body, Vector3(0.17, 0.5, 0.18), Vector3(0.4, 1.18, 0), cloth)
	_sphere(body, 0.19, Vector3(0, 1.72, 0), skin)
	_box(body, Vector3(0.42, 0.16, 0.42), Vector3(0, 1.86, 0), dark)   # fur cap
	# axe
	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.06, 0.9, 0.06)
	shaft.mesh = sm; shaft.material_override = dark
	shaft.position = Vector3(0.46, 1.2, 0.1)
	shaft.rotation_degrees = Vector3(-30, 0, 0)
	body.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(0.06, 0.28, 0.3)
	head.mesh = hm; head.material_override = _mat(Color(0.6, 0.62, 0.64))
	head.position = Vector3(0.46, 1.6, 0.18)
	body.add_child(head)

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
		var to = player.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > 1.8:
			var dir := to.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 0.15)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			if attack_cd <= 0.0:
				attack_cd = 1.3
				player.take_damage(8.0)
	move_and_slide()

func take_damage(d: float) -> void:
	hp -= d
	hurt_t = 0.15
	_set_tint(true)
	# small knockback
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var away := (global_position - player.global_position).normalized()
		velocity += away * 4.0
	if hp <= 0.0:
		Sfx.enemy_die()
		if main:
			main.on_enemy_killed()
		queue_free()

func _set_tint(on: bool) -> void:
	for m in mats:
		m.emission_enabled = on
		m.emission = Color(0.7, 0.1, 0.1)
		m.emission_energy_multiplier = 1.5

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)

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
