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
	var col := _color_from_name(color_name)
	# Cages read as hollow/hazard; gems read as bright/inviting.
	if kind == "cage":
		col = col.darkened(0.15)
	# Prefer the theme's gem/cage model (tinted to the color so the match mechanic
	# stays legible); fall back to the placeholder primitive. Fail-soft.
	var model := ThemeModels.instance(ThemeManager.asset("%s_model" % kind))
	if model:
		add_child(model)
		ThemeModels.tint(model, col)
		var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if placeholder:
			placeholder.visible = false
	else:
		var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.material_override = _solid(col)
	_add_symbol_badge()

func _solid(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	return mat

## A white shape floating above the item so the color is also readable as a
## SHAPE (color-blind accessibility — see Shapes.gd).
func _add_symbol_badge() -> void:
	if has_node("SymbolBadge"):
		return
	var badge := MeshInstance3D.new()
	badge.name = "SymbolBadge"
	badge.mesh = Shapes.badge(ThemeManager.gem_symbol(color_name))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.6
	badge.material_override = m
	badge.position = Vector3(0, 0.95, 0)
	add_child(badge)

func _color_from_name(n: String) -> Color:
	return ThemeManager.gem_color(n)

func _process(delta: float) -> void:
	if not GameCore.is_running():
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
		Effects.burst(global_position, _color_from_name(color_name), 8)
		AudioManager.play_sfx("gem_pickup", randf_range(1.0, 1.15))
		queue_free()
	elif kind == "cage":
		if player.carried_color == color_name:
			player.clear_color()
			GameCore.rescue_critter(_pick_critter_id())
			# Bigger, brighter burst the hotter the streak — pure celebration.
			Effects.burst(global_position, _color_from_name(color_name), 16 + mini(GameCore.streak, 8) * 3)
		else:
			GameCore.stumble()   # gentle: costs a life, never a hard game-over
			Effects.burst(global_position, Color(0.6, 0.6, 0.6), 6)
		queue_free()

func _pick_critter_id() -> String:
	var critters: Array = ThemeManager.get_val("rescuable_critters", [])
	if critters.is_empty():
		return "critter"
	return str(critters[randi() % critters.size()].get("id", "critter"))
