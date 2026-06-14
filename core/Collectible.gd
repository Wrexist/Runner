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

var _visual: Node3D = null      # the body we spin/bob (model or placeholder mesh)
var _t: float = 0.0
var _bob_phase: float = 0.0
var _reduce: bool = false
var _resolved: bool = false             # pickup/rescue/stumble already happened
var _near_missed: bool = false          # near-miss already celebrated (once)
var _was_threatening: bool = false      # player sat in this cage's lane unprepared
var _forgiveness_z: float = 0.6         # reward pickup/rescue tolerance (themed)
var _near_miss_z: float = 0.8           # dodge-celebration window (themed)
var _player: Node = null
var _pooled: bool = false               # returned to the Spawner pool (inert)

## Called by the Spawner right after instancing (and on every pooled reuse).
func setup(c: String, l: int) -> void:
	color_name = c
	lane = l
	_reduce = bool(SaveManager.settings.get("reduce_motion", false))
	_resolved = false
	_near_missed = false
	_pooled = false
	_was_threatening = false
	_forgiveness_z = float(ThemeManager.get_val("forgiveness_z", 0.6))
	_near_miss_z = float(ThemeManager.get_val("near_miss_z", 0.8))
	_bob_phase = randf() * TAU
	_apply_color()
	# Gentle "pop" as it appears so the track feels lively (motion-safe).
	if not _reduce:
		Effects.pop(self, 1.5)

func _apply_color() -> void:
	var col := _color_from_name(color_name)
	# Cages read as hollow/hazard; gems read as bright/inviting.
	if kind == "cage":
		col = col.darkened(0.15)
	# Prefer the theme's gem/cage model (tinted to the color so the match mechanic
	# stays legible); fall back to the placeholder primitive. Fail-soft.
	# Reuse an already-loaded model on a pooled respawn instead of adding another.
	var model := get_node_or_null("ThemeModel") as Node3D
	if model == null:
		model = ThemeModels.instance(ThemeManager.asset("%s_model" % kind))
		if model:
			model.name = "ThemeModel"
			add_child(model)
	if model:
		ThemeModels.tint(model, col)
		_visual = model
		var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if placeholder:
			placeholder.visible = false
	else:
		var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.material_override = _solid(col)
			_visual = mesh
	_add_symbol_badge()

func _solid(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	# Gems glow (inviting jewels); cages stay matte + darkened (a hazard to read).
	if kind == "gem":
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = float(ThemeManager.get_val("gem_emission", 0.8))
	return mat

## A white shape floating above the item so the color is also readable as a
## SHAPE (color-blind accessibility — see Shapes.gd).
func _add_symbol_badge() -> void:
	var badge := get_node_or_null("SymbolBadge") as MeshInstance3D
	if badge == null:
		badge = MeshInstance3D.new()
		badge.name = "SymbolBadge"
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.6
		badge.material_override = m
		badge.position = Vector3(0, 0.95, 0)
		add_child(badge)
	# Always refresh the shape so a pooled item shows its NEW color's symbol.
	badge.mesh = Shapes.badge(ThemeManager.gem_symbol(color_name))

func _color_from_name(n: String) -> Color:
	return ThemeManager.gem_color(n)

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	position.z += GameCore.current_speed * delta
	# Inviting idle motion on the body only (collision stays put). Gems spin
	# faster than cages; both bob softly. Skipped entirely under Reduce Motion.
	if not _reduce and _visual:
		_t += delta
		_visual.rotation.y += delta * (2.2 if kind == "gem" else 0.7)
		_visual.position.y = sin(_t * 3.0 + _bob_phase) * 0.08
	_check_proximity()
	if position.z > 4.0:        # passed the player; recycle back to the pool
		_despawn()

## Return to the Spawner's pool instead of freeing (latched so it happens once).
## Falls back to queue_free if there's no pooling parent (e.g. a bare test node).
func _despawn() -> void:
	if _pooled:
		return
	_pooled = true
	visible = false
	var sp := get_parent()
	if sp and sp.has_method("release"):
		sp.release(self)
	else:
		queue_free()

func _get_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player

## Forgiveness + near-miss, evaluated as the item nears the player line (z~0):
##   - a REWARD (gem pickup, or a prepared-cage rescue) in the player's lane
##     resolves a hair early/late, so a tiny timing error still counts;
##   - an UNPREPARED cage is NEVER resolved here — the hazard stays fair and is
##     handled precisely by the Area3D overlap;
##   - dodging an unprepared cage you were lined up to hit emits a near_miss.
func _check_proximity() -> void:
	if _resolved or _pooled:
		return
	var player := _get_player()
	if player == null:
		return
	var plane: int = player.current_lane
	# Track the dodge: were we lined up to hit the player (their lane, unprepared)?
	if kind == "cage" and position.z < 0.0 and plane == lane \
			and player.carried_color != color_name:
		_was_threatening = true
	if absf(position.z) > maxf(_forgiveness_z, _near_miss_z):
		return
	if plane == lane:
		if kind == "gem" and absf(position.z) <= _forgiveness_z:
			_resolve(player)
		elif kind == "cage" and player.carried_color == color_name \
				and absf(position.z) <= _forgiveness_z:
			_resolve(player)
	elif kind == "cage" and not _near_missed and _was_threatening \
			and player.carried_color != color_name and absf(position.z) <= _near_miss_z:
		_near_missed = true
		GameCore.near_miss.emit()

func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group("player"):
		return
	_resolve(player)

## The single resolution path (latched so proximity-forgiveness and the Area3D
## overlap can't both fire). Rewards on a match; a gentle stumble on a mismatch.
func _resolve(player: Node) -> void:
	if _resolved or _pooled:
		return
	_resolved = true
	if kind == "gem":
		player.carry_color(color_name)
		GameCore.add_score(1)
		GameCore.points_popped.emit(1, global_position)
		Effects.burst(global_position, _color_from_name(color_name), 8)
		Effects.haptic("light")
		AudioManager.play_sfx("gem_pickup", randf_range(1.0, 1.15))
		_despawn()
	elif kind == "cage":
		if player.carried_color == color_name:
			player.clear_color()
			var before := GameCore.score
			GameCore.rescue_critter(_pick_critter_id())
			GameCore.points_popped.emit(GameCore.score - before, global_position)
			# Bigger, brighter burst the hotter the streak — pure celebration.
			Effects.burst(global_position, _color_from_name(color_name), 16 + mini(GameCore.streak, 8) * 3)
			Effects.haptic("rescue")
		else:
			GameCore.stumble()   # gentle: costs a life, never a hard game-over
			Effects.burst(global_position, Color(0.6, 0.6, 0.6), 6)
		_despawn()

func _pick_critter_id() -> String:
	var critters: Array = ThemeManager.get_val("rescuable_critters", [])
	if critters.is_empty():
		return "critter"
	return str(critters[randi() % critters.size()].get("id", "critter"))
