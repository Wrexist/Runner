extends RefCounted
class_name UIScreens
## UIScreens.gd — factory for every front-end screen, built in code from the
## active theme so screens reskin for free. Used by UIManager. Each screen is a
## small inner Control class that emits intent signals; UIManager wires them.
##
## Localization: user-facing strings are wrapped in tr() so they translate via
## the catalog in res://localization/ (see docs/LOCALIZATION.md). Until a
## translation is loaded, tr() returns the English source unchanged — so the
## game reads identically in English with zero behavior change. Inner screen
## classes extend Control (a Node), so tr() resolves on the screen instance.

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
	signal about_pressed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label(ThemeManager.display_name(), 56))
		col.add_child(UIScreens._label(tr("Best: %d") % SaveManager.high_score, 28))
		if SaveManager.lifetime_rescued > 0:
			col.add_child(UIScreens._label(tr("Friends rescued: %d") % SaveManager.lifetime_rescued, 22))
		var play := UIScreens._button(tr("Play"))
		play.pressed.connect(func(): play_pressed.emit())
		col.add_child(play)
		var album := UIScreens._button(tr("My Critters"))
		album.pressed.connect(func(): album_pressed.emit())
		col.add_child(album)
		var settings := UIScreens._button(tr("Settings"))
		settings.pressed.connect(func(): settings_pressed.emit())
		col.add_child(settings)
		var about := UIScreens._button(tr("About"))
		about.pressed.connect(func(): about_pressed.emit())
		col.add_child(about)
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
		col.add_child(UIScreens._label(tr("Run Over"), 52))
		if _is_high:
			col.add_child(UIScreens._label(tr("New Best!"), 34))
		col.add_child(UIScreens._label(tr("Score: %d") % _score, 36))
		col.add_child(UIScreens._label(tr("Critters rescued: %d") % _rescued, 28))
		# Lead with the positive next action. Monetization is NOT placed at the
		# loss moment — the Shop lives behind the calm "My Critters" album.
		var again := UIScreens._button(tr("Play Again"))
		again.pressed.connect(func(): play_again_pressed.emit())
		col.add_child(again)
		var album := UIScreens._button(tr("My Critters"))
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
	const WRONG_COOLDOWN := 1.5   # seconds the answers stay disabled after a miss
	var _answer: int = 0
	var _prompt: Label
	var _feedback: Label
	var _buttons: Array[Button] = []
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label(tr("Ask a grown-up"), 40))
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
		var back := UIScreens._button(tr("Back"))
		back.pressed.connect(func(): cancelled.emit())
		col.add_child(back)
		add_child(col)
		_new_question()
	func _new_question() -> void:
		var a := randi_range(4, 9)
		var b := randi_range(4, 9)
		_answer = a + b
		_prompt.text = tr("What is %d + %d ?") % [a, b]
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
			# Briefly lock the answers so the gate can't be brute-forced by a
			# child rapidly tapping every option.
			_feedback.text = tr("Try again")
			_set_answers_enabled(false)
			get_tree().create_timer(WRONG_COOLDOWN).timeout.connect(_after_cooldown)
	func _after_cooldown() -> void:
		_set_answers_enabled(true)
		_new_question()
	func _set_answers_enabled(on: bool) -> void:
		for b in _buttons:
			b.disabled = not on

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
		col.add_child(UIScreens._label(tr("Critter Shop"), 48))
		_status = UIScreens._label(_status_text(), 28)
		col.add_child(_status)
		_unlock = UIScreens._button(tr("Unlock All Critters  %s") % IAP.price_text())
		_unlock.disabled = SaveManager.all_unlocked_iap
		_unlock.pressed.connect(func(): IAP.purchase_unlock_all())
		col.add_child(_unlock)
		var restore := UIScreens._button(tr("Restore Purchases"))
		restore.pressed.connect(func(): IAP.restore())
		col.add_child(restore)
		var back := UIScreens._button(tr("Back"))
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)
		# React to the purchase/restore results (real plugin or stub alike).
		IAP.purchase_succeeded.connect(_refresh)
		IAP.restore_completed.connect(func(_u): _refresh())
		IAP.purchase_failed.connect(func(reason): _status.text = tr("Purchase failed: %s") % reason)
	func _refresh() -> void:
		_status.text = _status_text()
		_unlock.disabled = SaveManager.all_unlocked_iap
	func _status_text() -> String:
		return tr("All critters unlocked!") if SaveManager.all_unlocked_iap else tr("Unlock every critter forever.")

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
		col.add_child(UIScreens._label(tr("Paused"), 52))
		var resume := UIScreens._button(tr("Resume"))
		resume.pressed.connect(func(): resume_pressed.emit())
		col.add_child(resume)
		var settings := UIScreens._button(tr("Settings"))
		settings.pressed.connect(func(): settings_pressed.emit())
		col.add_child(settings)
		var home := UIScreens._button(tr("Home"))
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
		col.add_child(UIScreens._label(tr("Settings"), 48))
		col.add_child(_toggle("Music", "music"))
		col.add_child(_toggle("Sounds", "sfx"))
		col.add_child(_toggle("Reduce motion", "reduce_motion"))
		col.add_child(_difficulty_button())
		# Language picker only appears once a second locale has been imported
		# (see docs/LOCALIZATION.md) — no dead UI in the English-only build.
		var langs := _available_locales()
		if langs.size() > 1:
			col.add_child(_language_button(langs))
		var reset := UIScreens._button(tr("Reset Progress"))
		reset.pressed.connect(func(): reset_requested.emit())
		col.add_child(reset)
		var back := UIScreens._button(tr("Back"))
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
		b.text = tr("Difficulty:  %s") % (tr("Easy") if d == "easy" else tr("Normal"))
	## English source ("en") plus any imported locales the engine has loaded.
	func _available_locales() -> Array:
		var out: Array = ["en"]
		for l in TranslationServer.get_loaded_locales():
			var code := str(l)
			if code != "" and code not in out:
				out.append(code)
		return out
	func _language_button(langs: Array) -> Button:
		var b := UIScreens._button("")
		_refresh_language(b)
		b.pressed.connect(func():
			var cur := str(TranslationServer.get_locale())
			var idx := langs.find(cur)
			if idx == -1:                                  # tolerate "es_ES" vs "es"
				for i in langs.size():
					if cur.begins_with(str(langs[i])):
						idx = i
						break
			var next: String = str(langs[(idx + 1) % langs.size()])
			TranslationServer.set_locale(next)
			SaveManager.settings["locale"] = next
			SaveManager.save_game()
			_relayout())                                   # re-translate every label
		return b
	func _refresh_language(b: Button) -> void:
		var code := str(TranslationServer.get_locale())
		var lname := TranslationServer.get_locale_name(code)
		b.text = tr("Language:  %s") % (lname if lname != "" else code.to_upper())
	func _relayout() -> void:
		for c in get_children():
			remove_child(c)
			c.free()
		_build()
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
		b.text = "%s:  %s" % [tr(label), tr("On") if on else tr("Off")]

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
		col.add_child(UIScreens._label(tr("My Critters"), 48))
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
			var unlock := UIScreens._button(tr("Unlock All Critters"))
			unlock.pressed.connect(func(): unlock_pressed.emit())
			col.add_child(unlock)
		var back := UIScreens._button(tr("Back"))
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
		var hint := UIScreens._label((tr("Rescued!") if unlocked else tr("Reach %d") % int(c.get("unlock_score", 0))), 18)
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
		col.add_child(UIScreens._label(tr("How to play"), 48))
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
		col.add_child(UIScreens._label(tr("Grab the gem, reach the matching cage!"), 26))
		var go := UIScreens._button(tr("Let's go!"))
		go.pressed.connect(func(): start_pressed.emit())
		col.add_child(go)
		add_child(col)

static func make_tutorial() -> Tutorial:
	var s := Tutorial.new()
	s._build()
	return s

# ---------------------------------------------------------------- About / Credits
## Reachable from Start. Two jobs: (1) reassure parents — this app collects no
## data, has no ads, no tracking (a truthful Kids-Category selling point), and
## (2) credit third-party assets. Credits are DATA: each theme may list its asset
## authors under an optional `credits` array in theme.json, so a reskin carries
## its own attribution. Any CC-BY asset MUST appear here; CC0 is welcome too.
class About extends Control:
	signal closed
	func _build() -> void:
		add_child(UIScreens._bg())
		var col := UIScreens._column()
		col.add_child(UIScreens._label(tr("About"), 48))
		col.add_child(UIScreens._label("%s  v%s" % [
			ThemeManager.display_name(),
			str(ProjectSettings.get_setting("application/config/version", "1.0"))], 26))
		# Privacy promise, in plain words. Mirrors the real behavior: SaveManager
		# is local-only and there are no SDKs/network calls.
		col.add_child(UIScreens._label(tr("No ads. No tracking."), 24))
		col.add_child(UIScreens._label(tr("We never collect your data."), 24))
		# A plain-language privacy summary, surfaced in-app (no outbound link).
		col.add_child(UIScreens._label(tr("No accounts, no internet — nothing leaves this device."), 18))
		col.add_child(UIScreens._label(tr("Made with Godot Engine (MIT)"), 20))
		var credits: Array = ThemeManager.get_val("credits", [])
		if not credits.is_empty():
			col.add_child(UIScreens._label(tr("Art & sound"), 26))
			# Scroll so a long credits list stays usable on a small phone screen.
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(360, 220)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var list := VBoxContainer.new()
			list.add_theme_constant_override("separation", 8)
			for entry in credits:
				list.add_child(UIScreens._label(UIScreens._credit_line(entry), 18))
			scroll.add_child(list)
			col.add_child(scroll)
		var back := UIScreens._button(tr("Back"))
		back.pressed.connect(func(): closed.emit())
		col.add_child(back)
		add_child(col)

## Format one credits entry. Accepts a plain string, or a dict with any of
## {asset/name, author/by, license, source/url} — all fields optional.
static func _credit_line(entry: Variant) -> String:
	if entry is String:
		return entry
	if entry is Dictionary:
		var what := str(entry.get("asset", entry.get("name", "")))
		var who := str(entry.get("author", entry.get("by", "")))
		var lic := str(entry.get("license", ""))
		var line := what
		if who != "":
			line += (" — " if line != "" else "") + who
		if lic != "":
			line += "  (%s)" % lic
		return line if line != "" else "—"
	return str(entry)

static func make_about() -> About:
	var s := About.new()
	s._build()
	return s
