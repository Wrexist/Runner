extends Node3D
## Player.gd — lane-based movement for the rescue runner.
## Input: swipe/drag on touch, arrow keys on desktop (NO tilt — small kids and
## reviewers both hate tilt). Holds the carried gem color for the Rescue Run
## mechanic: grab a gem -> carry its color -> swipe into a same-color cage to
## rescue the critter inside.

var lanes_count: int = 3
var lane_width: float = 2.0
var current_lane: int = 1
var move_speed: float = 12.0          # how fast we slide between lanes
var carried_color: String = ""

var _target_x: float = 0.0
var _swipe_start_x: float = 0.0
var _swiping: bool = false
const SWIPE_THRESHOLD := 40.0          # pixels before a drag counts as a swipe

# Breadcrumb of recent positions so the rescue Trail can snake behind us.
var _history: Array[Vector3] = []
const HISTORY_MAX := 240

func _ready() -> void:
	lanes_count = int(ThemeManager.get_val("lanes", 3))
	lane_width = float(ThemeManager.get_val("lane_width", 2.0))
	current_lane = lanes_count / 2       # integer center lane
	_target_x = _lane_to_x(current_lane)
	position.x = _target_x

func _lane_to_x(lane: int) -> float:
	return (lane - (lanes_count - 1) / 2.0) * lane_width

func move_lane(dir: int) -> void:
	var before := current_lane
	current_lane = clampi(current_lane + dir, 0, lanes_count - 1)
	_target_x = _lane_to_x(current_lane)
	if current_lane != before:
		_lean(dir)

## A quick lean into the turn that settles back — makes movement feel alive.
func _lean(dir: int) -> void:
	var mesh := get_node_or_null("MeshInstance3D") as Node3D
	if mesh == null:
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(mesh, "rotation:z", deg_to_rad(-14.0 * dir), 0.08)
	t.tween_property(mesh, "rotation:z", 0.0, 0.16)

## Position from `steps` frames ago (clamped). Used by Trail.gd.
func history_point(steps: int) -> Vector3:
	if _history.is_empty():
		return global_position
	return _history[mini(steps, _history.size() - 1)]

func _unhandled_input(event: InputEvent) -> void:
	if GameCore.state != GameCore.State.PLAYING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			move_lane(-1)
		elif event.keycode == KEY_RIGHT:
			move_lane(1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_x = event.position.x
			_swiping = true
		else:
			_swiping = false
	elif event is InputEventScreenDrag and _swiping:
		var dx := event.position.x - _swipe_start_x
		if absf(dx) >= SWIPE_THRESHOLD:
			move_lane(1 if dx > 0.0 else -1)
			_swiping = false        # one lane per swipe; release to swipe again

func _process(delta: float) -> void:
	position.x = move_toward(position.x, _target_x, move_speed * delta)
	_history.push_front(global_position)
	if _history.size() > HISTORY_MAX:
		_history.resize(HISTORY_MAX)

# --- Rescue Run color carrying (called by Collectible) ---
func carry_color(c: String) -> void:
	carried_color = c

func clear_color() -> void:
	carried_color = ""
