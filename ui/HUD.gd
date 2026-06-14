extends CanvasLayer
## HUD.gd — in-run heads-up display. Driven ENTIRELY by GameCore signals
## (no polling in _process). Large, high-contrast text for young eyes.

var _root: Control
var _score_label: Label
var _rescue_label: Label
var _lives_label: Label

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

	_root.visible = false   # hidden until a run starts (we open on the Start menu)
	_on_score_changed(GameCore.score)
	_refresh_rescues(0)
	_refresh_lives()

func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)
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
	var l := _make_label(44, ThemeManager.color("accent", Color(1.0, 0.55, 0.6)))
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var size := get_viewport().get_visible_rect().size
	l.position = Vector2(size.x * 0.5 - 150, size.y * 0.45)
	l.custom_minimum_size = Vector2(300, 0)
	_root.add_child(l)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 130, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.2)
	t.chain().tween_callback(l.queue_free)

func _on_stumbled(_lives_remaining: int) -> void:
	_refresh_lives()

func _on_run_started() -> void:
	_root.visible = true
	_refresh_rescues(0)
	_refresh_lives()

func _refresh_lives() -> void:
	var max_stumbles := int(ThemeManager.get_val("max_stumbles", 3))
	var left := maxi(max_stumbles - GameCore.stumbles, 0)
	_lives_label.text = "❤".repeat(left)
