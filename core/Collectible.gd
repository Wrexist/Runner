extends Area3D
## Collectible.gd — a gem or a cage (set by `kind`). Both scroll toward the
## player; what happens on contact is the heart of the Rescue Run mechanic:
##   gem  : player picks up its color (sets up a rescue). Small score.
##   cage : if the player's carried color matches -> RESCUE the critter (reward).
##          if it does NOT match -> a gentle "stumble" (the hazard side).
## One object type, two meanings, decided by the player's preparation.
##
## Collision setup (see the .tscn files):
##   Collectibles are on layer 1, mask 2.  The Player's Area3D is on layer 2,
##   mask 1.  So ONLY the player <-> collectible pair detects each other, and we
##   use area_entered (both sides are Area3D, there are no PhysicsBodies here).

@export_enum("gem", "cage") var kind: String = "gem"

var color_name: String = "red"
var lane: int = 0

## Called by the Spawner right after instancing.
func setup(c: String, l: int) -> void:
	color_name = c
	lane = l
	_apply_color()

func _apply_color() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color_from_name(color_name)
	# Cages read as hollow/hazard; gems read as bright/inviting.
	if kind == "cage":
		mat.albedo_color = mat.albedo_color.darkened(0.15)
	mesh.material_override = mat

func _color_from_name(n: String) -> Color:
	match n:
		"red": return Color(0.92, 0.32, 0.32)
		"blue": return Color(0.32, 0.52, 0.92)
		"yellow": return Color(0.95, 0.85, 0.32)
		"green": return Color(0.40, 0.80, 0.45)
		"purple": return Color(0.70, 0.42, 0.86)
		"orange": return Color(0.96, 0.60, 0.26)
		_: return Color.WHITE

func _process(delta: float) -> void:
	if GameCore.state != GameCore.State.PLAYING:
		return
	position.z += GameCore.current_speed * delta
	if position.z > 4.0:        # passed the player; recycle
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group("player"):
		return
	if kind == "gem":
		player.carry_color(color_name)
		GameCore.add_score(1)
		queue_free()
	elif kind == "cage":
		if player.carried_color == color_name:
			player.clear_color()
			GameCore.rescue_critter(_pick_critter_id())
		else:
			GameCore.stumble()   # gentle: costs a life, never a hard game-over
		queue_free()

func _pick_critter_id() -> String:
	var critters: Array = ThemeManager.get_val("rescuable_critters", [])
	if critters.is_empty():
		return "critter"
	return str(critters[randi() % critters.size()].id)
