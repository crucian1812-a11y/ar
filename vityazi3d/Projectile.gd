extends Node3D
class_name GameProjectile

var vel := Vector3.ZERO
var dmg := 7.0
var life := 4.0
var hit_group := "player"   # whom this projectile damages

func _ready() -> void:
	add_to_group("proj")
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
	for t in get_tree().get_nodes_in_group(hit_group):
		if global_position.distance_to(t.global_position + Vector3.UP * 1.0) < 1.3:
			if t.has_method("take_damage"):
				t.take_damage(dmg)
			queue_free()
			return
	if life <= 0.0 or global_position.y < -2.0:
		queue_free()
