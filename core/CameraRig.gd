extends Camera3D
## CameraRig — gentle smoothed follow on the player's lane position. Subtle
## (40% of the player's x) so the track stays readable for young eyes. No shake.

@export var follow_amount: float = 0.4
@export var smooth_speed: float = 5.0

var _player: Node3D
var _base: Vector3
var _base_fov: float
var _zoom_amount: float = 0.0     # extra FOV degrees at max speed (themed, 0 = off)

func _ready() -> void:
	_base = position
	_base_fov = fov
	follow_amount = float(ThemeManager.get_val("camera_follow", 0.4))
	smooth_speed = float(ThemeManager.get_val("camera_smooth", 5.0))
	_zoom_amount = float(ThemeManager.get_val("camera_zoom_amount", 0.0))
	await get_tree().process_frame      # let Main finish instancing the player
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if _player == null:
		return
	var rm := bool(SaveManager.settings.get("reduce_motion", false))
	# Reduce-motion: keep the camera still rather than following the lane.
	var amount := 0.0 if rm else follow_amount
	var target_x := _base.x + _player.position.x * amount
	position.x = lerpf(position.x, target_x, clampf(delta * smooth_speed, 0.0, 1.0))
	# A subtle, bounded sense-of-speed FOV nudge as the run accelerates. Off when
	# camera_zoom_amount is 0 or under reduce_motion (readability first; no shake).
	var target_fov := _base_fov
	if not rm and _zoom_amount > 0.0:
		var smax := float(ThemeManager.diff_val("scroll_speed_max", 18.0))
		var t := clampf(GameCore.current_speed / maxf(smax, 0.001), 0.0, 1.0)
		target_fov = _base_fov + _zoom_amount * t
	fov = lerpf(fov, target_fov, clampf(delta * smooth_speed, 0.0, 1.0))
