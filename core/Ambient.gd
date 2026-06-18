extends Node3D
## Ambient.gd — a slow, gentle drifting particle field around the player (forest
## fireflies / space stars / ocean bubbles). A SINGLE persistent CPUParticles3D
## (cheap), themed, that rides along just ahead of the player so the field always
## fills the visible corridor. FULLY suppressed under reduce_motion AND under the
## headless renderer (construction is safe; only emission is gated).

var _p: CPUParticles3D
var _player: Node
var _style := "fireflies"

func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.emitting = false
	_p.local_coords = false        # particles stay in world space as the emitter moves
	add_child(_p)
	_apply_tuning()
	ThemeManager.theme_loaded.connect(func(_id): _apply_tuning())
	await get_tree().process_frame  # let Main finish instancing the player
	_player = get_tree().get_first_node_in_group("player")

func _apply_tuning() -> void:
	var cfg_v: Variant = ThemeManager.get_val("ambient", {})
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
	_style = str(cfg.get("style", "fireflies"))
	_p.amount = maxi(int(cfg.get("amount", 24)), 1)
	_p.lifetime = 6.0
	_p.color = Color(str(cfg.get("color", "#fff2a8")))
	var bx := 6.0
	var by := 3.0
	var bz := 20.0
	var box_v: Variant = cfg.get("box", [])
	if box_v is Array and (box_v as Array).size() >= 3:
		bx = float(box_v[0])
		by = float(box_v[1])
		bz = float(box_v[2])
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(bx, by, bz)
	var speed := float(cfg.get("speed", 0.4))
	# Drift direction per style: bubbles rise, stars/dust sink slowly, fireflies hover.
	match _style:
		"bubbles":
			_p.gravity = Vector3(0, 1.2, 0)
			_p.direction = Vector3(0, 1, 0)
		"stars":
			_p.gravity = Vector3(0, -0.2, 0)
			_p.direction = Vector3(0, -1, 0)
		_:
			_p.gravity = Vector3.ZERO
			_p.direction = Vector3(0, 1, 0)
	_p.initial_velocity_min = speed * 0.5
	_p.initial_velocity_max = speed
	var sm := SphereMesh.new()      # tiny round mote
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 4
	sm.rings = 2
	_p.mesh = sm

func _process(_delta: float) -> void:
	# Emit only on a real renderer with motion allowed; otherwise fully off.
	var rm := bool(SaveManager.settings.get("reduce_motion", false))
	var allow := not rm and DisplayServer.get_name() != "headless"
	if _p.emitting != allow:
		_p.emitting = allow
	if rm:
		return
	if _player and is_instance_valid(_player):
		global_position = Vector3(0.0, 1.5, _player.global_position.z - 6.0)
