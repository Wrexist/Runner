extends RefCounted
class_name UIScreens
## UIScreens.gd — factory for every front-end screen, built in code from the
## active theme so screens reskin for free. Used by UIManager. Each screen is a
## small inner Control class that emits intent signals; UIManager wires them.

# ---------------------------------------------------------------- shared helpers
static func _bg() -> ColorRect:
	var r := ColorRect.new()
	r.color = ThemeManager.color("background_bottom", Color(0.12, 0.12, 0.16))
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ThemeManager.color("ui_text", Color.BLACK))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 76)
	b.add_theme_font_size_override("font_size", 28)
	return b

static func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	return v

# ---------------------------------------------------------------- Start screen
class StartScreen extends Control:
	signal play_pressed
	signal settings_pressed
	signal album_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label(ThemeManager.display_name(), 56))
		col.add_child(UIScreens._label("Best: %d" % SaveManager.high_score, 28))
		if SaveManager.lifetime_rescued > 0:
			col.add_child(UIScreens._label("Friends rescued: %d" % SaveManager.lifetime_rescued, 22))
		var play := UIScreens._button("Play")
		play.pressed.connect(func(): play_pressed.emit())
		col.add_child(play)
		var album := UIScreens._button("My Critters")
		album.pressed.connect(func(): album_pressed.emit())
		col.add_child(album)
		var settings := UIScreens._button("Settings")
		settings.pressed.connect(func(): settings_pressed.emit())
		col.add_child(settings)
		add_child(col)

static func make_start_screen() -> StartScreen:
	var s := StartScreen.new()
	s._build()
	return s

# ---------------------------------------------------------------- Game over
class GameOver extends Control:
	signal play_again_pressed
	signal album_pressed
	var _score: int = 0
	var _is_high: bool = false
	var _rescued: int = 0
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Run Over", 52))
		if _is_high:
			col.add_child(UIScreens._label("New Best!", 34))
		col.add_child(UIScreens._label("Score: %d" % _score, 36))
		col.add_child(UIScreens._label("Critters rescued: %d" % _rescued, 28))
		# Lead with the positive next action. Monetization is NOT placed at the
		# loss moment — the Shop lives behind the calm "My Critters" album.
		var again := UIScreens._button("Play Again")
		again.pressed.connect(func(): play_again_pressed.emit())
		col.add_child(again)
		var album := UIScreens._button("My Critters")
		album.pressed.connect(func(): album_pressed.emit())
		col.add_child(album)
		add_child(col)

static func make_game_over(score: int, is_high: bool, rescued: int) -> GameOver:
	var s := GameOver.new()
	s._score = score
	s._is_high = is_high
	s._rescued = rescued
	s._build()
	return s

# ---------------------------------------------------------------- Parental gate
## COMPLIANCE: must appear before the Shop / any purchase or external link.
## Arithmetic gate. A wrong tap re-rolls the question in place (with a gentle
## "Try again") rather than ejecting — only "Back" cancels. This is friendlier
## for a parent who mis-taps and harder for a child to brute-force.
class ParentalGate extends Control:
	signal passed
	signal cancelled
	var _answer: int = 0
	var _prompt: Label
	var _feedback: Label
	var _buttons: Array[Button] = []
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Ask a grown-up", 40))
		_prompt = UIScreens._label("", 36)
		col.add_child(_prompt)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		for i in 3:
			var btn := UIScreens._button("")
			btn.custom_minimum_size = Vector2(110, 90)
			btn.pressed.connect(_on_pick.bind(i))
			_buttons.append(btn)
			row.add_child(btn)
		col.add_child(row)
		_feedback = UIScreens._label("", 24)
		col.add_child(_feedback)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): cancelled.emit())
		col.add_child(back)
		add_child(col)
		_new_question()
	func _new_question() -> void:
		var a := randi_range(4, 9)
		var b := randi_range(4, 9)
		_answer = a + b
		_prompt.text = "What is %d + %d ?" % [a, b]
		# Distinct, positive, plausible distractors (never 0).
		var options: Array[int] = [_answer]
		while options.size() < 3:
			var delta := randi_range(1, 4) * (1 if randf() < 0.5 else -1)
			var candidate := _answer + delta
			if candidate > 0 and candidate not in options:
				options.append(candidate)
		options.shuffle()
		for i in _buttons.size():
			_buttons[i].text = str(options[i])
			_buttons[i].set_meta("value", options[i])
	func _on_pick(i: int) -> void:
		if int(_buttons[i].get_meta("value")) == _answer:
			passed.emit()
		else:
			_feedback.text = "Try again"
			_new_question()

static func make_parental_gate() -> ParentalGate:
	var s := ParentalGate.new()
	s._build()
	return s

# ---------------------------------------------------------------- Shop
## Single non-consumable "unlock all". No currency, no packs, no randomization.
## TODO(iap): replace the stubbed unlock with the Godot iOS IAP plugin call.
class Shop extends Control:
	signal closed
	var _status: Label
	var _unlock: Button
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Critter Shop", 48))
		_status = UIScreens._label(_status_text(), 28)
		col.add_child(_status)
		_unlock = UIScreens._button("Unlock All Critters  %s" % IAP.price_text())
		_unlock.disabled = SaveManager.all_unlocked_iap
		_unlock.pressed.connect(func(): IAP.purchase_unlock_all())
		col.add_child(_unlock)
		var restore := UIScreens._button("Restore Purchases")
		restore.pressed.connect(func(): IAP.restore())
		col.add_child(restore)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
		# React to the purchase/restore results (real plugin or stub alike).
		IAP.purchase_succeeded.connect(_refresh)
		IAP.restore_completed.connect(func(_u): _refresh())
		IAP.purchase_failed.connect(func(reason): _status.text = "Purchase failed: %s" % reason)
	func _refresh() -> void:
		_status.text = _status_text()
		_unlock.disabled = SaveManager.all_unlocked_iap
	func _status_text() -> String:
		return "All critters unlocked!" if SaveManager.all_unlocked_iap else "Unlock every critter forever."

static func make_shop() -> Shop:
	var s := Shop.new()
	s._build()
	return s

# ---------------------------------------------------------------- Pause
class Pause extends Control:
	signal resume_pressed
	signal settings_pressed
	signal home_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Paused", 52))
		var resume := UIScreens._button("Resume")
		resume.pressed.connect(func(): resume_pressed.emit())
		col.add_child(resume)
		var settings := UIScreens._button("Settings")
		settings.pressed.connect(func(): settings_pressed.emit())
		col.add_child(settings)
		var home := UIScreens._button("Home")
		home.pressed.connect(func(): home_pressed.emit())
		col.add_child(home)
		add_child(col)

static func make_pause() -> Pause:
	var s := Pause.new()
	s._build()
	return s

# ---------------------------------------------------------------- Settings
## Toggles for music + sound effects. The plumbing (SaveManager.settings +
## AudioManager honoring it) already existed; this is the missing screen.
class Settings extends Control:
	signal closed
	signal reset_requested
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Settings", 48))
		col.add_child(_toggle("Music", "music"))
		col.add_child(_toggle("Sounds", "sfx"))
		col.add_child(_toggle("Reduce motion", "reduce_motion"))
		col.add_child(_difficulty_button())
		var reset := UIScreens._button("Reset Progress")
		reset.pressed.connect(func(): reset_requested.emit())
		col.add_child(reset)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
	func _difficulty_button() -> Button:
		var b := UIScreens._button("")
		_refresh_difficulty(b)
		b.pressed.connect(func():
			var now := str(SaveManager.settings.get("difficulty", "easy"))
			SaveManager.settings["difficulty"] = "normal" if now == "easy" else "easy"
			SaveManager.save_game()
			_refresh_difficulty(b))
		return b
	func _refresh_difficulty(b: Button) -> void:
		var d := str(SaveManager.settings.get("difficulty", "easy"))
		b.text = "Difficulty:  %s" % ("Easy" if d == "easy" else "Normal")
	func _toggle(label: String, key: String) -> Button:
		var b := UIScreens._button("")
		_refresh(b, label, key)
		b.pressed.connect(_on_toggle.bind(b, label, key))
		return b
	func _on_toggle(b: Button, label: String, key: String) -> void:
		SaveManager.settings[key] = not bool(SaveManager.settings.get(key, true))
		SaveManager.save_game()
		_refresh(b, label, key)
		if key == "music":
			if bool(SaveManager.settings["music"]):
				AudioManager.play_music()
			else:
				AudioManager.stop_music()
	func _refresh(b: Button, label: String, key: String) -> void:
		var on := bool(SaveManager.settings.get(key, true))
		b.text = "%s:  %s" % [label, "On" if on else "Off"]

static func make_settings() -> Settings:
	var s := Settings.new()
	s._build()
	return s

# ---------------------------------------------------------------- Critter album
## The payoff for unlocks (earned-by-score or the IAP): a grid of friends you've
## rescued, with locked ones shown as "?" and the score that reveals them. This
## is the compliant, healthy replay driver (collect them) — no compulsion loop.
class Album extends Control:
	signal closed
	signal unlock_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("My Critters", 48))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 28)
		grid.add_theme_constant_override("v_separation", 16)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for c in ThemeManager.get_val("rescuable_critters", []):
			grid.add_child(_cell(c))
		col.add_child(grid)
		# Calm, contextual place to offer the single unlock-all purchase (gated).
		if not SaveManager.all_unlocked_iap:
			var unlock := UIScreens._button("Unlock All Critters")
			unlock.pressed.connect(func(): unlock_pressed.emit())
			col.add_child(unlock)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
	func _cell(c: Dictionary) -> Control:
		var id := str(c.get("id", "?"))
		var unlocked := SaveManager.is_unlocked(id)
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(220, 120)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(80, 80)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		swatch.color = ThemeManager.color("accent", Color(1, 0.55, 0.6)) if unlocked else Color(0.4, 0.4, 0.45)
		box.add_child(swatch)
		var name_label := UIScreens._label(id.capitalize() if unlocked else "?", 26)
		box.add_child(name_label)
		var hint := UIScreens._label("Rescued!" if unlocked else "Reach %d" % int(c.get("unlock_score", 0)), 18)
		box.add_child(hint)
		return box

static func make_album() -> Album:
	var s := Album.new()
	s._build()
	return s

# ---------------------------------------------------------------- Tutorial
## A small 2D shape drawn from a color+symbol, so the tutorial reads for a
## pre-reader (and reinforces the color-blind shape language). `filled` = a gem;
## hollow = an empty cage of the same color/shape.
class Glyph2D extends Control:
	var symbol: String = "sphere"
	var col: Color = Color.WHITE
	var filled: bool = true
	func _init(p_symbol: String = "sphere", p_col: Color = Color.WHITE, p_filled: bool = true) -> void:
		symbol = p_symbol
		col = p_col
		filled = p_filled
		custom_minimum_size = Vector2(96, 96)
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		_shape(c, r, col)
		if not filled:
			# Punch a hole so it reads as an empty cage, not a gem.
			_shape(c, r * 0.5, ThemeManager.color("background_bottom", Color.BLACK))
	func _shape(c: Vector2, r: float, color: Color) -> void:
		match symbol:
			"box", "cylinder", "capsule":
				draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), color)
			"prism":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r)]), color)
			_:
				draw_circle(c, r, color)

## One-time, first-run "how to play" card. The core mechanic is conditional
## (a gem changes what a cage means), the hardest thing to convey — so we SHOW
## it: gem -> same-color cage = a rescued friend, using the theme's real colors.
class Tutorial extends Control:
	signal start_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("How to play", 48))
		var colors: Array = ThemeManager.get_val("gem_colors", ["red"])
		var c0 := str(colors[0]) if colors.size() > 0 else "red"
		var gc := ThemeManager.gem_color(c0)
		var sym := ThemeManager.gem_symbol(c0)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		row.add_child(UIScreens.Glyph2D.new(sym, gc, true))             # gem
		row.add_child(UIScreens._label("→", 40))
		row.add_child(UIScreens.Glyph2D.new(sym, gc, false))            # matching cage
		row.add_child(UIScreens._label("=", 40))
		row.add_child(UIScreens.Glyph2D.new("sphere", ThemeManager.color("accent", Color(1, 0.55, 0.6)), true))
		col.add_child(row)
		col.add_child(UIScreens._label("Grab the gem, reach the matching cage!", 26))
		var go := UIScreens._button("Let's go!")
		go.pressed.connect(func(): start_pressed.emit())
		col.add_child(go)
		add_child(col)

static func make_tutorial() -> Tutorial:
	var s := Tutorial.new()
	s._build()
	return s
