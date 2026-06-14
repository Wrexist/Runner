extends Area3D
class_name Powerup
## Powerup.gd — a free, glowing power-up pickup that scrolls toward the player.
## On touch it grants ONE gentle build effect (shield/slow/magnet/double) with a
## celebratory pop. Never bought, never a paid/loot/random-paid reward — pure
## positive help (Kids/COPPA-safe). Collision mirrors the gem (layer 1 / mask 2).

var _kind := "shield"

func setup(kind: String) -> void:
	_kind = kind
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var c := color_for(_kind)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c.lightened(0.2)
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 1.3
		mesh.material_override = mat

## Each build effect reads as a distinct colour (also used by the HUD chips).
static func color_for(kind: String) -> Color:
	match kind:
		"shield": return Color(0.4, 0.8, 1.0)
		"slow": return Color(0.72, 0.6, 1.0)
		"magnet": return Color(1.0, 0.5, 0.6)
		"double": return Color(1.0, 0.85, 0.3)
		"rainbow": return Color(0.95, 0.5, 0.9)
		"dash": return Color(0.3, 1.0, 0.9)
		_: return Color.WHITE

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	position.z += GameCore.scroll_speed() * delta
	if not bool(SaveManager.settings.get("reduce_motion", false)):
		rotation.y += delta * 1.8
		position.y = 1.0 + sin(GameCore.elapsed * 3.0) * 0.12
	if position.z > 4.0:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group("player"):
		return
	Powerups.activate(_kind, float(ThemeManager.get_val("powerup_duration", 6.0)))
	Effects.burst(global_position, color_for(_kind), 18)
	Effects.haptic("rescue")
	AudioManager.play_sfx("powerup")
	queue_free()
