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
	env.glow_enabled = true
	env.glow_intensity = 0.4
	environment = env
