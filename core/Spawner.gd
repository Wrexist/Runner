extends Node3D
## Spawner.gd — implements the "Rescue Run" hook.
## Each beat spawns a colored GEM, then shortly after a CAGE of the SAME color
## in the SAME lane. Grab the gem first -> swiping into the cage RESCUES the
## critter (reward). Skip the gem -> the cage is a hazard to dodge.
## One object, two meanings, one decision. This is the differentiator.

@export var gem_scene: PackedScene
@export var cage_scene: PackedScene

var spawn_timer: float = 0.0
var interval: float = 1.4
var interval_min: float = 0.7
var colors: Array = ["red", "blue", "yellow"]
var lanes_count: int = 3
var lane_width: float = 2.0
var gem_cage_gap: float = 6.0   # reaction-time window (theme/difficulty lever)
var patterns: Array = []        # data-driven spawn sequence (see theme.json)
var _last_lane: int = -1
var _rng := RandomNumberGenerator.new()
var _free: Dictionary = {"gem": [], "cage": []}   # recycled collectibles by kind
const SPAWN_Z := -40.0          # spawn ahead, scroll toward player at z=0

func _ready() -> void:
	_rng.randomize()
	_apply_tuning()
	# Re-read tuning each run so a difficulty change in Settings takes effect.
	GameCore.run_started.connect(_apply_tuning)
	GameCore.run_started.connect(_clear_field)
	GameCore.returned_to_menu.connect(_clear_field)

func _apply_tuning() -> void:
	interval = float(ThemeManager.diff_val("spawn_interval_start", 1.4))
	interval_min = float(ThemeManager.diff_val("spawn_interval_min", 0.7))
	gem_cage_gap = float(ThemeManager.diff_val("gem_cage_gap", 6.0))
	colors = ThemeManager.get_val("gem_colors", ["red", "blue", "yellow"])
	lanes_count = int(ThemeManager.get_val("lanes", 3))
	lane_width = float(ThemeManager.get_val("lane_width", 2.0))
	patterns = ThemeManager.get_val("spawn_patterns", [])

## Remove any leftover gems/cages from a previous/abandoned run so a fresh run
## always starts with a clean track.
func _clear_field() -> void:
	spawn_timer = 0.0
	_last_lane = -1
	for c in get_tree().get_nodes_in_group("collectible"):
		release(c)

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_beat()
		# Tighten spacing as the run speeds up, but never below the floor.
		var t: float = clamp(GameCore.elapsed / 60.0, 0.0, 1.0)
		spawn_timer = lerp(interval, interval_min, t)

func _spawn_beat() -> void:
	_realize_pattern(_next_pattern())

## Pick the next pattern by weight from theme data; fall back to a single pair so
## a theme with no `spawn_patterns` behaves exactly as before.
func _next_pattern() -> Dictionary:
	if patterns.is_empty():
		return {"type": "single"}
	var total := 0.0
	for p in patterns:
		total += maxf(float(p.get("weight", 1.0)), 0.0)
	if total <= 0.0:
		return patterns[0]
	var r := _rng.randf() * total
	for p in patterns:
		r -= maxf(float(p.get("weight", 1.0)), 0.0)
		if r <= 0.0:
			return p
	return patterns[patterns.size() - 1]

func _realize_pattern(pat: Dictionary) -> void:
	match str(pat.get("type", "single")):
		"rest":
			pass                       # a guaranteed empty beat (breathing room)
		"double":
			_spawn_multi(2)            # a bounded "danger zone"
		_:
			_spawn_multi(1)

## Spawn `count` gem+cage pairs in distinct lanes. SAFETY FLOOR (independent of
## theme data): never occupy more than lanes_count-1 lanes, so at least one lane
## is ALWAYS clear to dodge into — the gentle-by-design invariant, in code.
func _spawn_multi(count: int) -> void:
	var lanes := _choose_lanes(count)
	for lane in lanes:
		var color: String = colors[_rng.randi() % colors.size()]
		var x := (float(lane) - (lanes_count - 1) / 2.0) * lane_width
		# Gem first (closer), cage behind it (further), same lane + color.
		_spawn_one("gem", x, SPAWN_Z, color, lane)
		_spawn_one("cage", x, SPAWN_Z - gem_cage_gap, color, lane)
	# Track the previous lane only for single beats (keeps an obvious safe lane
	# between consecutive singles); multi beats already leave a clear lane.
	_last_lane = int(lanes[0]) if lanes.size() == 1 else -1

func _choose_lanes(count: int) -> Array:
	var n := clampi(count, 1, maxi(lanes_count - 1, 1))
	var pool: Array = []
	for i in lanes_count:
		pool.append(i)
	# For a single spawn, avoid repeating the immediately-previous lane.
	if n == 1 and _last_lane != -1 and lanes_count > 1:
		pool.erase(_last_lane)
	# Fisher–Yates with the seedable rng, then take the first n.
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, n)

func _spawn_one(kind: String, x: float, z: float, color: String, lane: int) -> void:
	var inst := _acquire(kind)
	if inst == null:
		return
	inst.position = Vector3(x, 0, z)
	if inst.has_method("setup"):
		inst.setup(color, lane)

## Pull a collectible of `kind` from the pool, or instantiate one (growing the
## pool) if none are free — so a pacing change can never starve spawns.
func _acquire(kind: String) -> Node3D:
	var pool: Array = _free.get(kind, [])
	var inst: Node3D = null
	while inst == null and not pool.is_empty():
		inst = pool.pop_back() as Node3D
		if not is_instance_valid(inst):
			inst = null
	if inst == null:
		var scene: PackedScene = gem_scene if kind == "gem" else cage_scene
		if scene == null:
			return null
		inst = scene.instantiate() as Node3D
		add_child(inst)
	inst.visible = true
	inst.set_process(true)
	if not inst.is_in_group("collectible"):
		inst.add_to_group("collectible")
	return inst

## Return a finished collectible to its pool: hidden + inert, reused next spawn.
## Idempotent (group membership is the guard), so a despawn and a clear-field
## release can't double-pool the same node.
func release(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.is_in_group("collectible"):
		return
	node.remove_from_group("collectible")
	node.visible = false
	node.set_process(false)
	var kind := str(node.get("kind"))
	if not _free.has(kind):
		_free[kind] = []
	_free[kind].append(node)
