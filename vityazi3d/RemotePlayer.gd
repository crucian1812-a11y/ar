extends Node3D
class_name RemotePlayer

# Visual stand-in for another player on the network (no input/camera/AI).
var peer_id := 0
var main = null
var char_id := 0
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var moving := false
var hp_frac := 1.0

var _model: Node3D
var _anim: AnimationPlayer
var _cur := ""
var _hp_fg: MeshInstance3D
var _ready_done := false

func _model_path(id: int) -> String:
	match id:
		0: return "res://assets/models/Knight.glb"
		1: return "res://assets/models/Barbarian.glb"
		_: return "res://assets/models/Rogue.glb"

func setup(cid: int) -> void:
	char_id = cid
	if _ready_done:
		_build()

func _ready() -> void:
	add_to_group("remote_player")
	_ready_done = true
	_build()

func _build() -> void:
	if _model:
		_model.queue_free()
		_model = null
	_model = load(_model_path(char_id)).instantiate()
	add_child(_model)
	_model.scale = Vector3.ONE * 0.82
	# show a sword so the avatar is armed-looking
	var sk := _find_class(_model, "Skeleton3D")
	if sk:
		for c in sk.get_children():
			var n := String(c.name)
			if ("Helmet" in n) or ("Hat" in n) or ("Cape" in n) or ("Shield" in n) \
				or ("Axe" in n) or ("Crossbow" in n) or ("Knife" in n) or ("Throwable" in n) \
				or ("Mug" in n) or ("Offhand" in n) or ("Badge" in n) or ("Spike" in n) \
				or ("Rectangle" in n) or ("Round" in n) or ("Bow" in n):
				c.visible = false
	_anim = _find_class(_model, "AnimationPlayer")
	if _anim:
		for a in ["Idle", "Running_A"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_cur = "Idle"
		_anim.play("Idle")
	# hp bar
	var bg := _quad(Color(0, 0, 0, 0.6), 1.0, 0.14, 0)
	_hp_fg = _quad(Color(0.4, 0.7, 1.0, 1.0), 0.92, 0.09, 1)
	bg.position = Vector3(0, 2.2, 0)
	_hp_fg.position = Vector3(0, 2.2, 0)

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	if _anim:
		var want := "Running_A" if moving else "Idle"
		if want != _cur and _anim.has_animation(want):
			_cur = want
			_anim.play(want, 0.15)
	if _hp_fg:
		_hp_fg.scale.x = clampf(hp_frac, 0.02, 1.0)
		_hp_fg.position.x = -0.92 * (1.0 - clampf(hp_frac, 0.0, 1.0)) * 0.5

# host enemies hit this avatar -> tell the owning client to apply the damage
func take_damage(d: float) -> void:
	if main and main.has_method("host_damage_remote"):
		main.host_damage_remote(peer_id, d)

func knockback(_dir: Vector3, _force: float) -> void:
	pass

func _quad(color: Color, w: float, h: float, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(w, h)
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

func _find_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_class(c, cls)
		if r:
			return r
	return null
