extends Node3D
## Trail — the visible reward: every rescued critter joins a conga line that
## snakes behind the player (Snake-style, with smoothing). Caps the *visible*
## length for performance while GameCore keeps counting beyond it.

const Z_SPACING := 0.45       # world gap between followers, behind the player
const HISTORY_STEPS := 9      # how far back in the player's path each link reads
const MAX_VISIBLE := 10       # keeps the tail between the player (z≈0) and camera (z≈8)
const FOLLOW_SMOOTH := 12.0

var _player: Node3D
var _followers: Array[Node3D] = []

func _ready() -> void:
	GameCore.run_started.connect(_reset)
	GameCore.returned_to_menu.connect(_reset)
	GameCore.critter_rescued.connect(_on_rescued)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _reset() -> void:
	for f in _followers:
		if is_instance_valid(f):
			f.queue_free()
	_followers.clear()

func _on_rescued(_id: String, _total: int) -> void:
	if _followers.size() >= MAX_VISIBLE:
		return
	var f := _make_follower()
	add_child(f)
	if _player:
		f.global_position = _player.global_position
	_followers.append(f)
	Effects.pop(f, 1.6)

func _make_follower() -> Node3D:
	var n := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.28
	m.height = 0.56
	n.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ThemeManager.color("accent", Color(1.0, 0.55, 0.6))
	n.material_override = mat
	return n

func _process(delta: float) -> void:
	if _player == null or not _player.has_method("history_point"):
		return
	var t := clampf(delta * FOLLOW_SMOOTH, 0.0, 1.0)
	for i in _followers.size():
		var delayed: Vector3 = _player.history_point((i + 1) * HISTORY_STEPS)
		# Lane (x) trails the player's past; z fans out behind toward the camera.
		var target := Vector3(delayed.x, _player.global_position.y, (i + 1) * Z_SPACING)
		_followers[i].global_position = _followers[i].global_position.lerp(target, t)
