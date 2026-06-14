extends Node
## ScreenFX (autoload) — gentle SCREEN-SPACE juice: a soft full-screen flash, a
## brief edge vignette, and a confetti burst. Kept deliberately gentle for a kids'
## app: low alpha, short, NO strobe, NO harsh shake. Everything is suppressed
## under reduce_motion. Lives on its own CanvasLayer that sits above the in-3D HUD
## but below UIManager's menus, so menus always cover it.

const LAYER := 5                 # HUD is in the 3D scene; UIManager menus are at 10
const MAX_FLASH_ALPHA := 0.35    # hard cap so a flash is never blinding

var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)

func _reduce() -> bool:
	return bool(SaveManager.settings.get("reduce_motion", false))

func _viewport_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp else Vector2(720, 1280)

## A soft full-screen colour wash that fades out. `alpha` is clamped to a gentle
## cap; `time` is the fade. No strobe — one short, low wash.
func flash(color: Color, alpha: float = 0.2, time: float = 0.25) -> void:
	if _reduce():
		return
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, MAX_FLASH_ALPHA))
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	var t := r.create_tween()
	t.tween_property(r, "modulate:a", 0.0, maxf(time, 0.05))
	t.tween_callback(r.queue_free)

## A brief darkened edge vignette (a gentle "oof" with NO shake), from a radial
## gradient texture so it stays cheap on the mobile renderer.
func vignette(color: Color, time: float = 0.3) -> void:
	if _reduce():
		return
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))   # clear center
	g.set_color(1, Color(color.r, color.g, color.b, 0.45))  # darker edges
	var grad := GradientTexture2D.new()
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(tr)
	var t := tr.create_tween()
	t.tween_property(tr, "modulate:a", 0.0, maxf(time, 0.05))
	t.tween_callback(tr.queue_free)

## A celebratory 2D confetti burst from the upper area. Themed accent colour,
## gentle gravity, one-shot.
func confetti(count: int = 24) -> void:
	if _reduce():
		return
	var size := _viewport_size()
	var p := CPUParticles2D.new()
	p.amount = clampi(count, 1, 64)
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.2
	p.position = Vector2(size.x * 0.5, size.y * 0.25)
	p.direction = Vector2(0, 1)
	p.spread = 180.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = ThemeManager.color("accent", Color(1, 0.7, 0.5))
	_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
