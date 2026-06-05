extends Node
## Effects (autoload) — fire-and-forget visual juice. Kept GENTLE on purpose:
## soft particle bursts and quick scale "pops", never harsh screen shake.
## Autoload Node3D children render in the root viewport's World3D, i.e. the same
## 3D world as Main, so bursts appear right where the action happened.

## A soft confetti/sparkle burst at a world position.
func burst(global_pos: Vector3, color: Color, amount: int = 16) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount, 1)
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.28
	p.color = color
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	add_child(p)
	p.global_position = global_pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## A quick squash-and-stretch "pop" on any Node3D. Safe if the node goes away.
func pop(node: Node3D, strength: float = 1.3, time: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base: Vector3 = node.scale
	var t := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base * strength, time * 0.4)
	t.tween_property(node, "scale", base, time * 0.6)
