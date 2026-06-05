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

func _ready() -> void:
	lanes_count = int(ThemeManager.get_val("lanes", 3))
	lane_width = float(ThemeManager.get_val("lane_width", 2.0))
	current_lane = lanes_count / 2       # integer center lane
	_target_x = _lane_to_x(current_lane)
	position.x = _target_x

func _lane_to_x(lane: int) -> float:
	return (lane - (lanes_count - 1) / 2.0) * lane_width

func move_lane(dir: int) -> void:
	current_lane = clampi(current_lane + dir, 0, lanes_count - 1)
	_target_x = _lane_to_x(current_lane)

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

# --- Rescue Run color carrying (called by Collectible) ---
func carry_color(c: String) -> void:
	carried_color = c

func clear_color() -> void:
	carried_color = ""
