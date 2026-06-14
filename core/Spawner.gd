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
var _last_lane: int = -1
const SPAWN_Z := -40.0          # spawn ahead, scroll toward player at z=0

func _ready() -> void:
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

## Remove any leftover gems/cages from a previous/abandoned run so a fresh run
## always starts with a clean track.
func _clear_field() -> void:
	spawn_timer = 0.0
	_last_lane = -1
	for c in get_tree().get_nodes_in_group("collectible"):
		c.queue_free()

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_pair()
		# Tighten spacing as the run speeds up, but never below the floor.
		var t: float = clamp(GameCore.elapsed / 60.0, 0.0, 1.0)
		spawn_timer = lerp(interval, interval_min, t)

func _spawn_pair() -> void:
	# Avoid repeating the same lane twice in a row so there's always an easy,
	# obvious safe lane — keeps it fair and gentle for the youngest players.
	var lane := randi() % lanes_count
	if lane == _last_lane and lanes_count > 1:
		lane = (lane + 1 + (randi() % (lanes_count - 1))) % lanes_count
	_last_lane = lane
	var color: String = colors[randi() % colors.size()]
	var x := (lane - (lanes_count - 1) / 2.0) * lane_width
	# Gem first (closer), cage behind it (further), same lane + color.
	_spawn_one(gem_scene, x, SPAWN_Z, color, lane)
	_spawn_one(cage_scene, x, SPAWN_Z - gem_cage_gap, color, lane)

func _spawn_one(scene: PackedScene, x: float, z: float, color: String, lane: int) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	add_child(inst)
	inst.position = Vector3(x, 0, z)
	if inst.has_method("setup"):
		inst.setup(color, lane)
