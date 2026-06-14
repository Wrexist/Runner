extends WorldEnvironment
## SkyRig — builds the world background + ambient light from the active theme so
## the whole scene reskins for free (forest = soft green, space = deep violet…).

func _ready() -> void:
	_apply()
	ThemeManager.theme_loaded.connect(func(_id): _apply())

func _apply() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeManager.color("background_top", Color(0.5, 0.7, 0.9))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	# A touch of soft glow makes the bright gems pop without harshness.
	# (Skip under the headless dummy renderer used in CI — it has no post FX.)
	if DisplayServer.get_name() != "headless":
		env.glow_enabled = true
		env.glow_intensity = float(ThemeManager.get_val("glow_intensity", 0.4))
	environment = env
	_apply_ground()

## Texture the scrolling ground from the theme. With no texture, fall back to a
## soft themed color so the floor never looks like a stark white slab. Fail-soft.
func _apply_ground() -> void:
	var ground := get_parent().get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return
	var mat := StandardMaterial3D.new()
	var tex_path := ThemeManager.asset("ground_texture")
	var tex: Resource = ResourceLoader.load(tex_path) if ResourceLoader.exists(tex_path) else null
	if tex is Texture2D:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(6, 60, 1)   # tile across the long ground plane
	else:
		# Neutral fallback (not forest-green) so a theme missing the key degrades
		# sensibly rather than picking up a forest bias.
		mat.albedo_color = ThemeManager.color("background_bottom", Color(0.5, 0.52, 0.58)).darkened(0.12)
	ground.material_override = mat
