extends Node3D
class_name Obstacle
## A gentle hurdle (jump over) or overhang (slide under). If the player is in its
## lane AND hasn't cleared it the right way, it's a gentle, recoverable stumble.
## Clearing it — or simply being in another lane — passes. Two solutions (clear or
## dodge) keep it fair and kind. Proximity-based (no physics fiddliness).

var _kind := "hurdle"
var lane: int = 0
var _resolved := false

func setup(kind: String, lane_idx: int) -> void:
	_kind = kind
	lane = lane_idx
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.45, 0.25)
	mesh.mesh = bm
	mesh.position = Vector3(0, 0.25 if _kind == "hurdle" else 1.7, 0)   # low bar vs high bar
	var c := ThemeManager.color("accent", Color(0.9, 0.6, 0.5)).darkened(0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	position.z += GameCore.scroll_speed() * delta
	if not _resolved and absf(position.z) < 0.7:
		_resolve()
	if position.z > 4.0:
		queue_free()

func _resolve() -> void:
	_resolved = true
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or pl.current_lane != lane:
		return                       # in another lane — dodged by switching lanes
	var cleared: bool = pl.is_airborne() if _kind == "hurdle" else pl.is_sliding()
	if cleared:
		Effects.burst(global_position, Color(0.6, 0.9, 1.0), 12)   # nice clear!
		Effects.haptic("light")
	else:
		GameCore.stumble()           # gentle: costs a life, never a hard game-over
		Effects.burst(global_position, Color(0.6, 0.6, 0.6), 6)
