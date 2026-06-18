extends Node
## Discovery (autoload) — occasional GENTLE surprises so "what will this run be?"
## stays alive: a free treat (a power-up on the house) or a bonus shower (a little
## score + a big celebration), announced with a flourish. Pure positive,
## single-player curiosity — NO FOMO, NO currency, NO loss, NO "come back tomorrow".

signal discovery(name: String)

var _timer := 0.0
var _interval := 35.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	GameCore.run_started.connect(_on_run_started)

func _on_run_started() -> void:
	_interval = maxf(float(ThemeManager.get_val("discovery_interval", 35.0)), 5.0)
	_timer = _interval

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _interval
		_fire()

func _fire() -> void:
	if _rng.randf() < 0.5:
		# A free treat: a random gentle power-up, on the house.
		var kind: String = Powerups.KINDS[_rng.randi() % Powerups.KINDS.size()]
		Powerups.activate(kind, float(ThemeManager.get_val("powerup_duration", 6.0)))
		emit_signal("discovery", "treat")
	else:
		# A bonus shower: a little score and a big celebration.
		GameCore.add_score(15)
		emit_signal("discovery", "shower")
