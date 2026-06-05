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
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label(ThemeManager.display_name(), 56))
		var hi := UIScreens._label("Best: %d" % SaveManager.high_score, 28)
		col.add_child(hi)
		var play := UIScreens._button("Play")
		play.pressed.connect(func(): play_pressed.emit())
		col.add_child(play)
		add_child(col)

static func make_start_screen() -> StartScreen:
	var s := StartScreen.new()
	s._build()
	return s

# ---------------------------------------------------------------- Game over
class GameOver extends Control:
	signal play_again_pressed
	signal shop_pressed
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
		var again := UIScreens._button("Play Again")
		again.pressed.connect(func(): play_again_pressed.emit())
		col.add_child(again)
		var shop := UIScreens._button("Shop")
		shop.pressed.connect(func(): shop_pressed.emit())
		col.add_child(shop)
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
## A simple arithmetic question is the canonical Apple-approved gate.
class ParentalGate extends Control:
	signal passed
	signal cancelled
	var _answer: int = 0
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label("Ask a grown-up", 40))
		# Two-digit-ish sum so it isn't trivially guessable; distractors are
		# distinct, plausible, and never 0 (which would make elimination easy).
		var a := randi_range(4, 9)
		var b := randi_range(4, 9)
		_answer = a + b
		col.add_child(UIScreens._label("What is %d + %d ?" % [a, b], 36))
		var options: Array[int] = [_answer]
		while options.size() < 3:
			var delta := randi_range(1, 4) * (1 if randf() < 0.5 else -1)
			var candidate := _answer + delta
			if candidate > 0 and candidate not in options:
				options.append(candidate)
		options.shuffle()
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		for value in options:
			var btn := UIScreens._button(str(value))
			btn.custom_minimum_size = Vector2(110, 90)
			btn.pressed.connect(_on_answer.bind(value))
			row.add_child(btn)
		col.add_child(row)
		var back := UIScreens._button("Back")
		back.pressed.connect(func(): cancelled.emit())
		col.add_child(back)
		add_child(col)
	func _on_answer(value: int) -> void:
		if value == _answer:
			passed.emit()
		else:
			cancelled.emit()

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
