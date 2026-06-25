extends CharacterBody3D
class_name GameEnemy

enum Kind { RAIDER, SPEARMAN, ARCHER, BRUTE, BOSS, MONGOL, MONGOL_ARCHER, MONGOL_HEAVY, KHAN, MARAUDER, VETERAN, CHAMPION, WOLF }

var kind: int = Kind.RAIDER
var main

var hp := 60.0
var max_hp := 60.0
var speed := 3.6
var dmg := 8.0
var reach := 2.0
var atk_cd_time := 1.3
var ranged := false
var mscale := 0.8
var home := Vector3.ZERO
var gold_drop := 8

# networking
var net_id := -1
var net_proxy := false          # client-side visual copy of a host enemy
var net_target := Vector3.ZERO
var net_yaw := 0.0
var net_hpfrac := 1.0
var net_moving := false
var aggroed := false            # actively aware of / chasing a player
var last_attacker := 1          # net id of whoever last hit it (kill credit)
var aggro_range := 22.0         # per-kind aggro radius
var procedural := false         # build a code mesh instead of loading a glb

const AGGRO := 22.0
const GRAVITY := 22.0
var attack_cd := 0.0
var anim_lock := 0.0
var hurt_t := 0.0

var model: Node3D
var anim: AnimationPlayer
var attack_anim := "1H_Melee_Attack_Chop"
var cur_anim := ""
var hp_bg: MeshInstance3D
var hp_fg: MeshInstance3D

const EQUIP_KEYS := ["Sword", "Axe", "Shield", "Crossbow", "Knife", "Throwable",
	"Helmet", "Hat", "Cape", "Mug", "Offhand", "Badge", "Spike", "Rectangle", "Round", "Bow"]

func _ready() -> void:
	add_to_group("enemy")
	up_direction = Vector3.UP
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(60.0)
	_apply_kind()
	max_hp = hp

	var ch := 2.0 * mscale
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * mscale
	cap.height = ch
	col.shape = cap
	col.position = Vector3(0, ch * 0.5, 0)
	add_child(col)

	_build_model()
	if kind == Kind.MONGOL or kind == Kind.MONGOL_ARCHER or kind == Kind.MONGOL_HEAVY or kind == Kind.KHAN:
		_add_horde_gear(ch)
	_build_hpbar(ch)

func _apply_kind() -> void:
	var path := "res://assets/models/Barbarian.glb"
	var show: Array = []
	aggro_range = AGGRO
	match kind:
		Kind.WOLF:
			hp = 55; speed = 5.6; dmg = 12; reach = 2.0; atk_cd_time = 0.8; mscale = 1.0
			aggro_range = 36.0; procedural = true
			attack_anim = ""
		Kind.RAIDER:
			hp = 55; speed = 3.9; dmg = 8; reach = 2.2; atk_cd_time = 1.2; mscale = 0.78
			path = "res://assets/models/Barbarian.glb"; show = ["1H_Axe", "Barbarian_Round_Shield"]
			attack_anim = "1H_Melee_Attack_Chop"
		Kind.SPEARMAN:
			hp = 65; speed = 4.4; dmg = 11; reach = 2.7; atk_cd_time = 1.1; mscale = 0.82
			path = "res://assets/models/Knight.glb"; show = ["1H_Sword"]
			attack_anim = "1H_Melee_Attack_Stab"
		Kind.ARCHER:
			hp = 40; speed = 3.2; dmg = 7; reach = 16.0; atk_cd_time = 2.1; ranged = true; mscale = 0.78
			path = "res://assets/models/Rogue.glb"; show = ["2H_Crossbow"]
			attack_anim = "2H_Ranged_Shoot"
		Kind.BRUTE:
			hp = 165; speed = 2.7; dmg = 20; reach = 2.9; atk_cd_time = 1.7; mscale = 1.05
			path = "res://assets/models/Barbarian.glb"; show = ["2H_Axe", "Barbarian_Hat"]
			attack_anim = "2H_Melee_Attack_Chop"
		Kind.BOSS:
			hp = 650; speed = 3.0; dmg = 28; reach = 3.1; atk_cd_time = 1.4; mscale = 1.5
			path = "res://assets/models/Knight.glb"; show = ["2H_Sword", "Knight_Helmet", "Knight_Cape"]
			attack_anim = "2H_Melee_Attack_Chop"
		Kind.MONGOL:
			hp = 150; speed = 4.7; dmg = 23; reach = 2.4; atk_cd_time = 1.0; mscale = 0.85
			path = "res://assets/models/Barbarian.glb"; show = ["1H_Axe", "Barbarian_Round_Shield"]
			attack_anim = "1H_Melee_Attack_Chop"
		Kind.MONGOL_ARCHER:
			hp = 95; speed = 4.2; dmg = 17; reach = 18.0; atk_cd_time = 1.5; ranged = true; mscale = 0.82
			path = "res://assets/models/Rogue.glb"; show = ["2H_Crossbow"]
			attack_anim = "2H_Ranged_Shoot"
		Kind.MONGOL_HEAVY:
			hp = 340; speed = 2.9; dmg = 36; reach = 3.0; atk_cd_time = 1.5; mscale = 1.18
			path = "res://assets/models/Barbarian.glb"; show = ["2H_Axe", "Barbarian_Hat"]
			attack_anim = "2H_Melee_Attack_Chop"
		Kind.KHAN:
			hp = 2400; speed = 3.3; dmg = 50; reach = 3.5; atk_cd_time = 1.15; mscale = 2.4
			path = "res://assets/models/Knight.glb"; show = ["2H_Sword", "Knight_Helmet", "Knight_Cape"]
			attack_anim = "2H_Melee_Attack_Chop"
		Kind.MARAUDER:
			hp = 42; speed = 5.0; dmg = 9; reach = 2.2; atk_cd_time = 0.65; mscale = 0.72
			path = "res://assets/models/Barbarian.glb"; show = ["1H_Axe", "Barbarian_Round_Shield"]
			attack_anim = "1H_Melee_Attack_Chop"
		Kind.VETERAN:
			hp = 130; speed = 3.3; dmg = 15; reach = 2.5; atk_cd_time = 1.0; mscale = 0.92
			path = "res://assets/models/Knight.glb"; show = ["1H_Sword", "Knight_Helmet"]
			attack_anim = "1H_Melee_Attack_Slice_Diagonal"
		Kind.CHAMPION:
			hp = 230; speed = 3.1; dmg = 26; reach = 2.9; atk_cd_time = 1.15; mscale = 1.12
			path = "res://assets/models/Knight.glb"; show = ["2H_Sword", "Knight_Cape", "Knight_Helmet"]
			attack_anim = "2H_Melee_Attack_Chop"
	_model_path = path
	_show = show

var _model_path := ""
var _show: Array = []

func _build_model() -> void:
	if procedural:
		model = _build_wolf()
		add_child(model)
		model.scale = Vector3.ONE * mscale
		anim = null
		return
	model = load(_model_path).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * mscale
	var sk := _find_class(model, "Skeleton3D")
	if sk:
		for c in sk.get_children():
			if _is_equip(String(c.name)):
				c.visible = String(c.name) in _show
	anim = _find_class(model, "AnimationPlayer")
	if anim:
		for a in ["Idle", "Running_A"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		cur_anim = "Idle"
		anim.play("Idle")

# iconic pointed Tatar/Mongol helmet + horde banner so the eastern army reads at a glance
func _add_horde_gear(ch: float) -> void:
	var khan := kind == Kind.KHAN
	var head_y := ch * 0.92
	# pointed conical helmet
	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = (0.34 if khan else 0.26)
	cone.height = (0.7 if khan else 0.5)
	hat.mesh = cone
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.78, 0.66, 0.22) if khan else Color(0.32, 0.28, 0.22)
	hm.metallic = 0.7; hm.roughness = 0.35
	hat.material_override = hm
	hat.position = Vector3(0, head_y + (0.36 if khan else 0.26), 0)
	add_child(hat)
	# fur/cloth brim
	var brim := MeshInstance3D.new()
	var bc := CylinderMesh.new(); bc.top_radius = (0.36 if khan else 0.28); bc.bottom_radius = (0.36 if khan else 0.28); bc.height = 0.12
	brim.mesh = bc
	brim.material_override = _flat_e(Color(0.45, 0.12, 0.10) if khan else Color(0.3, 0.2, 0.12))
	brim.position = Vector3(0, head_y + 0.06, 0)
	add_child(brim)
	# back banner with a horsetail tug
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.04; pm.bottom_radius = 0.05; pm.height = (3.6 if khan else 2.6)
	pole.mesh = pm; pole.material_override = _flat_e(Color(0.3, 0.22, 0.14))
	pole.position = Vector3(-0.3 if not khan else -0.5, (3.6 if khan else 2.6) * 0.5, -0.35)
	add_child(pole)
	var flag := MeshInstance3D.new()
	var fb := BoxMesh.new(); fb.size = Vector3(0.7 if khan else 0.5, 0.45, 0.04)
	flag.mesh = fb
	flag.material_override = _flat_e(Color(0.7, 0.12, 0.10) if khan else Color(0.5, 0.35, 0.12))
	flag.position = Vector3((-0.3 if not khan else -0.5) + (0.4 if khan else 0.3), (3.4 if khan else 2.5), -0.35)
	add_child(flag)

func _flat_e(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

# low-poly wolf built in code (no quadruped model in the asset pack)
func _build_wolf() -> Node3D:
	var root := Node3D.new()
	var fur := StandardMaterial3D.new(); fur.albedo_color = Color(0.30, 0.29, 0.31); fur.roughness = 1.0
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.18, 0.17, 0.19); dark.roughness = 1.0
	# body
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(0.5, 0.5, 1.15)
	body.mesh = bb; body.material_override = fur; body.position = Vector3(0, 0.62, 0)
	root.add_child(body)
	# chest/hindquarters bulk
	var rump := MeshInstance3D.new()
	var rb := BoxMesh.new(); rb.size = Vector3(0.56, 0.56, 0.45)
	rump.mesh = rb; rump.material_override = fur; rump.position = Vector3(0, 0.66, -0.45)
	root.add_child(rump)
	# neck + head
	var neck := MeshInstance3D.new()
	var nb := BoxMesh.new(); nb.size = Vector3(0.34, 0.34, 0.4)
	neck.mesh = nb; neck.material_override = fur; neck.position = Vector3(0, 0.74, 0.6)
	root.add_child(neck)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new(); hb.size = Vector3(0.36, 0.34, 0.4)
	head.mesh = hb; head.material_override = fur; head.position = Vector3(0, 0.82, 0.86)
	root.add_child(head)
	var snout := MeshInstance3D.new()
	var sb := BoxMesh.new(); sb.size = Vector3(0.18, 0.18, 0.26)
	snout.mesh = sb; snout.material_override = dark; snout.position = Vector3(0, 0.74, 1.08)
	root.add_child(snout)
	# ears
	for ex in [-0.12, 0.12]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new(); ec.top_radius = 0.0; ec.bottom_radius = 0.09; ec.height = 0.18
		ear.mesh = ec; ear.material_override = dark; ear.position = Vector3(ex, 1.04, 0.82)
		root.add_child(ear)
	# eyes (glowing)
	var em := StandardMaterial3D.new(); em.albedo_color = Color(1.0, 0.85, 0.2)
	em.emission_enabled = true; em.emission = Color(1.0, 0.8, 0.1); em.emission_energy_multiplier = 2.0
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ex2 in [-0.1, 0.1]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new(); es.radius = 0.045; es.height = 0.09
		eye.mesh = es; eye.material_override = em; eye.position = Vector3(ex2, 0.86, 1.02)
		root.add_child(eye)
	# legs
	for lx in [-0.18, 0.18]:
		for lz in [0.4, -0.5]:
			var leg := MeshInstance3D.new()
			var lc := CylinderMesh.new(); lc.top_radius = 0.09; lc.bottom_radius = 0.07; lc.height = 0.6
			leg.mesh = lc; leg.material_override = dark; leg.position = Vector3(lx, 0.3, lz)
			root.add_child(leg)
	# tail
	var tail := MeshInstance3D.new()
	var tc := CylinderMesh.new(); tc.top_radius = 0.05; tc.bottom_radius = 0.12; tc.height = 0.5
	tail.mesh = tc; tail.material_override = fur
	tail.position = Vector3(0, 0.78, -0.78); tail.rotation_degrees = Vector3(-50, 0, 0)
	root.add_child(tail)
	return root

func _is_equip(n: String) -> bool:
	for k in EQUIP_KEYS:
		if k in n:
			return true
	return false

func _nearest_player():
	var best = null
	var bd := 1e18
	for p in get_tree().get_nodes_in_group("player"):
		var d: float = p.global_position.distance_to(global_position)
		if d < bd:
			bd = d; best = p
	return best

func _physics_process(delta: float) -> void:
	if net_proxy:
		# client-side: just follow the host's transform/hp, no AI or physics
		var f := clampf(delta * 12.0, 0.0, 1.0)
		global_position = global_position.lerp(net_target, f)
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, net_yaw, f)
		hp = net_hpfrac * max_hp
		var np = _nearest_player()
		var npd: float = np.global_position.distance_to(global_position) if np else 999.0
		aggroed = npd <= aggro_range
		if anim:
			anim.active = npd < 80.0
		if npd < 80.0:
			_update_anim(net_moving)
		_update_hpbar()
		return

	attack_cd = maxf(0.0, attack_cd - delta)
	if hurt_t > 0.0: hurt_t -= delta
	if anim_lock > 0.0: anim_lock -= delta

	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)

	var player = _nearest_player()
	var moving := false
	if player:
		var to: Vector3 = player.global_position - global_position
		to.y = 0
		var dist := to.length()
		var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
		aggroed = dist <= aggro_range

		# performance: far enemies stop animating & idle in place
		if dist > 80.0 and is_on_floor():
			if anim and anim.active:
				anim.active = false
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_update_hpbar()
			return
		elif anim and not anim.active:
			anim.active = true

		if dist > aggro_range:
			# passive: stay near the camp until the player comes close
			var hto := home - global_position
			hto.y = 0
			if hto.length() > 3.0:
				var hd := hto.normalized()
				velocity.x = hd.x * speed * 0.4
				velocity.z = hd.z * speed * 0.4
				moving = true
				if model:
					model.rotation.y = lerp_angle(model.rotation.y, atan2(hd.x, hd.z), 0.1)
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
			move_and_slide()
			_update_anim(moving)
			_update_hpbar()
			return

		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.15)

		if ranged:
			if dist > reach + 2.0:
				velocity.x = dir.x * speed; velocity.z = dir.z * speed; moving = true
			elif dist < reach - 6.0:
				velocity.x = -dir.x * speed; velocity.z = -dir.z * speed; moving = true
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
			if dist <= reach and attack_cd <= 0.0:
				attack_cd = atk_cd_time
				_shoot(player)
				_play_attack()
		else:
			if dist > reach:
				velocity.x = dir.x * speed; velocity.z = dir.z * speed; moving = true
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
				if attack_cd <= 0.0:
					attack_cd = atk_cd_time
					player.take_damage(dmg)
					_play_attack()
					if kind in [Kind.BRUTE, Kind.BOSS, Kind.MONGOL_HEAVY, Kind.KHAN] and player.has_method("knockback"):
						player.knockback((player.global_position - global_position).normalized(), 7.0)
	move_and_slide()
	_update_anim(moving)
	_update_hpbar()

func _play_attack() -> void:
	if anim and anim.has_animation(attack_anim):
		anim.play(attack_anim)
		cur_anim = attack_anim
		anim_lock = anim.get_animation(attack_anim).length * 0.9

func _update_anim(moving: bool) -> void:
	if anim == null or anim_lock > 0.0:
		return
	var want := "Running_A" if moving else "Idle"
	if cur_anim != want and anim.has_animation(want):
		cur_anim = want
		anim.play(want, 0.15)

func _shoot(player) -> void:
	var pr := GameProjectile.new()
	pr.dmg = dmg
	get_parent().add_child(pr)
	pr.global_position = global_position + Vector3.UP * (1.4 * mscale)
	var target: Vector3 = player.global_position + Vector3.UP * 1.0
	pr.vel = (target - pr.global_position).normalized() * 18.0

func take_damage(d: float, by: int = 1) -> void:
	# client proxy: don't resolve damage locally, ask the host to apply it
	if net_proxy:
		hurt_t = 0.12
		if main and main.has_method("client_hit_enemy"):
			main.client_hit_enemy(net_id, d)
		return
	hp -= d
	hurt_t = 0.12
	aggroed = true
	last_attacker = by
	var player = _nearest_player()
	if player:
		var away: Vector3 = (global_position - player.global_position).normalized()
		velocity += away * (1.5 if (kind == Kind.BOSS or kind == Kind.KHAN) else 4.0)
	if hp <= 0.0:
		Sfx.enemy_die()
		if main:
			if kind == Kind.BOSS and main.has_method("on_boss_killed"):
				main.on_boss_killed()
			if kind == Kind.KHAN and main.has_method("on_khan_killed"):
				main.on_khan_killed()
			main.on_enemy_killed(global_position, gold_drop, last_attacker, kind)
		queue_free()

# ---------------- hp bar ----------------

func _build_hpbar(ch: float) -> void:
	var y := ch + 0.35
	hp_bg = _quad(Color(0, 0, 0, 0.6), 1.15, 0.18, 0, y)
	hp_fg = _quad(Color(0.85, 0.22, 0.18, 1.0), 1.05, 0.12, 1, y)
	hp_bg.visible = false
	hp_fg.visible = false

func _update_hpbar() -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var show := frac < 0.999
	hp_bg.visible = show
	hp_fg.visible = show
	if show:
		hp_fg.scale.x = frac
		hp_fg.position.x = -1.05 * (1.0 - frac) * 0.5

func _quad(color: Color, w: float, h: float, prio: int, y: float) -> MeshInstance3D:
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
	mi.position = Vector3(0, y, 0)
	add_child(mi)
	return mi

func _find_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_class(c, cls)
		if r:
			return r
	return null
