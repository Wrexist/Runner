extends Node
## Powerups (autoload) — gentle, run-scoped "roguelike build" effects. They are
## picked up FREE during a run (never bought, never a paid/random reward), and
## stack into a build:
##   shield : absorbs the next stumble (more forgiving — never a punishment)
##   slow   : calmly slows the world for a few seconds (easier, soothing)
##   magnet : gems drift toward your lane (easier pickups — NOT coins/currency)
##   double : rescues score double for a while (pure celebration)
## COMPLIANCE: no currency, no purchase, no loss-on-death, no FOMO. Pure positive
## help that makes "what will this run be?" fun without any dark pattern.

signal powerup_changed(kind: String, active: bool)

const KINDS := ["shield", "slow", "magnet", "double"]

var _active: Dictionary = {}   # kind -> seconds remaining ("shield" holds a charge)

func _ready() -> void:
	GameCore.run_started.connect(clear_all)
	GameCore.returned_to_menu.connect(clear_all)
	GameCore.run_ended.connect(func(_s, _h): clear_all())

## Turn a power-up on. `shield` is a single charge; the others are timed.
func activate(kind: String, duration: float = 6.0) -> void:
	if kind == "shield":
		_active[kind] = 1.0
	else:
		_active[kind] = maxf(duration, 0.1)
	emit_signal("powerup_changed", kind, true)

func is_active(kind: String) -> bool:
	return _active.has(kind)

## Spend the shield charge if present (so a stumble is absorbed, not punished).
func consume_shield() -> bool:
	if _active.has("shield"):
		_active.erase("shield")
		emit_signal("powerup_changed", "shield", false)
		return true
	return false

## Scroll-speed factor (<1 while "slow" is active), read by the scrolling systems.
func slow_multiplier() -> float:
	return float(ThemeManager.get_val("slow_factor", 0.55)) if is_active("slow") else 1.0

func rescue_multiplier() -> int:
	return 2 if is_active("double") else 1

func clear_all() -> void:
	var had: Array = _active.keys()
	_active.clear()
	for k in had:
		emit_signal("powerup_changed", str(k), false)

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	for kind in _active.keys():
		if kind == "shield":
			continue                    # a charge, not a timer
		_active[kind] -= delta
		if _active[kind] <= 0.0:
			_active.erase(kind)
			emit_signal("powerup_changed", str(kind), false)
