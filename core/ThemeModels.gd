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

## The visual for a rescued critter: its real model if present, else a cute
## two-blob procedural placeholder colored by `critter_color`.
static func critter_visual(critter: Dictionary, body_radius: float = 0.28) -> Node3D:
	var model := instance(str(critter.get("model", "")))
	if model:
		return model
	var id := str(critter.get("id", "critter"))
	var col := critter_color(id)
	var root := Node3D.new()
	root.add_child(_blob(body_radius, col, Vector3.ZERO))
	# A smaller, lighter "head" gives a friendly silhouette instead of a plain ball.
	root.add_child(_blob(body_radius * 0.6, col.lightened(0.18),
		Vector3(0, body_radius * 0.85, 0)))
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
