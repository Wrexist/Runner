extends Node3D
class_name Giant
## A rare, GENTLE "giant friend" encounter — a spectacle, never a boss to fight.
## A big friendly creature drifts in majestically; reaching it is a celebration
## with a reward (a free power-up + a score bonus). No combat, no threat, no
## stumble — pure wonder ("a world event" the kind way).

var _resolved := false

func setup() -> void:
	var body := ThemeModels.critter_visual({"id": "giant"}, 0.9)
	body.scale = Vector3(2.2, 2.2, 2.2)
	add_child(body)

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	position.z += GameCore.scroll_speed() * delta * 0.7   # drifts a touch slower (majestic)
	if not bool(SaveManager.settings.get("reduce_motion", false)):
		rotation.y += delta * 0.3
	if not _resolved and position.z > -3.0:
		_resolve()
	if position.z > 7.0:
		queue_free()

func _resolve() -> void:
	_resolved = true
	GameCore.add_score(30)
	var kind: String = Powerups.KINDS[randi() % Powerups.KINDS.size()]
	Powerups.activate(kind, float(ThemeManager.get_val("powerup_duration", 6.0)))
	GameCore.emit_signal("giant_met")
	Effects.burst(global_position, ThemeManager.color("accent", Color(1.0, 0.8, 0.4)), 30)
	Effects.haptic("rescue")
