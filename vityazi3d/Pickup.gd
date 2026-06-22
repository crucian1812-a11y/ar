extends Node3D
class_name GamePickup

# kind: "gold" / "weapon" / "armor" / "heal"
var kind := "gold"
var value := 20.0
var main
var _t := 0.0

func _ready() -> void:
	add_to_group("pickup")
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.3
	match kind:
		"gold":
			var c := CylinderMesh.new(); c.top_radius = 0.28; c.bottom_radius = 0.28; c.height = 0.08
			mi.mesh = c
			mat.albedo_color = Color(0.95, 0.78, 0.25); mat.metallic = 0.8
			mi.rotation_degrees = Vector3(90, 0, 0)
		"weapon":
			var b := BoxMesh.new(); b.size = Vector3(0.1, 0.7, 0.1)
			mi.mesh = b
			mat.albedo_color = Color(0.85, 0.86, 0.9); mat.metallic = 0.7
		"armor":
			var b2 := BoxMesh.new(); b2.size = Vector3(0.5, 0.6, 0.12)
			mi.mesh = b2
			mat.albedo_color = Color(0.45, 0.6, 0.8); mat.metallic = 0.4
		_:
			var s := SphereMesh.new(); s.radius = 0.25; s.height = 0.5
			mi.mesh = s
			mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.4
	mi.material_override = mat
	add_child(mi)
	# glow base
	var glow := OmniLight3D.new()
	glow.light_color = mat.albedo_color
	glow.light_energy = 0.6
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.5, 0)
	add_child(glow)

func _process(delta: float) -> void:
	_t += delta
	rotate_y(delta * 1.8)
	position.y += sin(_t * 3.0) * delta * 0.25
	var p = get_tree().get_first_node_in_group("player")
	if p and global_position.distance_to(p.global_position) < 2.0:
		_collect(p)

func _collect(p) -> void:
	var msg := ""
	match kind:
		"gold":
			p.add_gold(int(value)); msg = "+%d золота" % int(value); Sfx.coin()
		"weapon":
			p.add_dmg(value); msg = "Найдено оружие: +%d к урону" % int(value); Sfx.buy()
		"armor":
			p.add_armor(value); msg = "Найден доспех"; Sfx.buy()
		"heal":
			p.heal(value); msg = "+%d здоровья" % int(value); Sfx.coin()
	if main and main.has_method("show_toast"):
		main.show_toast(msg)
	if main and main.has_method("on_pickup"):
		main.on_pickup()
	queue_free()
