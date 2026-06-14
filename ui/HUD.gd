extends CanvasLayer
## HUD.gd — in-run heads-up display. Driven ENTIRELY by GameCore signals
## (no polling in _process). Large, high-contrast text for young eyes.

var _root: Control
var _score_label: Label
var _rescue_label: Label
var _lives_label: Label
var _streak_label: Label
var _difficulty_label: Label
var _powerup_row: HBoxContainer

func _ready() -> void:
	var text_color := ThemeManager.color("ui_text", Color.BLACK)

	# Everything lives under one root Control so the whole HUD can be hidden on
	# menus / game-over (a CanvasLayer itself has no `visible`).
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_score_label = _make_label(48, text_color)
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_left = -160
	_score_label.offset_right = 160
	_score_label.offset_top = 24
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.pivot_offset = Vector2(160, 30)   # center for the scale "pop"
	_root.add_child(_score_label)

	_rescue_label = _make_label(28, text_color)
	_rescue_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rescue_label.offset_left = 108   # clear of the pause button at top-left
	_rescue_label.offset_top = 34
	_root.add_child(_rescue_label)

	_lives_label = _make_label(28, text_color)
	_lives_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lives_label.offset_left = -180
	_lives_label.offset_right = -24
	_lives_label.offset_top = 28
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_lives_label)

	# A celebration-only streak badge under the score (hidden at streak 0/1). It
	# never counts down, never gates anything — pure "you're on a roll" flair.
	_streak_label = _make_label(30, ThemeManager.color("accent", Color(1.0, 0.6, 0.3)))
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_streak_label.offset_left = -120
	_streak_label.offset_right = 120
	_streak_label.offset_top = 82
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.pivot_offset = Vector2(120, 18)
	_streak_label.visible = false
	_root.add_child(_streak_label)

	# A small badge so the player can see which difficulty they're playing.
	_difficulty_label = _make_label(20, text_color)
	_difficulty_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_difficulty_label.offset_left = 20
	_difficulty_label.offset_top = -46
	_root.add_child(_difficulty_label)

	# Your current "build" — a row of colored chips, one per active power-up.
	_powerup_row = HBoxContainer.new()
	_powerup_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_powerup_row.offset_left = -110
	_powerup_row.offset_right = 110
	_powerup_row.offset_top = 120
	_powerup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_powerup_row.add_theme_constant_override("separation", 8)
	_root.add_child(_powerup_row)

	# Big, easy pause target (auto-pause on backgrounding is handled in GameCore).
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 28)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_btn.offset_left = 20
	pause_btn.offset_top = 20
	pause_btn.custom_minimum_size = Vector2(72, 72)
	pause_btn.pressed.connect(GameCore.pause)
	_root.add_child(pause_btn)

	GameCore.score_changed.connect(_on_score_changed)
	GameCore.critter_rescued.connect(_on_critter_rescued)
	GameCore.stumbled.connect(_on_stumbled)
	GameCore.run_started.connect(_on_run_started)
	GameCore.run_ended.connect(func(_s, _h): _root.visible = false)
	GameCore.returned_to_menu.connect(func(): _root.visible = false)
	GameCore.new_best.connect(func(): _float_text(tr("New Best!")))
	GameCore.points_popped.connect(_on_points_popped)
	GameCore.streak_changed.connect(_on_streak_changed)
	GameCore.near_miss.connect(func(): _float_text(tr("Whew!")))
	GameCore.milestone_reached.connect(_on_milestone)
	GameCore.critter_unlocked.connect(_on_critter_unlocked)
	Powerups.powerup_changed.connect(_on_powerup_changed)
	GameCore.shield_used.connect(_on_shield_used)
	Biomes.biome_changed.connect(func(_n): _float_text(tr("New area!")))
	Discovery.discovery.connect(_on_discovery)
	GameCore.giant_met.connect(func(): _float_text(tr("A giant friend!")); ScreenFX.confetti(36))

	_root.visible = false   # hidden until a run starts (we open on the Start menu)
	_on_score_changed(GameCore.score)
	_refresh_rescues(0)
	_refresh_lives()

func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _reduce_motion() -> bool:
	return bool(SaveManager.settings.get("reduce_motion", false))

func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)
	if _reduce_motion():
		_score_label.scale = Vector2.ONE
		return
	# Quick scale "pop" so the score feels alive every time it ticks up.
	_score_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_score_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_critter_rescued(_id: String, total: int) -> void:
	_refresh_rescues(total)
	if total > 0:
		_float_text(_streak_word(GameCore.streak))

func _refresh_rescues(total: int) -> void:
	_rescue_label.text = "🐾 %d" % total

const STREAK_WORDS := ["Rescued!", "Nice!", "Great!", "Awesome!", "Amazing!", "Incredible!"]

func _streak_word(streak: int) -> String:
	if streak <= 1:
		return tr(STREAK_WORDS[0])
	return tr(STREAK_WORDS[mini(streak - 1, STREAK_WORDS.size() - 1)])

## A happy word that floats up from the center and fades. Pure positive feedback.
func _float_text(text: String) -> void:
	var size := get_viewport().get_visible_rect().size
	_float_at(text, Vector2(size.x * 0.5, size.y * 0.45), ThemeManager.color("accent", Color(1.0, 0.55, 0.6)), 44, 300)

## A floating label that rises and fades from a screen point. Motion-safe.
func _float_at(text: String, center: Vector2, color: Color, font_size: int = 36, width: float = 140.0) -> void:
	var l := _make_label(font_size, color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	l.position = center - Vector2(width * 0.5, 0)
	_root.add_child(l)
	if _reduce_motion():
		# No sliding motion for motion-sensitive players: hold, fade in place, free.
		var ts := l.create_tween()
		ts.tween_interval(0.6)
		ts.tween_property(l, "modulate:a", 0.0, 0.3)
		ts.tween_callback(l.queue_free)
		return
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 110, 0.85)
	t.tween_property(l, "modulate:a", 0.0, 0.85).set_delay(0.2)
	t.chain().tween_callback(l.queue_free)

## Float a "+N" right where the points were earned (gem/cage world position).
func _on_points_popped(amount: int, world_pos: Vector3) -> void:
	if amount <= 0:
		return
	_float_at("+%d" % amount, _world_to_screen(world_pos),
		ThemeManager.color("accent", Color(1.0, 0.85, 0.4)), 34, 120)

func _world_to_screen(world_pos: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.unproject_position(world_pos)
	var s := get_viewport().get_visible_rect().size
	return Vector2(s.x * 0.5, s.y * 0.45)

## Refresh the "build" chips whenever a power-up turns on or off.
func _on_powerup_changed(_kind: String, _active: bool) -> void:
	for c in _powerup_row.get_children():
		c.free()
	for k in Powerups.KINDS:
		if Powerups.is_active(k):
			var chip := ColorRect.new()
			chip.custom_minimum_size = Vector2(24, 24)
			chip.color = Powerup.color_for(k)
			_powerup_row.add_child(chip)

## A shield absorbed a stumble — celebrate the save (no life lost).
func _on_shield_used() -> void:
	_float_text(tr("Shield!"))

## A surprise discovery event — a flourish + confetti (the "what will happen?" beat).
func _on_discovery(_name: String) -> void:
	_float_text(tr("Surprise!"))
	ScreenFX.confetti(28)

## A rescue milestone (25/50/100…) — a big happy word and a confetti pop. Pure
## celebration; it gates nothing and never nags you to "come back".
func _on_milestone(_kind: String, _value: int) -> void:
	_float_text(tr("Milestone!"))
	ScreenFX.confetti(30)

## Earning a new critter mid-run feels like an event (not a silent Album change).
func _on_critter_unlocked(_id: String) -> void:
	_float_text(tr("New friend!"))
	ScreenFX.confetti(20)

## Show/hide the streak badge. Resets silently to hidden on a stumble (streak 0)
## or a fresh run — no "you lost your streak!" shaming.
func _on_streak_changed(streak: int) -> void:
	if streak < 2:
		_streak_label.visible = false
		return
	_streak_label.text = tr("Streak %d") % streak
	_streak_label.visible = true
	if _reduce_motion():
		_streak_label.scale = Vector2.ONE
		return
	_streak_label.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_streak_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_stumbled(_lives_remaining: int) -> void:
	_refresh_lives()
	# A gentle "oof": a brief, low-alpha screen dim (NO shake, NO strobe) plus a
	# soft floater. Caps come from theme data and ScreenFX clamps the alpha.
	ScreenFX.flash(Color(0.12, 0.10, 0.16),
		float(ThemeManager.get_val("stumble_flash_alpha", 0.18)),
		float(ThemeManager.get_val("stumble_flash_time", 0.25)))
	_float_text(tr("Oops!"))

func _on_run_started() -> void:
	_root.visible = true
	_refresh_rescues(0)
	_refresh_lives()
	_difficulty_label.text = tr("Easy") if ThemeManager.difficulty() == "easy" else tr("Normal")

func _refresh_lives() -> void:
	var max_stumbles := int(ThemeManager.get_val("max_stumbles", 3))
	var left := maxi(max_stumbles - GameCore.stumbles, 0)
	_lives_label.text = "❤".repeat(left)
