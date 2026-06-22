extends CharacterBody3D

var main
var controls

var max_hp := 100.0
var hp := 100.0
const SPEED := 7.0
const JUMP := 9.5
const GRAVITY := 22.0
const CAM_DIST := 7.0
const MODEL_SCALE := 0.82

var char_id := 0
var atk_dmg := 42.0
var atk_reach := 2.8
var atk_cd_time := 0.6

var cam_yaw := 0.0
var cam_pitch := 0.5
var cam: Camera3D
var model: Node3D
var anim: AnimationPlayer
var idle_anim := "Idle"
var run_anim := "Running_A"
var attack_anim := "1H_Melee_Attack_Slice_Diagonal"
var cur_anim := ""

var attack_cd := 0.0
var anim_lock := 0.0
var hurt_t := 0.0

const EQUIP_KEYS := ["Sword", "Axe", "Shield", "Crossbow", "Knife", "Throwable",
	"Helmet", "Hat", "Cape", "Mug", "Offhand", "Badge", "Spike", "Rectangle", "Round", "Bow"]

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
	var path := ""
	var show: Array = []
	match id:
		0:  # Саша — рыцарь с мечом и щитом
			path = "res://assets/models/Knight.glb"
			show = ["1H_Sword", "Round_Shield", "Knight_Helmet"]
			attack_anim = "1H_Melee_Attack_Slice_Diagonal"
			atk_dmg = 42; atk_reach = 2.7; atk_cd_time = 0.55
		1:  # Глеб — богатырь с секирой
			path = "res://assets/models/Barbarian.glb"
			show = ["2H_Axe", "Barbarian_Hat"]
			attack_anim = "2H_Melee_Attack_Chop"
			atk_dmg = 64; atk_reach = 2.7; atk_cd_time = 0.7
		2:  # Федя — ловкач с кинжалами
			path = "res://assets/models/Rogue.glb"
			show = ["Knife", "Knife_Offhand", "Rogue_Cape"]
			attack_anim = "Dualwield_Melee_Attack_Slice"
			atk_dmg = 30; atk_reach = 2.4; atk_cd_time = 0.38

	if model != null:
		model.queue_free()
	model = load(path).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE

	var sk := _find_class(model, "Skeleton3D")
	if sk:
		for c in sk.get_children():
			if _is_equip(String(c.name)):
				c.visible = String(c.name) in show
	anim = _find_class(model, "AnimationPlayer")
	if anim:
		for a in [idle_anim, run_anim]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		cur_anim = idle_anim
		anim.play(idle_anim)

func _is_equip(n: String) -> bool:
	for k in EQUIP_KEYS:
		if k in n:
			return true
	return false

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if hurt_t > 0.0: hurt_t -= delta
	if anim_lock > 0.0: anim_lock -= delta

	if controls:
		cam_yaw -= controls.consume_look() * 0.005

	var stick: Vector2 = controls.move_vec if controls else Vector2.ZERO
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := fwd * stick.y + right * stick.x
	var moving := false

	if dir.length() > 0.15:
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		moving = true
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.25)
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
		Sfx.swing()
		_do_attack()
		if anim and anim.has_animation(attack_anim):
			anim.play(attack_anim)
			cur_anim = attack_anim
			anim_lock = anim.get_animation(attack_anim).length * 0.9

	move_and_slide()
	_update_anim(moving)
	_update_camera()

func _update_anim(moving: bool) -> void:
	if anim == null or anim_lock > 0.0:
		return
	var want := run_anim if moving else idle_anim
	if cur_anim != want and anim.has_animation(want):
		cur_anim = want
		anim.play(want, 0.15)

func _do_attack() -> void:
	var f := -global_transform.basis.z
	if model:
		f = Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	for e in get_tree().get_nodes_in_group("enemy"):
		var to = e.global_position - global_position
		if to.length() < atk_reach and f.dot(to.normalized()) > 0.1:
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

func _find_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_class(c, cls)
		if r:
			return r
	return null
