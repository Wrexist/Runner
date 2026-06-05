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
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Critter Shop", 48))
		var status := UIScreens._label(_status_text(), 28)
		col.add_child(status)
		var unlock := UIScreens._button("Unlock All Critters  $2.99")
		unlock.disabled = SaveManager.all_unlocked_iap
		unlock.pressed.connect(func():
			SaveManager.set_all_unlocked(true)   # TODO(iap): real purchase
			status.text = _status_text()
			unlock.disabled = true)
		col.add_child(unlock)
		var restore := UIScreens._button("Restore Purchases")
		restore.pressed.connect(func():
			# TODO(iap): query StoreKit for prior non-consumable purchase.
			status.text = _status_text())
		col.add_child(restore)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
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
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Settings", 48))
		col.add_child(_toggle("Music", "music"))
		col.add_child(_toggle("Sounds", "sfx"))
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
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
## One-time, first-run "how to play" card. The core mechanic is conditional
## (a gem changes what a cage means), which is the hardest thing to convey — so
## we show it with big colored shapes, not paragraphs of text.
class Tutorial extends Control:
	signal start_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("How to play", 48))
		col.add_child(UIScreens._label("1.  Grab a gem to carry its color", 28))
		col.add_child(UIScreens._label("2.  Reach the SAME-color cage to rescue a friend!", 28))
		col.add_child(UIScreens._label("Swipe or tap a side to move.", 24))
		var go := UIScreens._button("Let's go!")
		go.pressed.connect(func(): start_pressed.emit())
		col.add_child(go)
		add_child(col)

static func make_tutorial() -> Tutorial:
	var s := Tutorial.new()
	s._build()
	return s
