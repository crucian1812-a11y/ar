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

# weapon/equipment databases
var WEAPONS := [
	{"name": "Меч", "model": "res://assets/weapons/sword_1handed.gltf", "anim": "1H_Melee_Attack_Slice_Diagonal", "dmg": 42.0, "reach": 2.7, "cd": 0.55, "two": false},
	{"name": "Двуручный меч", "model": "res://assets/weapons/sword_2handed.gltf", "anim": "2H_Melee_Attack_Chop", "dmg": 76.0, "reach": 3.0, "cd": 0.82, "two": true},
	{"name": "Боевой топор", "model": "res://assets/weapons/axe_1handed.gltf", "anim": "1H_Melee_Attack_Chop", "dmg": 52.0, "reach": 2.6, "cd": 0.6, "two": false},
	{"name": "Секира", "model": "res://assets/weapons/axe_2handed.gltf", "anim": "2H_Melee_Attack_Chop", "dmg": 88.0, "reach": 2.9, "cd": 0.9, "two": true},
	{"name": "Кинжал", "model": "res://assets/weapons/dagger.gltf", "anim": "1H_Melee_Attack_Stab", "dmg": 34.0, "reach": 2.3, "cd": 0.38, "two": false},
	{"name": "Копьё", "model": "res://assets/weapons/staff.gltf", "anim": "2H_Melee_Attack_Stab", "dmg": 60.0, "reach": 3.5, "cd": 0.6, "two": true},
	{"name": "Арбалет", "model": "res://assets/weapons/crossbow_2handed.gltf", "anim": "2H_Ranged_Shoot", "dmg": 44.0, "reach": 22.0, "cd": 1.0, "two": true, "ranged": true},
	# --- unique rewards (quests only) ---
	{"name": "Меч-кладенец", "model": "res://assets/weapons/sword_2handed.gltf", "anim": "2H_Melee_Attack_Chop", "dmg": 120.0, "reach": 3.3, "cd": 0.7, "two": true, "rare": true, "tint": Color(1.0, 0.84, 0.30)},
	{"name": "Секира Перуна", "model": "res://assets/weapons/axe_2handed.gltf", "anim": "2H_Melee_Attack_Chop", "dmg": 140.0, "reach": 3.0, "cd": 0.85, "two": true, "rare": true, "tint": Color(0.65, 0.85, 1.0)},
	{"name": "Лук Соловья", "model": "res://assets/weapons/crossbow_2handed.gltf", "anim": "2H_Ranged_Shoot", "dmg": 82.0, "reach": 26.0, "cd": 0.8, "two": true, "ranged": true, "rare": true, "tint": Color(0.55, 1.0, 0.55)},
]
const UNARMED := {"name": "Кулаки", "dmg": 14.0, "reach": 2.0, "cd": 0.5, "anim": "1H_Melee_Attack_Slice_Diagonal"}
var SHIELDS := [
	{"name": "Без щита", "model": "", "armor": 0.0},
	{"name": "Круглый щит", "model": "res://assets/weapons/shield_round.gltf", "armor": 0.10},
	{"name": "Большой щит", "model": "res://assets/weapons/shield_square.gltf", "armor": 0.18},
]
var ARMOR_TIERS := [0.0, 0.12, 0.22]
var ARMOR_NAMES := ["нет", "кольчуга", "латы"]

# ownership / equipped
var gold := 60
var dmg_bonus := 0.0
var owned_weapons := [0]
var equipped_weapon := 0
var owned_shields := [0]
var equipped_shield := 0
var helmet_owned := false
var helmet_on := false
var owned_armors := []      # tiers the player owns (1 = кольчуга, 2 = латы)
var equipped_armor := 0     # 0 = none
var armor := 0.0

# combat
var atk_dmg := 42.0
var atk_reach := 2.7
var atk_cd_time := 0.55
var attack_anim := "1H_Melee_Attack_Slice_Diagonal"
var ranged := false

# dodge
const DODGE_SPEED := 16.0
const DODGE_TIME := 0.32
const DODGE_CD := 0.8
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.FORWARD

var cam_yaw := 0.0
var cam_pitch := 0.5
var cam: Camera3D
var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var weapon_holder: BoneAttachment3D
var shield_holder: BoneAttachment3D
var helmet_node: Node = null
var dust: CPUParticles3D
var idle_anim := "Idle"
var run_anim := "Running_A"
var cur_anim := ""
var attack_cd := 0.0
var anim_lock := 0.0
var hurt_t := 0.0
var step_t := 0.0

const HIDE_KEYS := ["Sword", "Axe", "Shield", "Crossbow", "Knife", "Throwable",
	"Mug", "Offhand", "Badge", "Spike", "Rectangle", "Round", "Bow", "Cape"]

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
	_build_dust()
	set_character(0)

func _build_dust() -> void:
	dust = CPUParticles3D.new()
	dust.amount = 10
	dust.lifetime = 0.5
	dust.emitting = false
	dust.local_coords = false
	dust.direction = Vector3.UP
	dust.spread = 38.0
	dust.gravity = Vector3(0, 1.0, 0)
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.8
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.billboard_keep_scale = true
	q.material = dm
	dust.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.64, 0.5, 0.0))
	ramp.set_color(1, Color(0.6, 0.52, 0.4, 0.0))
	ramp.add_point(0.3, Color(0.7, 0.62, 0.48, 0.4))
	dust.color_ramp = ramp
	dust.position = Vector3(0, 0.1, 0)
	add_child(dust)

func _model_path(id: int) -> String:
	match id:
		0: return "res://assets/models/Knight.glb"
		1: return "res://assets/models/Barbarian.glb"
		_: return "res://assets/models/Rogue.glb"

func set_character(id: int) -> void:
	char_id = id
	# reset RPG state
	gold = 60
	dmg_bonus = 0.0
	owned_shields = [0]
	equipped_shield = 0
	helmet_owned = false
	helmet_on = false
	owned_armors = []
	equipped_armor = 0
	match id:
		0: owned_weapons = [0]; equipped_weapon = 0
		1: owned_weapons = [2]; equipped_weapon = 2
		_: owned_weapons = [4]; equipped_weapon = 4

	if model != null:
		model.queue_free()
	model = load(_model_path(id)).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	skel = _find_class(model, "Skeleton3D")
	anim = _find_class(model, "AnimationPlayer")
	helmet_node = null
	if skel:
		# hide all built-in weapons/shields/capes; keep helmet/hat for toggle
		for c in skel.get_children():
			var nm := String(c.name)
			if ("Helmet" in nm) or ("Hat" in nm):
				helmet_node = c
				c.visible = false
			elif _should_hide(nm):
				c.visible = false
		weapon_holder = BoneAttachment3D.new()
		weapon_holder.bone_name = "handslot.r"
		skel.add_child(weapon_holder)
		shield_holder = BoneAttachment3D.new()
		shield_holder.bone_name = "handslot.l"
		skel.add_child(shield_holder)
	if anim:
		for a in [idle_anim, run_anim]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		cur_anim = idle_anim
		anim.play(idle_anim)
	equip_weapon(equipped_weapon)

func _should_hide(n: String) -> bool:
	for k in HIDE_KEYS:
		if k in n:
			return true
	return false

# ---- equipment ----
func own_weapon(i: int) -> void:
	if not (i in owned_weapons):
		owned_weapons.append(i)
func own_shield(i: int) -> void:
	if not (i in owned_shields):
		owned_shields.append(i)

func equip_weapon(i: int) -> void:
	equipped_weapon = i
	if i < 0:
		# unarmed
		atk_dmg = UNARMED["dmg"]; atk_reach = UNARMED["reach"]; atk_cd_time = UNARMED["cd"]
		attack_anim = UNARMED["anim"]; ranged = false
		if weapon_holder:
			for c in weapon_holder.get_children():
				c.queue_free()
		_refresh_shield()
		_recalc_armor()
		return
	var w = WEAPONS[i]
	atk_dmg = w["dmg"]; atk_reach = w["reach"]; atk_cd_time = w["cd"]; attack_anim = w["anim"]
	ranged = w.get("ranged", false)
	if weapon_holder:
		for c in weapon_holder.get_children():
			c.queue_free()
		if w["model"] != "":
			var inst = load(w["model"]).instantiate()
			weapon_holder.add_child(inst)
			if w.get("rare", false):
				_tint(inst, w.get("tint", Color(1.0, 0.85, 0.3)))
	_refresh_shield()
	_recalc_armor()

func unequip_weapon() -> void:
	equip_weapon(-1)

func _tint(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = 0.85
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.45
		node.material_override = m
	for c in node.get_children():
		_tint(c, col)

func equip_shield(i: int) -> void:
	equipped_shield = i
	_refresh_shield()
	_recalc_armor()

func _refresh_shield() -> void:
	if shield_holder == null:
		return
	for c in shield_holder.get_children():
		c.queue_free()
	var two: bool = WEAPONS[equipped_weapon].get("two", false)
	if equipped_shield >= 1 and not two and SHIELDS[equipped_shield]["model"] != "":
		shield_holder.add_child(load(SHIELDS[equipped_shield]["model"]).instantiate())

func toggle_helmet() -> void:
	if not helmet_owned:
		return
	helmet_on = not helmet_on
	if helmet_node:
		helmet_node.visible = helmet_on
	_recalc_armor()

func own_armor(t: int) -> void:
	t = clampi(t, 1, ARMOR_TIERS.size() - 1)
	if not (t in owned_armors):
		owned_armors.append(t)

func set_armor_tier(t: int) -> void:
	# grant ownership and equip it
	if t >= 1:
		own_armor(t)
	equipped_armor = clampi(t, 0, ARMOR_TIERS.size() - 1)
	_recalc_armor()

func equip_armor(t: int) -> void:
	equipped_armor = clampi(t, 0, ARMOR_TIERS.size() - 1)
	_recalc_armor()

func unequip_armor() -> void:
	equipped_armor = 0
	_recalc_armor()

func _recalc_armor() -> void:
	var a: float = ARMOR_TIERS[equipped_armor]
	if helmet_on:
		a += 0.06
	var two: bool = WEAPONS[equipped_weapon].get("two", false)
	if equipped_shield >= 1 and not two:
		a += SHIELDS[equipped_shield].get("armor", 0.0)
	armor = clampf(a, 0.0, 0.7)

# ---- loop ----
func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	if hurt_t > 0.0: hurt_t -= delta
	if anim_lock > 0.0: anim_lock -= delta
	if dodge_t > 0.0: dodge_t -= delta

	if controls:
		cam_yaw -= controls.consume_look() * 0.005

	var stick: Vector2 = controls.move_vec if controls else Vector2.ZERO
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := fwd * stick.y + right * stick.x
	var moving := false

	if dodge_t > 0.0:
		velocity.x = dodge_dir.x * DODGE_SPEED
		velocity.z = dodge_dir.z * DODGE_SPEED
	elif dir.length() > 0.15:
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

	if controls and controls.consume_dodge() and dodge_cd <= 0.0 and is_on_floor():
		dodge_cd = DODGE_CD
		dodge_t = DODGE_TIME
		hurt_t = maxf(hurt_t, DODGE_TIME)
		var dd := dir if dir.length() > 0.1 else Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
		dodge_dir = dd.normalized()
		if model:
			model.rotation.y = atan2(dodge_dir.x, dodge_dir.z)
		if anim and anim.has_animation("Dodge_Forward"):
			anim.play("Dodge_Forward")
			cur_anim = "Dodge_Forward"
			anim_lock = DODGE_TIME

	if controls and controls.consume_attack() and attack_cd <= 0.0 and dodge_t <= 0.0:
		attack_cd = atk_cd_time
		Sfx.swing()
		_do_attack()
		if anim and anim.has_animation(attack_anim):
			anim.play(attack_anim)
			cur_anim = attack_anim
			anim_lock = anim.get_animation(attack_anim).length * 0.9

	move_and_slide()
	if dust:
		dust.emitting = (moving or dodge_t > 0.0) and is_on_floor()
	# footsteps timed to the run cadence
	if moving and is_on_floor() and dodge_t <= 0.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.34
			var surf := "grass"
			if main and main.has_method("surface_at"):
				surf = main.surface_at(global_position)
			Sfx.step(surf)
	else:
		step_t = 0.0
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
	var f := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) if model else -global_transform.basis.z
	if ranged:
		var tgt = _nearest_enemy()
		var start := global_position + Vector3.UP * 1.3 + f * 0.6
		var aim := f
		if tgt:
			aim = (tgt.global_position + Vector3.UP * 1.0 - start).normalized()
		var pr := GameProjectile.new()
		pr.hit_group = "enemy"
		pr.dmg = atk_dmg + dmg_bonus
		get_parent().add_child(pr)
		pr.global_position = start
		pr.vel = aim * 30.0
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		var to = e.global_position - global_position
		if to.length() < atk_reach and f.dot(to.normalized()) > 0.1:
			e.take_damage(atk_dmg + dmg_bonus)
			Sfx.hit()
			if main and main.has_method("spawn_hit_sparks"):
				main.spawn_hit_sparks(e.global_position + Vector3.UP * 1.2)

func _nearest_enemy():
	var best = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d; best = e
	return best

func take_damage(d: float) -> void:
	if hurt_t > 0.0:
		return
	hp -= d * (1.0 - clampf(armor, 0.0, 0.7))
	hurt_t = 0.6
	Sfx.hurt()
	if hp < 0.0:
		hp = 0.0

func knockback(dir: Vector3, force: float) -> void:
	velocity.x += dir.x * force
	velocity.z += dir.z * force

func add_gold(n: int) -> void: gold += n
func add_dmg(n: float) -> void: dmg_bonus += n
func add_armor(n: float) -> void:
	var t: int = mini(equipped_armor + 1, ARMOR_TIERS.size() - 1)
	own_armor(t)
	equipped_armor = t
	_recalc_armor()
func heal(n: float) -> void: hp = minf(hp + n, max_hp)
func add_maxhp(n: float) -> void: max_hp += n; hp = max_hp
func total_dmg() -> int: return int(atk_dmg + dmg_bonus)

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
