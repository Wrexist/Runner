extends WorldEnvironment
## SkyRig — builds the world background + ambient light from the active theme so
## the whole scene reskins for free (forest = soft green, space = deep violet…).
## Also scrolls the ground for a sense of motion (frozen under reduce_motion).

var _ground_mat: StandardMaterial3D
var _ground_scroll: float = 0.0
var _ground_uv_speed: float = 0.04

func _ready() -> void:
	_apply()
	ThemeManager.theme_loaded.connect(func(_id): _apply())

func _apply() -> void:
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = float(ThemeManager.get_val("ambient_energy", 0.7))
	# Flat colour by default (and always under the headless CI renderer, which has
	# no sky/post FX); a richer gradient sky + soft glow with a real renderer.
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeManager.color("background_top", Color(0.5, 0.7, 0.9))
	if DisplayServer.get_name() != "headless":
		env.glow_enabled = true
		env.glow_intensity = float(ThemeManager.get_val("glow_intensity", 0.4))
		# A vertical gradient (top -> horizon) for depth, straight from the palette.
		var psky := ProceduralSkyMaterial.new()
		psky.sky_top_color = ThemeManager.color("background_top", Color(0.5, 0.7, 0.9))
		psky.sky_horizon_color = ThemeManager.color("background_bottom", Color(0.7, 0.8, 0.9))
		psky.ground_horizon_color = ThemeManager.color("background_bottom", Color(0.7, 0.8, 0.9))
		psky.ground_bottom_color = ThemeManager.color("background_bottom", Color(0.5, 0.6, 0.7)).darkened(0.1)
		var sky := Sky.new()
		sky.sky_material = psky
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		# Optional gentle distance fog: far props/cages fade into the horizon for
		# depth (low density — never a soup).
		if bool(ThemeManager.get_val("fog_enabled", false)):
			env.fog_enabled = true
			env.fog_density = float(ThemeManager.get_val("fog_density", 0.01))
			env.fog_light_color = ThemeManager.color("background_bottom", Color(0.7, 0.8, 0.9))
	environment = env
	_apply_ground()
	_apply_light()

## Tune the scene's DirectionalLight from theme data (fail-soft if it's absent).
func _apply_light() -> void:
	var light := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light == null:
		return
	light.light_energy = float(ThemeManager.get_val("light_energy", 1.0))
	var lc := str(ThemeManager.get_val("light_color", ""))
	if lc != "":
		light.light_color = Color(lc)

## Texture the scrolling ground from the theme. With no texture, fall back to a
## procedural stripe (so the floor still reads as MOVING) instead of a flat slab.
func _apply_ground() -> void:
	var ground := get_parent().get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return
	_ground_uv_speed = float(ThemeManager.get_val("ground_uv_speed", 0.04))
	var mat := StandardMaterial3D.new()
	var tex_path := ThemeManager.asset("ground_texture")
	var tex: Resource = ResourceLoader.load(tex_path) if ResourceLoader.exists(tex_path) else null
	if tex is Texture2D:
		mat.albedo_texture = tex
	else:
		# Neutral fallback (not forest-green): a 2-tone stripe so motion is visible.
		mat.albedo_texture = _stripe_texture(
			ThemeManager.color("background_bottom", Color(0.5, 0.52, 0.58)).darkened(0.12))
	mat.uv1_scale = Vector3(6, 60, 1)   # tile across the long ground plane
	ground.material_override = mat
	_ground_mat = mat

## A tiny 2-tone horizontal stripe texture so the ground shows motion with no art.
func _stripe_texture(base: Color) -> ImageTexture:
	var img := Image.create(4, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		var c := base if (y / 2) % 2 == 0 else base.lightened(0.10)
		for x in 4:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Scroll the ground texture toward the player (speeds up with the run; frozen
## under reduce_motion).
func _process(delta: float) -> void:
	if _ground_mat == null or _ground_mat.albedo_texture == null:
		return
	if bool(SaveManager.settings.get("reduce_motion", false)):
		return
	if not GameCore.is_running():
		return
	_ground_scroll += GameCore.current_speed * delta * _ground_uv_speed
	_ground_mat.uv1_offset = Vector3(0.0, _ground_scroll, 0.0)
