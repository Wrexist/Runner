extends Node3D
class_name ChoiceGate
## A branching CHOICE: each lane floats a different reward. Steer into the lane
## with the reward you want — your choice shapes the run. The rewards you don't take
## are simply not granted (no penalty, no loss): gentle decision-making, never
## punishment. All rewards are positive (power-ups or a small bonus).

const POOL := ["shield", "slow", "magnet", "double", "bonus"]

var rewards: Array = []
var _resolved := false

func setup(lanes_count: int, lane_width: float) -> void:
	var pool: Array = POOL.duplicate()
	pool.shuffle()
	rewards.clear()
	for i in lanes_count:
		var kind: String = str(pool[i % pool.size()])
		rewards.append(kind)
		var x := (float(i) - (lanes_count - 1) / 2.0) * lane_width
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		orb.mesh = sm
		orb.material_override = Style.emissive(_color(kind), 1.3)
		orb.position = Vector3(x, 1.0, 0.0)
		add_child(orb)

func _color(kind: String) -> Color:
	return Color(1.0, 0.85, 0.3) if kind == "bonus" else Powerup.color_for(kind)

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
	var lane := int(pl.current_lane) if pl else 0
	if lane < 0 or lane >= rewards.size():
		return
	var kind: String = str(rewards[lane])
	if kind == "bonus":
		GameCore.add_score(20)
	else:
		Powerups.activate(kind, float(ThemeManager.get_val("powerup_duration", 6.0)))
	Effects.burst(global_position, _color(kind), 18)
	Effects.haptic("rescue")
	AudioManager.play_sfx("powerup")
