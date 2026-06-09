extends Node
## Headless logic tests for the core loop. These run with the real autoloads
## (SaveManager / ThemeManager / GameCore / ...) so they catch regressions in the
## rules engine without needing a display. Run in CI:
##   godot --headless --path . res://tests/Tests.tscn
## Exits 0 if all pass, 1 on any failure.

var _failures := 0

func _ready() -> void:
	_run_all()
	if _failures == 0:
		print("TESTS: ALL PASS")
	else:
		printerr("TESTS: %d FAILURE(S)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(test_name: String, cond: bool) -> void:
	if cond:
		print("  ok   ", test_name)
	else:
		_failures += 1
		printerr("  FAIL ", test_name)

func _run_all() -> void:
	_test_theme()
	_test_run_lifecycle()
	_test_pause()
	_test_game_over_and_guards()
	_test_new_best()
	_test_menu_abandon()
	_test_save_unlocks()
	_test_difficulty()
	_test_iap_and_reset()
	_test_about_screen()
	_test_localization()
	_test_loc_coverage()
	_test_theme_schema()
	_test_deterministic_unlocks()
	_test_parental_gate_cooldown()
	_test_language_picker()
	_test_iap_event_handlers()
	_test_theme_models()

func _test_theme() -> void:
	_check("theme loaded (lanes present)", ThemeManager.get_val("lanes", -1) != -1)
	_check("gem_color returns a Color", typeof(ThemeManager.gem_color("red")) == TYPE_COLOR)
	_check("gem_symbol returns non-empty", ThemeManager.gem_symbol("red") != "")

func _test_run_lifecycle() -> void:
	GameCore.start_run()
	_check("start -> PLAYING", GameCore.state == GameCore.State.PLAYING)
	_check("start resets score", GameCore.score == 0)
	_check("start resets streak", GameCore.streak == 0)
	_check("is_running() true", GameCore.is_running())
	GameCore.add_score(5)
	_check("add_score works", GameCore.score == 5)
	var before := GameCore.score
	GameCore.rescue_critter("bunny")
	_check("rescue records critter", GameCore.rescued_this_run.size() == 1)
	_check("rescue sets streak=1", GameCore.streak == 1)
	_check("rescue scores 10+streak bonus", GameCore.score == before + 11)

func _test_pause() -> void:
	GameCore.start_run()
	GameCore.pause()
	_check("paused -> not running", not GameCore.is_running())
	GameCore.resume()
	_check("resumed -> running", GameCore.is_running())

func _test_game_over_and_guards() -> void:
	GameCore.start_run()
	var maxs := int(ThemeManager.get_val("max_stumbles", 3))
	for i in maxs:
		GameCore.stumble()
	_check("max stumbles ends run", GameCore.state == GameCore.State.GAME_OVER)
	_check("stumble cleared streak", GameCore.streak == 0)
	# add_score must be a no-op once the run is over.
	var frozen := GameCore.score
	GameCore.add_score(100)
	_check("score guarded after game over", GameCore.score == frozen)

func _test_new_best() -> void:
	SaveManager.high_score = 5
	var got := {"best": false}
	var cb := func(): got["best"] = true
	GameCore.new_best.connect(cb)
	GameCore.start_run()
	GameCore.add_score(6)            # 6 > previous best of 5
	_check("new_best emitted past old best", got["best"])
	GameCore.new_best.disconnect(cb)

func _test_menu_abandon() -> void:
	GameCore.start_run()
	GameCore.pause()
	GameCore.go_to_menu()
	_check("go_to_menu -> MENU", GameCore.state == GameCore.State.MENU)
	_check("go_to_menu clears paused", not GameCore.paused)

func _test_save_unlocks() -> void:
	SaveManager.unlock_critter("owl")
	_check("unlock recorded", SaveManager.is_unlocked("owl"))
	SaveManager.all_unlocked_iap = true
	_check("IAP unlocks everything", SaveManager.is_unlocked("anything"))
	SaveManager.all_unlocked_iap = false

func _test_difficulty() -> void:
	SaveManager.settings["difficulty"] = "easy"
	var easy_start := float(ThemeManager.diff_val("scroll_speed_start", 99.0))
	var easy_ramp := float(ThemeManager.diff_val("speed_ramp_per_second", 99.0))
	SaveManager.settings["difficulty"] = "normal"
	var normal_start := float(ThemeManager.diff_val("scroll_speed_start", 99.0))
	_check("easy start slower than normal", easy_start < normal_start)
	_check("easy ramp is flat (0)", easy_ramp == 0.0)
	SaveManager.settings["difficulty"] = "easy"   # restore gentle default

func _test_iap_and_reset() -> void:
	SaveManager.all_unlocked_iap = false
	var got := {"ok": false}
	var cb := func(): got["ok"] = true
	IAP.purchase_succeeded.connect(cb)
	IAP.purchase_unlock_all()
	_check("IAP purchase grants unlock", SaveManager.all_unlocked_iap)
	_check("IAP emits purchase_succeeded", got["ok"])
	IAP.purchase_succeeded.disconnect(cb)
	# Reset keeps purchases (must stay restorable) but wipes progress.
	SaveManager.high_score = 123
	SaveManager.lifetime_rescued = 9
	SaveManager.reset_progress()
	_check("reset clears high score", SaveManager.high_score == 0)
	_check("reset clears lifetime stat", SaveManager.lifetime_rescued == 0)
	_check("reset keeps IAP entitlement", SaveManager.all_unlocked_iap)
	SaveManager.all_unlocked_iap = false

## The About screen builds from theme data; verify it constructs without error
## and that the credits formatter handles strings, dicts, and partial dicts.
func _test_about_screen() -> void:
	var about := UIScreens.make_about()
	_check("About screen builds", about != null and about.get_child_count() > 0)
	about.free()
	_check("credit_line passes a string through",
		UIScreens._credit_line("Kenney") == "Kenney")
	_check("credit_line formats a full dict",
		UIScreens._credit_line({"asset": "fox.glb", "author": "Quaternius", "license": "CC0"})
			== "fox.glb — Quaternius  (CC0)")
	_check("credit_line tolerates a partial dict",
		UIScreens._credit_line({"author": "Kenney"}) == "Kenney")

## The translation catalog stays structurally sound: a `keys` header, at least
## one locale column, every row actually translated (no blanks that would import
## as empty strings), and known keys present. Also confirms tr() is identity in
## English so the un-translated build is unchanged.
func _test_localization() -> void:
	var path := "res://localization/ui_strings.csv"
	_check("loc csv exists", FileAccess.file_exists(path))
	var map := _loc_catalog()
	_check("loc has the full string set", map.size() >= 40)
	# A blank cell would import as an empty string and render nothing in-game —
	# check EVERY locale column, not just the first.
	var blanks := 0
	var f2 := FileAccess.open(path, FileAccess.READ)
	var header := f2.get_csv_line(",")
	while not f2.eof_reached():
		var row := f2.get_csv_line(",")
		if row.size() < 2 or row[0] == "":
			continue
		for col in range(1, header.size()):
			if col >= row.size() or row[col].strip_edges() == "":
				blanks += 1
	f2.close()
	_check("loc every row translated in every locale (no blanks)", blanks == 0)
	_check("loc maps a known string (Play->Jugar)", map.get("Play", "") == "Jugar")
	_check("loc includes the gated 'Back'", map.has("Back"))
	# Until a .translation is imported + registered, tr() returns the source.
	_check("tr() is identity in English", tr("Play") == "Play" and tr("Back") == "Back")

## Parse the CSV catalog into {english_source: first_locale_translation}.
func _loc_catalog() -> Dictionary:
	var map := {}
	var f := FileAccess.open("res://localization/ui_strings.csv", FileAccess.READ)
	if f == null:
		return map
	var header := f.get_csv_line(",")  # keys,es,...
	if header.size() < 2 or header[0] != "keys":
		return map
	while not f.eof_reached():
		var row := f.get_csv_line(",")
		if row.size() < 2 or row[0] == "":
			continue
		map[row[0]] = row[1]
	f.close()
	return map

## Coverage guard: every literal tr("...") in the UI must have a catalog row, so
## the catalog can't silently drift behind the code (a string that would render
## fine in English but vanish/stay untranslated in every other locale).
func _test_loc_coverage() -> void:
	var keys := _loc_catalog()
	var re := RegEx.new()
	re.compile("tr\\(\"([^\"]*)\"\\)")
	var missing: Array[String] = []
	for src in ["res://ui/UIScreens.gd", "res://ui/HUD.gd"]:
		var f := FileAccess.open(src, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		for m in re.search_all(text):
			var lit := m.get_string(1)
			if not keys.has(lit) and lit not in missing:
				missing.append(lit)
	_check("every tr(\"...\") literal is in the catalog (%s)" % str(missing), missing.is_empty())

## Schema guard for the reskinnable engine: every theme.json must carry the keys
## core/ reads, so a malformed reskin fails in CI instead of on a child's device.
func _test_theme_schema() -> void:
	var ids := DirAccess.get_directories_at("res://themes")
	_check("themes discovered", ids.size() >= 1)
	for id in ids:
		var path := "res://themes/%s/theme.json" % id
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_check("theme %s opens" % id, false)
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		_check("theme %s is valid JSON object" % id, parsed is Dictionary)
		if not (parsed is Dictionary):
			continue
		var d: Dictionary = parsed
		for key in ["display_name", "lanes", "gem_colors", "max_stumbles",
				"assets", "rescuable_critters", "audio", "palette"]:
			_check("theme %s has '%s'" % [id, key], d.has(key))
		_check("theme %s lanes >= 1" % id, int(d.get("lanes", 0)) >= 1)
		# Palette keys the UI/HUD read.
		var pal: Dictionary = d.get("palette", {})
		for pk in ["background_top", "background_bottom", "accent", "ui_text"]:
			_check("theme %s palette.%s" % [id, pk], pal.has(pk))
		# Asset + audio slots the engine wires up.
		var assets: Dictionary = d.get("assets", {})
		for ak in ["player_model", "gem_model", "cage_model", "ground_texture"]:
			_check("theme %s assets.%s" % [id, ak], str(assets.get(ak, "")).begins_with("res://"))
		var aud: Dictionary = d.get("audio", {})
		for au in ["music", "rescue", "gem_pickup", "miss"]:
			_check("theme %s audio.%s" % [id, au], str(aud.get(au, "")).begins_with("res://"))
		# Gem colors non-empty AND each maps to a DISTINCT color-blind symbol.
		var colors: Array = d.get("gem_colors", [])
		_check("theme %s has gem colors" % id, colors.size() >= 1)
		ThemeManager.load_theme(id)
		var symbols := {}
		for c in colors:
			symbols[ThemeManager.gem_symbol(str(c))] = true
		_check("theme %s gem symbols are distinct (color-blind safe)" % id,
			symbols.size() == colors.size())
		# Critters: well-formed, with at least one always-available starter.
		var critters: Array = d.get("rescuable_critters", [])
		_check("theme %s has critters" % id, critters.size() >= 1)
		var has_starter := false
		var critters_ok := true
		for c in critters:
			if not (c is Dictionary) or str(c.get("id", "")) == "" \
					or not str(c.get("model", "")).begins_with("res://"):
				critters_ok = false
			if int((c as Dictionary).get("unlock_score", -1)) == 0:
				has_starter = true
		_check("theme %s critters well-formed {id, model}" % id, critters_ok)
		_check("theme %s has a free starter critter (unlock_score 0)" % id, has_starter)
	# Leave the default theme active for any later tests / a clean exit.
	ThemeManager.load_theme("forest")

## Fix #1: reaching a score threshold unlocks EVERY critter at/under it,
## regardless of which critter the rescue randomly surfaced.
func _test_deterministic_unlocks() -> void:
	ThemeManager.load_theme("forest")  # bunny:0, hedgehog:50, owl:150, deer:300
	SaveManager.unlocked_critters = []
	SaveManager.all_unlocked_iap = false
	GameCore.start_run()
	GameCore.add_score(300)
	# Rescue surfaces "bunny", but score 300 should unlock the high-threshold ones.
	GameCore.rescue_critter("bunny")
	_check("unlock: rescued critter unlocked", SaveManager.is_unlocked("bunny"))
	_check("unlock: deer (300) unlocked despite rescuing bunny", SaveManager.is_unlocked("deer"))
	_check("unlock: owl (150) unlocked too", SaveManager.is_unlocked("owl"))
	# A critter above the current score stays locked.
	SaveManager.unlocked_critters = []
	GameCore.start_run()
	GameCore.add_score(50)
	GameCore.rescue_critter("bunny")
	_check("unlock: deer stays locked below threshold", not SaveManager.is_unlocked("deer"))
	SaveManager.unlocked_critters = []
	GameCore.go_to_menu()

## Fix #2: a wrong parental-gate answer locks the buttons (anti brute-force) and
## does not pass; a correct answer passes.
func _test_parental_gate_cooldown() -> void:
	var gate := UIScreens.make_parental_gate()
	add_child(gate)  # in-tree so the cooldown timer can be created
	var got := {"passed": false}
	gate.passed.connect(func(): got["passed"] = true)
	var wrong := -1
	var right := -1
	for i in gate._buttons.size():
		if int(gate._buttons[i].get_meta("value")) == gate._answer:
			right = i
		else:
			wrong = i
	gate._on_pick(wrong)
	_check("gate: wrong answer does not pass", not got["passed"])
	_check("gate: wrong answer disables the buttons", gate._buttons[0].disabled)
	gate._on_pick(right)
	_check("gate: correct answer passes", got["passed"])
	gate.free()

## The Settings language picker is self-hiding: with only the English source
## loaded (CI has no imported .translation), there's no second locale to pick, so
## the button is absent — no dead UI in the shipped English-only build.
func _test_language_picker() -> void:
	var s := UIScreens.make_settings()
	add_child(s)
	_check("lang: 'en' source always available", "en" in s._available_locales())
	_check("lang: english-only build hides the picker", s._available_locales().size() == 1)
	s.free()

## The real StoreKit path can't run in CI (no native plugin), so drive IAP's
## event handlers directly with synthetic events to cover purchase/restore/price.
func _test_iap_event_handlers() -> void:
	# product_info → localized price surfaces on the Shop button.
	IAP._localized_price = ""
	IAP._on_product_info({"type": "product_info", "result": "ok",
		"ids": [IAP.PRODUCT_ID], "localized_prices": ["£1.99"]})
	_check("IAP: product_info sets localized price", IAP.price_text() == "£1.99")
	# Successful purchase → grant + purchase_succeeded.
	SaveManager.all_unlocked_iap = false
	var ok := {"v": false}
	var ok_cb := func(): ok["v"] = true
	IAP.purchase_succeeded.connect(ok_cb)
	IAP._on_purchase({"type": "purchase", "result": "ok", "product_id": IAP.PRODUCT_ID})
	_check("IAP: purchase event grants unlock", SaveManager.all_unlocked_iap)
	_check("IAP: purchase event emits succeeded", ok["v"])
	IAP.purchase_succeeded.disconnect(ok_cb)
	# Failed purchase → reason reported, no grant.
	SaveManager.all_unlocked_iap = false
	var failed := {"reason": ""}
	var fail_cb := func(r): failed["reason"] = r
	IAP.purchase_failed.connect(fail_cb)
	IAP._on_purchase({"type": "purchase", "result": "error",
		"product_id": IAP.PRODUCT_ID, "error": "declined"})
	_check("IAP: failed purchase does not grant", not SaveManager.all_unlocked_iap)
	_check("IAP: failed purchase reports the reason", failed["reason"] == "declined")
	IAP.purchase_failed.disconnect(fail_cb)
	# Restore finding our product → grant + restore_completed(true).
	SaveManager.all_unlocked_iap = false
	var restored := {"v": false}
	var rcb := func(u): restored["v"] = u
	IAP.restore_completed.connect(rcb)
	IAP._on_restore({"type": "restore", "product_id": IAP.PRODUCT_ID})
	_check("IAP: restore event grants unlock", SaveManager.all_unlocked_iap)
	_check("IAP: restore emits completed(true)", restored["v"] == true)
	IAP.restore_completed.disconnect(rcb)
	# Tidy up so later tests / a clean exit aren't affected.
	IAP._localized_price = ""
	SaveManager.all_unlocked_iap = false

## The fail-soft theme model loader: missing paths degrade to procedural visuals
## (so the game looks good with zero art), and critters get distinct stable colors.
func _test_theme_models() -> void:
	_check("models: empty path → null", ThemeModels.instance("") == null)
	_check("models: absent path → null (fail-soft)",
		ThemeModels.instance("res://themes/forest/models/__nope__.glb") == null)
	# Distinct, deterministic per-critter colors.
	_check("models: critter_color is a Color", ThemeModels.critter_color("bunny") is Color)
	_check("models: critter_color is deterministic",
		ThemeModels.critter_color("owl") == ThemeModels.critter_color("owl"))
	_check("models: different critters → different colors",
		ThemeModels.critter_color("bunny") != ThemeModels.critter_color("deer"))
	# With no model file, a procedural placeholder critter is built (not null).
	var v := ThemeModels.critter_visual({"id": "bunny"})
	_check("models: critter_visual falls back to a Node3D", v is Node3D and v.get_child_count() > 0)
	v.free()
