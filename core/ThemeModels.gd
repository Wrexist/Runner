extends RefCounted
class_name ThemeModels
## ThemeModels.gd — loads per-theme 3D art and degrades gracefully when it's
## missing. This is what makes dropping a `.glb` at a `theme.json` asset path
## "just work" with no scene edits: the gameplay nodes ask here for a visual and
## get either the real imported model OR a charming procedural placeholder, so
## the game is fun to play before any art exists AND reskins for free after.
##
## FAIL-SOFT by contract: a missing/unimported path returns null (callers keep
## their placeholder). Never crashes — this is a kids' app that must keep running.

## Instance a model from a res:// path. Accepts an imported scene (.glb) or a raw
## Mesh resource. Returns a Node3D, or null if the path is empty/absent.
static func instance(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is PackedScene:
		var n: Node = (res as PackedScene).instantiate()
		if n is Node3D:
			return n
		n.queue_free()
		return null
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res
		return mi
	return null

## Apply a flat albedo tint to every MeshInstance3D under `root`. Used for gems
## and cages, which MUST read as a single theme color for the matching mechanic.
static func tint(root: Node, color: Color) -> void:
	for mi in _mesh_instances(root):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat

static func _mesh_instances(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_mesh_instances(c))
	return out

## A stable, distinct, pleasant color per critter id — so the rescue conga line
## and the album are a varied rainbow of friends, not identical blobs (even with
## zero downloaded art). Deterministic: the same id always gets the same hue.
static func critter_color(id: String) -> Color:
	var hue := float(absi(hash(id)) % 360) / 360.0
	return Color.from_hsv(hue, 0.5, 0.95)

## The visual for a rescued critter: its real model if present, else a charming
## procedural creature colored by `critter_color`. `critter_detail` ("full" |
## "simple") lets a calmer/low-end theme fall back to the gentle two-blob form.
static func critter_visual(critter: Dictionary, body_radius: float = 0.28) -> Node3D:
	var model := instance(str(critter.get("model", "")))
	if model:
		return model
	var id := str(critter.get("id", "critter"))
	if str(ThemeManager.get_val("critter_detail", "full")) == "simple":
		return _simple_creature(id, body_radius)
	return _build_creature(id, body_radius)

## The original gentle two-blob (kept for "simple" detail / continuity).
static func _simple_creature(id: String, body_radius: float) -> Node3D:
	var col := critter_color(id)
	var root := Node3D.new()
	root.add_child(_blob(body_radius, col, Vector3.ZERO))
	root.add_child(_blob(body_radius * 0.6, col.lightened(0.18),
		Vector3(0, body_radius * 0.85, 0)))
	return root

## A feature-assembled creature: body + head + eyes, plus a DETERMINISTIC set of
## features (ears / tail / fin / antennae / snout) chosen from the id hash, so each
## rescued friend has a distinct silhouette — still soft and kid-friendly, no art.
static func _build_creature(id: String, body_radius: float) -> Node3D:
	var col := critter_color(id)
	var accent := col.lightened(0.18)
	var h := absi(hash(id))
	var r := body_radius
	var root := Node3D.new()
	root.add_child(_blob(r, col, Vector3.ZERO))                 # body
	var head_y := r * 0.95
	root.add_child(_blob(r * 0.62, accent, Vector3(0, head_y, 0)))  # head
	# Two tiny dark eyes — a big, cheap "alive" readability win.
	var eye := Color(0.12, 0.12, 0.14)
	root.add_child(_blob(r * 0.12, eye, Vector3(-r * 0.22, head_y + r * 0.08, r * 0.5)))
	root.add_child(_blob(r * 0.12, eye, Vector3(r * 0.22, head_y + r * 0.08, r * 0.5)))
	# Disjoint bit-slices of the hash pick the silhouette features.
	match h % 3:
		1: _add_ears(root, accent, r, head_y, false)   # round ears
		2: _add_ears(root, accent, r, head_y, true)    # pointy ears
	match (h / 3) % 3:
		0: root.add_child(_prim(_sphere(r * 0.3), col.lightened(0.1), Vector3(0, 0, -r * 0.95)))   # tail nub
		1: _add_fin(root, accent, r)                   # back fin
	if (h / 9) % 2 == 1:
		_add_antennae(root, accent, r, head_y)
	if (h / 18) % 2 == 1:
		root.add_child(_prim(_sphere(r * 0.18), accent, Vector3(0, head_y - r * 0.05, r * 0.6)))   # snout
	return root

static func _add_ears(root: Node3D, color: Color, r: float, head_y: float, pointy: bool) -> void:
	var ear: Mesh
	if pointy:
		var pm := PrismMesh.new()
		pm.size = Vector3(r * 0.3, r * 0.5, r * 0.2)
		ear = pm
	else:
		ear = _sphere(r * 0.22)
	var ey := head_y + r * 0.55
	root.add_child(_prim(ear, color, Vector3(-r * 0.34, ey, 0)))
	root.add_child(_prim(ear, color, Vector3(r * 0.34, ey, 0)))

static func _add_fin(root: Node3D, color: Color, r: float) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(r * 0.5, r * 0.7, r * 0.12)
	root.add_child(_prim(pm, color, Vector3(0, r * 0.7, -r * 0.1)))

static func _add_antennae(root: Node3D, color: Color, r: float, head_y: float) -> void:
	var stalk := CylinderMesh.new()
	stalk.top_radius = r * 0.04
	stalk.bottom_radius = r * 0.04
	stalk.height = r * 0.5
	var ay := head_y + r * 0.7
	root.add_child(_prim(stalk, color, Vector3(-r * 0.18, ay, 0)))
	root.add_child(_prim(stalk, color, Vector3(r * 0.18, ay, 0)))
	root.add_child(_prim(_sphere(r * 0.08), color.lightened(0.2), Vector3(-r * 0.18, ay + r * 0.3, 0)))
	root.add_child(_prim(_sphere(r * 0.08), color.lightened(0.2), Vector3(r * 0.18, ay + r * 0.3, 0)))

static func _sphere(radius: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	return sm

## A tinted MeshInstance3D from any mesh at a local position.
static func _prim(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi

## A procedural PLAYER silhouette (used when no `player_model` .glb is present) so
## the runner reads as a themed character/vehicle instead of a bare box. Accent-
## driven; fail-soft to a neutral capsule for an unknown shape.
static func player_visual(shape: String, accent: Color, body_radius: float = 0.4) -> Node3D:
	var root := Node3D.new()
	var r := body_radius
	match shape:
		"rocket":
			var body := CapsuleMesh.new()
			body.radius = r * 0.55
			body.height = r * 2.0
			root.add_child(_prim(body, accent, Vector3(0, r * 0.8, 0)))
			var nose := CylinderMesh.new()        # top_radius 0 = a cone
			nose.top_radius = 0.0
			nose.bottom_radius = r * 0.55
			nose.height = r * 0.7
			root.add_child(_prim(nose, accent.lightened(0.25), Vector3(0, r * 1.9, 0)))
			var fin := PrismMesh.new()
			fin.size = Vector3(r * 0.5, r * 0.6, r * 0.12)
			root.add_child(_prim(fin, accent.darkened(0.2), Vector3(-r * 0.55, r * 0.2, 0)))
			root.add_child(_prim(fin, accent.darkened(0.2), Vector3(r * 0.55, r * 0.2, 0)))
		"sub":
			var hull := CapsuleMesh.new()
			hull.radius = r * 0.65
			hull.height = r * 2.4
			var hmi := _prim(hull, accent, Vector3(0, r * 0.55, 0))
			hmi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)   # lie along z (forward)
			root.add_child(hmi)
			var tower := CylinderMesh.new()
			tower.top_radius = r * 0.22
			tower.bottom_radius = r * 0.3
			tower.height = r * 0.55
			root.add_child(_prim(tower, accent.darkened(0.12), Vector3(0, r * 1.05, r * 0.1)))
			root.add_child(_prim(_sphere(r * 0.2), Color(0.85, 0.95, 1.0), Vector3(0, r * 0.55, -r * 1.1)))
		"critter":
			root.add_child(_blob(r, accent, Vector3(0, r * 0.2, 0)))
			var head_y := r * 1.1
			root.add_child(_blob(r * 0.62, accent.lightened(0.12), Vector3(0, head_y, 0)))
			_add_ears(root, accent.lightened(0.12), r, head_y, false)
			var ec := Color(0.12, 0.12, 0.14)
			root.add_child(_blob(r * 0.1, ec, Vector3(-r * 0.2, head_y + r * 0.05, r * 0.5)))
			root.add_child(_blob(r * 0.1, ec, Vector3(r * 0.2, head_y + r * 0.05, r * 0.5)))
		_:
			var cap := CapsuleMesh.new()
			cap.radius = r * 0.6
			cap.height = r * 2.0
			root.add_child(_prim(cap, accent, Vector3(0, r * 0.6, 0)))
	return root

static func _blob(radius: float, color: Color, offset: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
