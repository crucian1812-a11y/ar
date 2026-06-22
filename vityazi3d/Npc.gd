extends Node3D
class_name GameNpc

var label := "Торговец"

func _ready() -> void:
	add_to_group("npc")
	var m = load("res://assets/models/Knight.glb").instantiate()
	add_child(m)
	m.scale = Vector3.ONE * 0.82
	# peaceful merchant: hide all weapons/shields, keep helmet
	var sk := _find_class(m, "Skeleton3D")
	if sk:
		for c in sk.get_children():
			var n := String(c.name)
			if ("Sword" in n) or ("Shield" in n) or ("Axe" in n) or ("Crossbow" in n) \
				or ("Knife" in n) or ("Offhand" in n) or ("Badge" in n) or ("Spike" in n) \
				or ("Rectangle" in n) or ("Round" in n) or ("Cape" in n) or ("Bow" in n):
				c.visible = false
	var ap := _find_class(m, "AnimationPlayer")
	if ap and ap.has_animation("Idle"):
		ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")

	# floating gold marker
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new(); s.radius = 0.18; s.height = 0.36
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.78, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.6, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(0, 2.4, 0)
	add_child(mi)

func _find_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_class(c, cls)
		if r:
			return r
	return null
