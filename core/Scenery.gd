extends Node3D
## Scenery.gd — procedural side decorations that scroll past the track (trees /
## asteroids / coral). Pooled + recycled like the Spawner. PURELY COSMETIC:
##   - a CODE INVARIANT keeps every prop OUTSIDE the play lanes (|x| >= play_half),
##     independent of theme data, so scenery can never block or distract gameplay;
##   - reduce_motion freezes the scroll (the static dressing stays so the world is
##     never empty).
## All primitive meshes + StandardMaterial3D — no imported art, no shaders.

const SPAWN_Z := -40.0          # matches Spawner SPAWN_Z (far ahead)
const RECYCLE_Z := 8.0          # just past the camera

var _style := "trees"
var _max_props := 14
var _min_x_margin := 0.8
var _side_band := 4.0
var _scale_min := 0.8
var _scale_max := 1.4
var _density := 1.0
var _play_half := 3.0           # computed half-width of the playfield (no props inside)

var _free: Array[Node3D] = []
var _live: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _spawn_accum := 0.0         # world-distance accumulator for even density
var _spacing := 6.0             # world units between props (derived from density)

func _ready() -> void:
	_rng.randomize()
	GameCore.run_started.connect(_repopulate)
	GameCore.returned_to_menu.connect(_repopulate)
	_repopulate()

func _apply_tuning() -> void:
	var cfg_v: Variant = ThemeManager.get_val("scenery", {})
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
	_style = str(cfg.get("style", "trees"))
	_max_props = int(cfg.get("max_props", 14))
	_min_x_margin = float(cfg.get("min_x_margin", 0.8))
	_side_band = float(cfg.get("side_band", 4.0))
	_scale_min = float(cfg.get("scale_min", 0.8))
	_scale_max = float(cfg.get("scale_max", 1.4))
	_density = maxf(float(cfg.get("density", 1.0)), 0.1)
	var lanes := int(ThemeManager.get_val("lanes", 3))
	var lane_width := float(ThemeManager.get_val("lane_width", 2.0))
	# The playfield reaches the outer lane centre plus a half-lane dodge margin —
	# props live strictly beyond this, so they can never enter a travel lane.
	_play_half = ((lanes - 1) / 2.0) * lane_width + lane_width * 0.5
	_spacing = maxf(6.0 / _density, 1.0)

## Re-read tuning, return all props to the pool, and lay a fresh static spread so
## the world is dressed immediately (even when reduce_motion freezes scrolling).
func _repopulate() -> void:
	_apply_tuning()
	for p in _live.duplicate():
		_recycle(p)
	_spawn_accum = 0.0
	var z := SPAWN_Z
	var side := 1.0
	while z < RECYCLE_Z and _live.size() < _max_props:
		_emit(z, side)
		z += _spacing
		side = -side

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	if bool(SaveManager.settings.get("reduce_motion", false)):
		return                      # static dressing stays; only the scroll freezes
	var dz := GameCore.scroll_speed() * delta
	for p in _live.duplicate():
		p.position.z += dz
		if p.position.z > RECYCLE_Z:
			_recycle(p)
	# Keep density even: emit one prop per `_spacing` world-units, alternating sides.
	_spawn_accum += dz
	while _spawn_accum >= _spacing and _live.size() < _max_props:
		_spawn_accum -= _spacing
		_emit(SPAWN_Z, 1.0 if _rng.randf() < 0.5 else -1.0)

## Place a prop on `side` (+1/-1) at depth `z`, strictly outside the lanes.
func _emit(z: float, side: float) -> void:
	if _live.size() >= _max_props:
		return
	var prop := _acquire()
	if prop == null:
		return
	var x := side * (_play_half + _min_x_margin + _rng.randf() * _side_band)
	var s := _rng.randf_range(_scale_min, _scale_max)
	prop.position = Vector3(x, 0.0, z)
	prop.scale = Vector3(s, s, s)
	prop.rotation = Vector3(0.0, _rng.randf() * TAU, 0.0)
	prop.visible = true
	_live.append(prop)

func _acquire() -> Node3D:
	if not _free.is_empty():
		return _free.pop_back()
	var prop := _build_prop()
	add_child(prop)
	return prop

func _recycle(prop: Node3D) -> void:
	_live.erase(prop)
	prop.visible = false
	if prop not in _free:
		_free.append(prop)

func _build_prop() -> Node3D:
	match _style:
		"trees": return _build_tree()
		"asteroids": return _build_asteroid()
		"coral": return _build_coral()
		_: return _build_rock()

func _build_tree() -> Node3D:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.16
	trunk.height = 1.2
	root.add_child(_mesh(trunk, Color(0.45, 0.32, 0.2), Vector3(0, 0.6, 0)))
	var leaf := ThemeManager.color("background_bottom", Color(0.4, 0.7, 0.4)).darkened(0.1)
	var c1 := PrismMesh.new()
	c1.size = Vector3(1.3, 1.2, 1.3)
	root.add_child(_mesh(c1, leaf, Vector3(0, 1.5, 0)))
	var c2 := PrismMesh.new()
	c2.size = Vector3(1.0, 1.0, 1.0)
	root.add_child(_mesh(c2, leaf.lightened(0.08), Vector3(0, 2.1, 0)))
	return root

func _build_rock() -> Node3D:
	var root := Node3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.7
	root.add_child(_mesh(s, ThemeManager.color("background_bottom", Color(0.5, 0.5, 0.55)).darkened(0.2), Vector3(0, 0.25, 0)))
	return root

func _build_asteroid() -> Node3D:
	var root := Node3D.new()
	var base := ThemeManager.color("background_bottom", Color(0.4, 0.4, 0.5)).lightened(0.05)
	var main := _mesh(_ball(0.55), base, Vector3(0, 0.4, 0))
	main.scale = Vector3(1.1, 0.8, 1.0)              # lumpy / uneven rock
	root.add_child(main)
	root.add_child(_mesh(_ball(0.28), base.darkened(0.1), Vector3(0.4, 0.55, 0.15)))
	var cry := PrismMesh.new()                        # a bright crystal accent (glows via bloom)
	cry.size = Vector3(0.2, 0.45, 0.2)
	root.add_child(_mesh(cry, ThemeManager.color("accent", Color(0.5, 0.9, 1.0)), Vector3(-0.25, 0.7, 0.0)))
	return root

func _build_coral() -> Node3D:
	var root := Node3D.new()
	var col := ThemeManager.color("accent", Color(1.0, 0.6, 0.5))
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.1
	stalk.bottom_radius = 0.16
	stalk.height = 1.0
	root.add_child(_mesh(stalk, col, Vector3(0, 0.5, 0)))
	var br := CylinderMesh.new()
	br.top_radius = 0.07
	br.bottom_radius = 0.1
	br.height = 0.7
	var b1 := _mesh(br, col.lightened(0.1), Vector3(0.18, 0.9, 0))
	b1.rotation = Vector3(0, 0, deg_to_rad(35.0))
	root.add_child(b1)
	var b2 := _mesh(br, col.lightened(0.05), Vector3(-0.18, 0.85, 0))
	b2.rotation = Vector3(0, 0, deg_to_rad(-30.0))
	root.add_child(b2)
	root.add_child(_mesh(_ball(0.12), col.lightened(0.18), Vector3(0, 1.05, 0)))   # rounded tip
	return root

func _ball(r: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	return sm

## A non-shadow-casting, tinted mesh (props are far background — keep the light cheap).
func _mesh(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
