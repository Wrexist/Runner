extends Node3D
## LaneMarkers.gd — procedural dashed dividers BETWEEN the lanes, so the track
## reads as moving "racing stripes" and the three lanes stay obvious. The dashes
## are placed exactly on the computed lane boundaries and scroll toward the player,
## wrapping around. reduce_motion -> static dashes (lanes stay legible; only the
## scroll freezes). Shared mesh + material, no shadows, no art, no shaders.

const SPAWN_Z := -40.0
const RECYCLE_Z := 8.0

var _enabled := true
var _color := Color(1, 1, 1, 0.6)
var _dash_len := 1.2
var _dash_gap := 1.4
var _boundaries: Array[float] = []
var _dashes: Array[MeshInstance3D] = []
var _mesh: BoxMesh
var _mat: StandardMaterial3D

func _ready() -> void:
	GameCore.run_started.connect(_rebuild)
	GameCore.returned_to_menu.connect(_rebuild)
	_rebuild()

func _apply_tuning() -> void:
	var cfg_v: Variant = ThemeManager.get_val("lane_marker", {})
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
	_enabled = bool(cfg.get("enabled", true))
	_color = Color(str(cfg.get("color", "#ffffff")))
	_dash_len = float(cfg.get("dash_len", 1.2))
	_dash_gap = float(cfg.get("dash_gap", 1.4))
	var lanes := int(ThemeManager.get_val("lanes", 3))
	var lane_width := float(ThemeManager.get_val("lane_width", 2.0))
	_boundaries = []
	for i in maxi(lanes - 1, 0):    # one divider between each pair of lanes
		_boundaries.append((i + 0.5 - (lanes - 1) / 2.0) * lane_width)

func _rebuild() -> void:
	_apply_tuning()
	for d in _dashes:
		d.queue_free()
	_dashes.clear()
	if not _enabled or _boundaries.is_empty():
		return
	_refresh_shared()
	var step := _dash_len + _dash_gap
	for bx in _boundaries:
		var z := SPAWN_Z
		while z < RECYCLE_Z:
			_dashes.append(_make_dash(bx, z))
			z += step

func _refresh_shared() -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.12, 0.02, _dash_len)
	if _mat == null:
		_mat = StandardMaterial3D.new()
	_mat.albedo_color = _color
	_mat.emission_enabled = true
	_mat.emission = _color
	_mat.emission_energy_multiplier = 0.4
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # gentle, semi-transparent

func _make_dash(x: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(x, 0.02, z)
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	if bool(SaveManager.settings.get("reduce_motion", false)):
		return                       # static dashes stay drawn; only the scroll freezes
	var dz := GameCore.scroll_speed() * delta
	var span := RECYCLE_Z - SPAWN_Z
	for d in _dashes:
		d.position.z += dz
		if d.position.z > RECYCLE_Z:
			d.position.z -= span     # wrap back to the far end
