extends Node3D
class_name GameProjectile

var vel := Vector3.ZERO
var dmg := 7.0
var life := 4.0

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.08, 0.08, 0.7)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.78, 0.5)
	mi.material_override = mat
	add_child(mi)

func _process(delta: float) -> void:
	global_position += vel * delta
	if vel.length() > 0.01:
		look_at(global_position + vel, Vector3.UP)
	life -= delta
	var p = get_tree().get_first_node_in_group("player")
	if p and global_position.distance_to(p.global_position + Vector3.UP * 1.0) < 1.2:
		if p.has_method("take_damage"):
			p.take_damage(dmg)
		queue_free()
		return
	if life <= 0.0 or global_position.y < -2.0:
		queue_free()
