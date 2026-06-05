extends Camera3D
## CameraRig — gentle smoothed follow on the player's lane position. Subtle
## (40% of the player's x) so the track stays readable for young eyes. No shake.

@export var follow_amount: float = 0.4
@export var smooth_speed: float = 5.0

var _player: Node3D
var _base: Vector3

func _ready() -> void:
	_base = position
	await get_tree().process_frame      # let Main finish instancing the player
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if _player == null:
		return
	var target_x := _base.x + _player.position.x * follow_amount
	position.x = lerpf(position.x, target_x, clampf(delta * smooth_speed, 0.0, 1.0))
