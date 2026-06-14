extends Node
## Headless logic tests for the core loop. These run with the real autoloads
## (SaveManager / ThemeManager / GameCore / ...) so they catch regressions in the
## rules engine without needing a display. Run in CI:
##   godot --headless --path . res://tests/Tests.tscn
## Exits 0 if all pass, 1 on any failure.

var _failures := 0
var _near_miss_count := 0   # scratch counter for the near-miss test

## Optional tunables added by the polish overhaul. They have code-side defaults
## (so they're NOT in the strict required-key block), but must stay in PARITY:
## present in every theme.json or none. Each feature commit appends its key here.
## Dotted paths (e.g. "audio.menu_music") are supported.
const EXTENDED_KEYS: Array[String] = [
	# W-A game feel & input
	"swipe_threshold_px", "tap_dead_zone_frac", "lane_change_cooldown",
	"carry_glow", "carry_badge_scale", "haptic_ms",
	# W-B difficulty & pacing
	"warmup_seconds", "spawn_patterns", "forgiveness_z", "near_miss_z",
	# W-C feedback & juice
	"stumble_flash_alpha", "stumble_flash_time", "milestone_rescues",
	# W-E audio (fail-soft keys)
	"audio.menu_music", "audio.ui_click", "audio.whoosh",
	"audio.near_miss", "audio.jingle",
	# W-F procedural visuals
	"gem_emission", "glow_intensity", "ground_uv_speed",
	"camera_follow", "camera_smooth", "camera_zoom_amount",
	# W-G procedural scenery & characters
	"critter_detail", "player_shape", "scenery", "ambient",
	"fog_enabled", "fog_density", "ambient_energy", "light_energy", "light_color",
	"lane_marker",
	# Adventure depth: gentle power-up "builds"
	"slow_factor", "powerup_interval", "powerup_duration", "audio.powerup",
	# Adventure depth: in-run biome journey + discovery
	"biome_interval", "discovery_interval",
	# Adventure depth: jump & slide
	"jump_height", "jump_seconds", "slide_seconds", "obstacle_interval",
]

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
	_test_theme_schema_extended()
	_test_deterministic_unlocks()
	_test_parental_gate_cooldown()
	_test_language_picker()
	_test_iap_event_handlers()
	_test_theme_models()
	_test_hud_reduce_motion()
	_test_wav_loop_math()
	_test_player_lean_no_stack()
	_test_celebration_signals()
	_test_run_stats()
	_test_end_run_records_stats()
	_test_player_input_tunables()
	_test_input_buffer()
	_test_carry_indicator()
	_test_haptics()
	_test_settings_autosave()
	_test_speed_warmup()
	_test_spawn_patterns()
	_test_forgiveness_and_near_miss()
	_test_pool_reuse()
	_test_screenfx()
	_test_points_popped()
	_test_streak_counter()
	_test_stumble_feedback_gentle()
	_test_celebration_feedback()
	_test_audio_handlers()
	_test_button_roles()
	_test_settings_toggle_switch()
	_test_game_over_stats()
	_test_master_volume()
	_test_collectible_silhouette()
	_test_camera_reads_theme()
	_test_ground_scroll()
	_test_critter_variety()
	_test_player_visual()
	_test_scenery()
	_test_scenery_styles()
	_test_ambient()
	_test_atmosphere()
	_test_lane_markers()
	_test_powerups()
	_test_powerup_spawn()
	_test_powerup_hud()
	_test_magnet()
	_test_biomes()
	_test_jump_slide()
	_test_obstacle()
	_test_discovery()
	_test_state_restored()

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

## Parity guard for the optional overhaul tunables (see EXTENDED_KEYS): each key
## must be present in EVERY theme or NONE, so a reskin never silently misses one.
func _test_theme_schema_extended() -> void:
	var ids := DirAccess.get_directories_at("res://themes")
	for key in EXTENDED_KEYS:
		var present := 0
		for id in ids:
			if _theme_has_path(_load_theme_json(id), key):
				present += 1
		_check("extended key '%s' in all themes or none (parity)" % key,
			present == 0 or present == ids.size())

func _load_theme_json(id: String) -> Dictionary:
	var f := FileAccess.open("res://themes/%s/theme.json" % id, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

## True if a (possibly dotted) key path exists in the theme dict.
func _theme_has_path(d: Dictionary, path: String) -> bool:
	var cur: Variant = d
	for p in path.split("."):
		if not (cur is Dictionary) or not (cur as Dictionary).has(p):
			return false
		cur = (cur as Dictionary)[p]
	return true

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

## Accessibility: with reduce_motion on, the HUD must not animate (no score-pop
## scale, no sliding floaters) — it still shows the text, just without movement.
func _test_hud_reduce_motion() -> void:
	var prev: bool = bool(SaveManager.settings.get("reduce_motion", false))
	SaveManager.settings["reduce_motion"] = true
	var hud = preload("res://ui/HUD.gd").new()   # untyped for dynamic member access
	add_child(hud)   # triggers _ready: builds labels + connects signals
	hud._on_score_changed(7)
	_check("hud: score pop suppressed under reduce_motion", hud._score_label.scale == Vector2.ONE)
	var before: int = hud._root.get_child_count()
	hud._float_text("Nice!")
	_check("hud: floater still appears under reduce_motion (static)",
		hud._root.get_child_count() == before + 1)
	hud.free()
	SaveManager.settings["reduce_motion"] = prev

## The placeholder WAV loop point must follow bit depth AND channel count, not
## assume 16-bit mono (which silently mis-loops stereo / 8-bit clips).
func _test_wav_loop_math() -> void:
	var w := AudioStreamWAV.new()
	var bytes := PackedByteArray()
	bytes.resize(8)
	w.data = bytes
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = false
	_check("wav: 16-bit mono loop_end = bytes/2", AudioManager._wav_loop_end(w) == 4)
	w.stereo = true
	_check("wav: 16-bit stereo loop_end = bytes/4", AudioManager._wav_loop_end(w) == 2)
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.stereo = false
	_check("wav: 8-bit mono loop_end = bytes/1", AudioManager._wav_loop_end(w) == 8)

## Rapid lane changes must not stack overlapping lean tweens (which fight over
## rotation:z); starting a new lean kills the previous one.
func _test_player_lean_no_stack() -> void:
	var prev: bool = bool(SaveManager.settings.get("reduce_motion", false))
	SaveManager.settings["reduce_motion"] = false
	var p = preload("res://scenes/Player.tscn").instantiate()   # untyped for dynamic access
	add_child(p)
	p._lane_cooldown_time = 0.0   # isolate the lean-stack check from the lane cooldown
	p.move_lane(1)
	var first: Tween = p._lean_tween
	p.move_lane(-1)
	# NOTE: in Godot 4.3 kill() leaves is_valid()==true but stops the tween, so the
	# "killed" check is is_running()==false (not is_valid()).
	_check("lean: previous tween stopped on a new lean", first == null or not first.is_running())
	_check("lean: a fresh lean tween is now running",
		p._lean_tween != null and p._lean_tween.is_running())
	p.free()
	SaveManager.settings["reduce_motion"] = prev

## Celebration signals: a rescue that crosses score gates emits critter_unlocked
## once per newly-earned critter (not for owned ones), and rescue milestones emit
## milestone_reached at the data-driven counts.
func _test_celebration_signals() -> void:
	ThemeManager.load_theme("forest")   # bunny:0, hedgehog:50, owl:150, deer:300
	SaveManager.unlocked_critters = []
	SaveManager.all_unlocked_iap = false
	var got := {"unlocked": [], "milestone": 0}
	var ucb := func(id): got["unlocked"].append(id)
	var mcb := func(kind, value):
		if kind == "rescues":
			got["milestone"] = value
	GameCore.critter_unlocked.connect(ucb)
	GameCore.milestone_reached.connect(mcb)
	GameCore.start_run()
	GameCore.add_score(50)
	GameCore.rescue_critter("bunny")    # score now >=50: earns bunny + hedgehog
	_check("signal: critter_unlocked fires for newly-earned critters",
		"hedgehog" in got["unlocked"] and "bunny" in got["unlocked"])
	var owned: int = got["unlocked"].size()
	GameCore.rescue_critter("bunny")    # already owned → no refire
	_check("signal: critter_unlocked does not refire for owned critters",
		got["unlocked"].size() == owned)
	# Milestone fires at the data-driven rescue counts (default 25/50/100).
	GameCore.start_run()
	for i in 25:
		GameCore.rescue_critter("bunny")
	_check("signal: milestone_reached at 25 rescues", got["milestone"] == 25)
	GameCore.critter_unlocked.disconnect(ucb)
	GameCore.milestone_reached.disconnect(mcb)
	SaveManager.unlocked_critters = []
	GameCore.go_to_menu()

## Personal-best stats only ever rise, survive a reset only via the IAP/settings
## carve-out, and new settings keys migrate in with defaults.
func _test_run_stats() -> void:
	SaveManager.best_streak = 0
	SaveManager.most_rescues_in_run = 0
	SaveManager.longest_run_seconds = 0.0
	SaveManager.record_run_stats(5, 12, 30.0)
	_check("stats: record sets bests", SaveManager.best_streak == 5
		and SaveManager.most_rescues_in_run == 12
		and is_equal_approx(SaveManager.longest_run_seconds, 30.0))
	SaveManager.record_run_stats(3, 8, 20.0)   # a worse run must not lower bests
	_check("stats: record only raises bests",
		SaveManager.best_streak == 5 and SaveManager.most_rescues_in_run == 12)
	_check("stats: haptics setting present by default", SaveManager.settings.has("haptics"))
	_check("stats: master_volume setting present by default", SaveManager.settings.has("master_volume"))
	# reset wipes stats but keeps settings + the IAP entitlement.
	SaveManager.all_unlocked_iap = true
	SaveManager.reset_progress()
	_check("stats: reset zeroes best_streak", SaveManager.best_streak == 0)
	_check("stats: reset keeps IAP entitlement", SaveManager.all_unlocked_iap)
	_check("stats: reset keeps settings (haptics)", SaveManager.settings.has("haptics"))
	SaveManager.all_unlocked_iap = false

func _test_end_run_records_stats() -> void:
	SaveManager.best_streak = 0
	SaveManager.most_rescues_in_run = 0
	GameCore.start_run()
	GameCore.rescue_critter("bunny")
	GameCore.rescue_critter("bunny")
	GameCore.rescue_critter("bunny")   # streak peaks at 3
	var maxs := int(ThemeManager.get_val("max_stumbles", 3))
	for i in maxs:
		GameCore.stumble()             # ends the run
	_check("stats: end_run records most_rescues_in_run", SaveManager.most_rescues_in_run >= 3)
	_check("stats: end_run records best_streak", SaveManager.best_streak >= 3)
	GameCore.go_to_menu()

## Input tunables come from theme data, not hardcoded constants.
func _test_player_input_tunables() -> void:
	ThemeManager.load_theme("forest")
	var p = preload("res://scenes/Player.tscn").instantiate()
	add_child(p)
	_check("input: swipe threshold read from theme",
		p._swipe_threshold == float(ThemeManager.get_val("swipe_threshold_px", 40.0)))
	_check("input: tap dead-zone read from theme",
		p._tap_dead_zone_frac == float(ThemeManager.get_val("tap_dead_zone_frac", 0.12)))
	p.free()

## A lane change during the cooldown is buffered (one step), then released when
## the cooldown expires — never dropped, and never more than a single queued step.
func _test_input_buffer() -> void:
	var p = preload("res://scenes/Player.tscn").instantiate()
	add_child(p)
	p._lane_cooldown_time = 0.1   # force a cooldown window for the test
	p.current_lane = 0
	p._target_x = p._lane_to_x(0)
	p._lane_cooldown = 0.0
	p._buffered_dir = 0
	p.move_lane(1)
	_check("buffer: first move applies immediately", p.current_lane == 1)
	_check("buffer: cooldown started", p._lane_cooldown > 0.0)
	p.move_lane(1)                 # within cooldown → buffered, not applied yet
	_check("buffer: move during cooldown is held", p.current_lane == 1 and p._buffered_dir == 1)
	p.move_lane(1)                 # buffer holds only the latest single step
	_check("buffer: only one step queued", p._buffered_dir == 1)
	p._tick_cooldown(0.2)          # expire the cooldown → release the buffered step
	_check("buffer: buffered step released after cooldown", p.current_lane == 2)
	_check("buffer: buffer cleared after release", p._buffered_dir == 0)
	p.free()

## The carried-color badge appears (shaped + glowing) while carrying and hides
## when cleared — the visible signal of the core Rescue Run decision.
func _test_carry_indicator() -> void:
	ThemeManager.load_theme("forest")
	var p = preload("res://scenes/Player.tscn").instantiate()
	add_child(p)
	p.carry_color("red")
	var badge = p.get_node_or_null("CarryBadge")
	_check("carry: badge appears when carrying", badge != null and badge.visible)
	_check("carry: badge has a shape mesh", badge != null and badge.mesh != null)
	p.clear_color()
	_check("carry: badge hidden when not carrying", badge != null and not badge.visible)
	p.free()

## Haptics are opt-out, suppressed under reduce_motion, and a safe no-op off
## mobile (so CI/desktop never throw), and the Settings screen exposes the toggle.
func _test_haptics() -> void:
	SaveManager.settings["haptics"] = true
	SaveManager.settings["reduce_motion"] = false
	Effects.haptic("light")     # off-mobile: must be a silent no-op, never throw
	Effects.haptic("rescue")
	SaveManager.settings["haptics"] = false
	Effects.haptic("light")
	SaveManager.settings["haptics"] = true
	_check("haptics: Effects.haptic is a safe no-op headless", true)
	var s := UIScreens.make_settings()
	add_child(s)
	_check("haptics: Settings exposes a Haptics toggle", _find_text_descendant(s, tr("Haptics")))
	s.free()

## Every setting change funnels through set_setting(), which writes to disk
## immediately — so a toggle survives a reload.
func _test_settings_autosave() -> void:
	var prev: bool = bool(SaveManager.settings.get("sfx", true))
	SaveManager.set_setting("sfx", false)
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	_check("autosave: save file written by set_setting", f != null)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		var saved: Dictionary = (parsed.get("settings", {}) if parsed is Dictionary else {})
		_check("autosave: set_setting persisted the change", saved.get("sfx", true) == false)
	SaveManager.set_setting("sfx", prev)

## The speed curve holds at the starting speed during the warm-up grace, then
## ramps (on normal) toward — but never past — the cap. Easy stays flat throughout.
func _test_speed_warmup() -> void:
	SaveManager.settings["difficulty"] = "normal"
	ThemeManager.load_theme("forest")
	var start := float(ThemeManager.diff_val("scroll_speed_start", 8.0))
	var smax := float(ThemeManager.diff_val("scroll_speed_max", 18.0))
	var warmup := float(ThemeManager.diff_val("warmup_seconds", 2.5))
	GameCore.start_run()
	GameCore._process(warmup * 0.5)              # still inside warm-up
	_check("speed: held at start during warm-up", is_equal_approx(GameCore.current_speed, start))
	GameCore._process(warmup)                    # cross the warm-up boundary
	GameCore._process(1.0)
	_check("speed: ramps up after warm-up (normal)", GameCore.current_speed > start)
	for i in 2000:
		GameCore._process(0.1)                   # plenty of time to hit the cap
	_check("speed: never exceeds the cap", GameCore.current_speed <= smax)
	# Easy: flat ramp means flat speed even long past warm-up.
	SaveManager.settings["difficulty"] = "easy"
	ThemeManager.load_theme("forest")
	var estart := float(ThemeManager.diff_val("scroll_speed_start", 8.0))
	GameCore.start_run()
	GameCore._process(10.0)
	_check("speed: easy stays flat past warm-up", is_equal_approx(GameCore.current_speed, estart))
	GameCore.go_to_menu()
	SaveManager.settings["difficulty"] = "easy"   # restore gentle default

## The spawn-pattern system never walls the track (>=1 lane always clear, even
## for an over-eager pattern), falls back to single pairs with no data, and can
## select a "rest" beat.
func _test_spawn_patterns() -> void:
	var sp = preload("res://core/Spawner.gd").new()
	add_child(sp)
	sp.lanes_count = 3
	sp._last_lane = -1
	for count in [2, 3, 5]:        # even a greedy request can't occupy every lane
		for i in 25:
			var lanes = sp._choose_lanes(count)
			_check("spawn: leaves >=1 lane clear (req %d)" % count,
				lanes.size() >= 1 and lanes.size() <= sp.lanes_count - 1)
			var uniq := {}
			for l in lanes:
				uniq[l] = true
			_check("spawn: chosen lanes distinct (req %d)" % count, uniq.size() == lanes.size())
	sp.patterns = []
	_check("spawn: empty table falls back to single", sp._next_pattern().get("type", "") == "single")
	sp.patterns = [{"type": "rest", "weight": 1}]
	_check("spawn: rest pattern selectable", sp._next_pattern().get("type", "") == "rest")
	sp._realize_pattern({"type": "rest"})   # an empty beat must not throw
	sp.free()

func _count_near_miss() -> void:
	_near_miss_count += 1

## Final hygiene: leave the engine in its canonical default state so nothing
## leaks between the suite and a real launch (forest theme, gentle difficulty).
func _test_state_restored() -> void:
	ThemeManager.load_theme("forest")
	SaveManager.settings["difficulty"] = "easy"
	SaveManager.settings["reduce_motion"] = false
	SaveManager.all_unlocked_iap = false
	SaveManager.unlocked_critters = []
	GameCore.go_to_menu()
	_check("state: default theme is forest", ThemeManager.active_theme == "forest")
	_check("state: difficulty restored to gentle default", ThemeManager.difficulty() == "easy")
	_check("state: not mid-run after the suite", not GameCore.is_running())

## Screen-space juice is fully suppressed under reduce_motion and otherwise mounts
## a self-freeing overlay (and never throws headless).
func _test_screenfx() -> void:
	SaveManager.settings["reduce_motion"] = true
	var before := ScreenFX._layer.get_child_count()
	ScreenFX.flash(Color.WHITE, 0.2, 0.2)
	ScreenFX.vignette(Color.BLACK, 0.2)
	ScreenFX.confetti(10)
	_check("screenfx: reduce_motion suppresses all effects",
		ScreenFX._layer.get_child_count() == before)
	SaveManager.settings["reduce_motion"] = false
	ScreenFX.flash(Color.WHITE, 0.9, 0.2)   # over-cap alpha is clamped internally
	_check("screenfx: flash mounts an overlay when motion is on",
		ScreenFX._layer.get_child_count() > before)

## A "+N" floater appears where points were earned; non-positive amounts don't.
func _test_points_popped() -> void:
	var hud = preload("res://ui/HUD.gd").new()
	add_child(hud)
	var before: int = hud._root.get_child_count()
	hud._on_points_popped(7, Vector3.ZERO)
	_check("popups: +N floater mounts", hud._root.get_child_count() == before + 1)
	hud._on_points_popped(0, Vector3.ZERO)
	_check("popups: non-positive amount does not float", hud._root.get_child_count() == before + 1)
	hud.free()

## The streak badge shows from streak 2 and hides at 0/1 (silent reset, no shame).
func _test_streak_counter() -> void:
	var hud = preload("res://ui/HUD.gd").new()
	add_child(hud)
	hud._on_streak_changed(3)
	_check("streak: badge visible at streak>=2",
		hud._streak_label.visible and "3" in hud._streak_label.text)
	hud._on_streak_changed(1)
	_check("streak: badge hidden at streak 1", not hud._streak_label.visible)
	hud._on_streak_changed(0)
	_check("streak: badge hidden at streak 0", not hud._streak_label.visible)
	hud.free()

## Stumble feedback stays gentle: the flash alpha is capped low in EVERY theme,
## and a near-miss shows a floater without touching the score.
func _test_stumble_feedback_gentle() -> void:
	for id in DirAccess.get_directories_at("res://themes"):
		var a := float(_load_theme_json(id).get("stumble_flash_alpha", 0.18))
		_check("stumble: %s flash alpha is gentle (<=0.25)" % id, a <= 0.25)
	var hud = preload("res://ui/HUD.gd").new()
	add_child(hud)
	var before_score := GameCore.score
	var before: int = hud._root.get_child_count()
	GameCore.near_miss.emit()
	_check("near-miss: a floater appears", hud._root.get_child_count() == before + 1)
	_check("near-miss: score is unchanged", GameCore.score == before_score)
	hud.free()

## Milestone + unlock celebrations each mount a floater (confetti is separate).
func _test_celebration_feedback() -> void:
	var hud = preload("res://ui/HUD.gd").new()
	add_child(hud)
	var before: int = hud._root.get_child_count()
	hud._on_milestone("rescues", 25)
	_check("milestone: celebration floater shown", hud._root.get_child_count() == before + 1)
	hud._on_critter_unlocked("bunny")
	_check("unlock: celebration floater shown", hud._root.get_child_count() == before + 2)
	hud.free()

## All audio entry points are fail-soft: missing files stay silent, never throw.
func _test_audio_handlers() -> void:
	AudioManager.play_menu_music()
	AudioManager.play_music()
	AudioManager.play_sfx("whoosh")
	AudioManager.play_sfx("near_miss")
	AudioManager.play_sfx("jingle")
	AudioManager.play_sfx("ui_click")
	AudioManager.set_paused(true)
	AudioManager.set_paused(false)
	_check("audio: all handlers are fail-soft (no crash)", true)

## Button roles drive emphasis; the default role preserves the original size.
func _test_button_roles() -> void:
	var primary := UIScreens._button("X", "primary")
	var back := UIScreens._button("X", "back")
	var default := UIScreens._button("X")
	_check("buttons: primary taller than back",
		primary.custom_minimum_size.y > back.custom_minimum_size.y)
	_check("buttons: default preserves 280x76", default.custom_minimum_size == Vector2(280, 76))
	primary.free()
	back.free()
	default.free()

## The collectible pool reuses freed nodes (no unbounded growth) and a recycled
## node is fully re-initialized to its new color on reuse.
func _test_pool_reuse() -> void:
	ThemeManager.load_theme("forest")
	var sp = preload("res://core/Spawner.gd").new()
	sp.gem_scene = preload("res://scenes/Gem.tscn")
	sp.cage_scene = preload("res://scenes/Cage.tscn")
	add_child(sp)
	sp.lanes_count = 3
	sp._spawn_one("gem", 0.0, -40.0, "red", 1)
	var count_after_first := sp.get_child_count()
	var gem_a = sp.get_child(count_after_first - 1)
	for c in sp.get_children():
		sp.release(c)               # back to the pool, not freed
	sp._spawn_one("gem", 0.0, -40.0, "blue", 0)
	_check("pool: reuse does not grow the node count", sp.get_child_count() == count_after_first)
	var gem_b = sp.get_child(sp.get_child_count() - 1)
	_check("pool: the same instance is reused", gem_a == gem_b)
	_check("pool: reused node re-initialized to new color", gem_b.color_name == "blue")
	_check("pool: reused node is active again",
		gem_b.visible and gem_b.is_in_group("collectible"))
	sp.free()

## Rewards are forgiving (a gem in the player's lane within the window is picked
## up even without a perfect overlap); the hazard stays fair; and dodging an
## unprepared cage you were lined up to hit emits a near_miss.
func _test_forgiveness_and_near_miss() -> void:
	ThemeManager.load_theme("forest")
	SaveManager.settings["reduce_motion"] = true   # quiet pops/particles in the test
	GameCore.start_run()
	var player = preload("res://scenes/Player.tscn").instantiate()
	add_child(player)        # joins group "player" (from the scene)
	var gem = preload("res://core/Collectible.gd").new()
	gem.kind = "gem"
	add_child(gem)
	gem.setup("red", player.current_lane)
	gem.position.z = 0.3     # inside forgiveness_z, player already in the lane
	gem._check_proximity()
	_check("forgiveness: in-lane gem within window is picked up", player.carried_color == "red")
	_near_miss_count = 0
	GameCore.near_miss.connect(_count_near_miss)
	var cage = preload("res://core/Collectible.gd").new()
	cage.kind = "cage"
	add_child(cage)
	cage.setup("blue", 1)
	player.clear_color()         # unprepared for a blue cage
	player.current_lane = 1      # lined up to hit it
	cage.position.z = -3.0
	cage._check_proximity()      # registers the threat
	player.current_lane = 0      # dodge out of the lane
	cage.position.z = 0.2        # now passing the player line
	cage._check_proximity()
	_check("near-miss: dodging a lined-up unprepared cage emits near_miss", _near_miss_count == 1)
	# An unprepared cage is NOT resolved by forgiveness (hazard stays fair).
	_check("forgiveness: unprepared cage not auto-resolved off-lane", not cage._resolved)
	GameCore.near_miss.disconnect(_count_near_miss)
	cage.free()
	player.free()
	GameCore.go_to_menu()
	SaveManager.settings["reduce_motion"] = false

## Settings toggles are real CheckButton switches now, and flipping one persists.
func _test_settings_toggle_switch() -> void:
	var s := UIScreens.make_settings()
	add_child(s)
	var cb := _find_checkbutton(s, tr("Music"))
	_check("settings: Music is a CheckButton switch", cb != null)
	if cb:
		var prev: bool = bool(SaveManager.settings.get("music", true))
		cb.toggled.emit(not prev)
		_check("settings: flipping the switch persists",
			bool(SaveManager.settings.get("music", true)) == (not prev))
		SaveManager.set_setting("music", prev)
	s.free()

## Game Over shows personal-best stats AND — crucially for compliance — never a
## purchase/Shop button at the loss moment.
func _test_game_over_stats() -> void:
	SaveManager.best_streak = 7
	var go := UIScreens.make_game_over(120, true, 9)
	add_child(go)
	_check("gameover: shows best streak", _find_text_descendant(go, "7"))
	_check("gameover: NO purchase/Shop at the loss moment",
		not _find_text_descendant(go, tr("Unlock All Critters"))
		and not _find_text_descendant(go, tr("Critter Shop")))
	go.free()

## The ground scrolls during play and freezes under reduce_motion.
func _test_ground_scroll() -> void:
	ThemeManager.load_theme("forest")
	var root := Node3D.new()
	add_child(root)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = PlaneMesh.new()
	root.add_child(ground)
	var sky = preload("res://core/SkyRig.gd").new()
	root.add_child(sky)             # _ready builds the env + ground material
	GameCore.start_run()
	SaveManager.settings["reduce_motion"] = true
	sky._ground_scroll = 0.0
	sky._process(0.2)
	_check("ground: no scroll under reduce_motion", sky._ground_scroll == 0.0)
	SaveManager.settings["reduce_motion"] = false
	sky._process(0.2)
	_check("ground: scrolls during play", sky._ground_scroll > 0.0)
	GameCore.go_to_menu()
	root.free()

## The camera pulls follow/smooth/zoom from theme data, not hardcoded exports.
func _test_camera_reads_theme() -> void:
	ThemeManager.load_theme("space")
	var cam = preload("res://core/CameraRig.gd").new()
	add_child(cam)
	_check("camera: follow read from theme",
		is_equal_approx(cam.follow_amount, float(ThemeManager.get_val("camera_follow", 0.4))))
	_check("camera: zoom amount read from theme",
		is_equal_approx(cam._zoom_amount, float(ThemeManager.get_val("camera_zoom_amount", 0.0))))
	cam.free()
	ThemeManager.load_theme("forest")

## Procedural critters are deterministic per id, richer than the legacy blob, and
## varied across ids; "simple" detail falls back to the gentle two-blob.
func _test_critter_variety() -> void:
	ThemeManager.load_theme("forest")
	var a := ThemeModels._build_creature("bunny", 0.28)
	var b := ThemeModels._build_creature("bunny", 0.28)
	_check("critter: same id -> same structure", a.get_child_count() == b.get_child_count())
	_check("critter: full creature richer than a blob", a.get_child_count() > 3)
	var counts := {}
	for id in ["bunny", "hedgehog", "owl", "deer", "clownfish", "robo"]:
		var c := ThemeModels._build_creature(id, 0.28)
		counts[c.get_child_count()] = true
		c.free()
	_check("critter: ids produce varied silhouettes", counts.size() >= 2)
	var s := ThemeModels._simple_creature("bunny", 0.28)
	_check("critter: simple detail is the two-blob", s.get_child_count() == 2)
	var v := ThemeModels.critter_visual({"id": "owl"})
	_check("critter: critter_visual returns a populated Node3D",
		v is Node3D and v.get_child_count() > 0)
	a.free()
	b.free()
	s.free()
	v.free()

## Side scenery never enters the play lanes, reuses its pool, and freezes the
## scroll under reduce_motion (static dressing stays).
func _test_scenery() -> void:
	ThemeManager.load_theme("forest")
	var sc = preload("res://core/Scenery.gd").new()
	add_child(sc)               # _ready populates a static spread
	var outside := true
	for p in sc._live:
		if absf(p.position.x) < sc._play_half:
			outside = false
	_check("scenery: every prop is outside the play lanes", outside and sc._live.size() > 0)
	var count1 := sc.get_child_count()
	sc._repopulate()
	_check("scenery: repopulate reuses the pool (no node growth)", sc.get_child_count() == count1)
	_check("scenery: respects the max_props cap", sc._live.size() <= sc._max_props)
	GameCore.start_run()
	# Reduce-motion freezes the scroll.
	SaveManager.settings["reduce_motion"] = true
	var frozen = sc._live[0]
	var zf: float = frozen.position.z
	sc._process(0.3)
	_check("scenery: frozen under reduce_motion", frozen.position.z == zf)
	# Motion on: a prop well before recycle advances forward.
	SaveManager.settings["reduce_motion"] = false
	var mover = null
	for p in sc._live:
		if p.position.z < 0.0:
			mover = p
			break
	if mover != null:
		var zb: float = mover.position.z
		sc._process(0.1)
		_check("scenery: scrolls forward during play", mover.position.z > zb)
	GameCore.go_to_menu()
	sc.free()
	SaveManager.settings["reduce_motion"] = false

## Gentle power-up "builds": shield absorbs a stumble (no life lost) once, slow
## softens scroll_speed and expires, double multiplies rescues, and a new run
## clears the build. All celebration/forgiveness — never a penalty.
func _test_powerups() -> void:
	ThemeManager.load_theme("forest")
	GameCore.start_run()
	Powerups.clear_all()
	var before := GameCore.stumbles
	var used := {"v": false}
	var cb := func(): used["v"] = true
	GameCore.shield_used.connect(cb)
	Powerups.activate("shield")
	GameCore.stumble()
	_check("powerup: shield absorbs the stumble (no life lost)", GameCore.stumbles == before)
	_check("powerup: shield_used fired", used["v"])
	_check("powerup: shield consumed after one hit", not Powerups.is_active("shield"))
	GameCore.shield_used.disconnect(cb)
	GameCore.stumble()
	_check("powerup: without a shield, a stumble costs a life", GameCore.stumbles == before + 1)
	GameCore.current_speed = 10.0
	Powerups.activate("slow", 1.0)
	_check("powerup: slow softens scroll_speed", GameCore.scroll_speed() < 10.0)
	Powerups._process(2.0)
	_check("powerup: slow expires", not Powerups.is_active("slow")
		and is_equal_approx(GameCore.scroll_speed(), 10.0))
	Powerups.activate("double", 5.0)
	_check("powerup: double doubles rescue score", Powerups.rescue_multiplier() == 2)
	GameCore.start_run()
	_check("powerup: a new run clears the build", not Powerups.is_active("double"))
	Powerups.clear_all()
	GameCore.go_to_menu()

## The HUD shows a "build" chip per active power-up, and clears them when over.
func _test_powerup_hud() -> void:
	var hud = preload("res://ui/HUD.gd").new()
	add_child(hud)
	GameCore.start_run()
	Powerups.clear_all()
	Powerups.activate("double", 5.0)
	_check("powerup hud: a chip appears for an active build", hud._powerup_row.get_child_count() >= 1)
	Powerups.clear_all()
	_check("powerup hud: chips clear when the build ends", hud._powerup_row.get_child_count() == 0)
	hud.free()
	GameCore.go_to_menu()

## The magnet power-up pulls gems toward the player's lane (cages are never pulled).
func _test_magnet() -> void:
	ThemeManager.load_theme("forest")
	SaveManager.settings["reduce_motion"] = true
	GameCore.start_run()
	var player = preload("res://scenes/Player.tscn").instantiate()
	add_child(player)
	player.position.x = 0.0
	var gem = preload("res://core/Collectible.gd").new()
	gem.kind = "gem"
	add_child(gem)
	gem.setup("red", 0)
	gem.position = Vector3(2.0, 0.0, -8.0)
	Powerups.clear_all()
	Powerups.activate("magnet", 5.0)
	var x_before: float = gem.position.x
	gem._process(0.2)
	_check("powerup: magnet pulls a gem toward the player's lane", gem.position.x < x_before)
	Powerups.clear_all()
	gem.free()
	player.free()
	GameCore.go_to_menu()
	SaveManager.settings["reduce_motion"] = false

## A discovery event fires a named gentle surprise (a treat or a bonus shower).
func _test_discovery() -> void:
	ThemeManager.load_theme("forest")
	GameCore.start_run()
	Powerups.clear_all()
	var got := {"n": ""}
	var cb := func(n): got["n"] = n
	Discovery.discovery.connect(cb)
	Discovery._fire()
	_check("discovery: fires a named gentle event", got["n"] == "treat" or got["n"] == "shower")
	Discovery.discovery.disconnect(cb)
	Powerups.clear_all()
	GameCore.go_to_menu()

## A hurdle in your lane is a gentle stumble unless jumped; a different-lane one is
## dodged. (Two solutions = fair and kind.)
func _test_obstacle() -> void:
	ThemeManager.load_theme("forest")
	GameCore.start_run()
	var player = preload("res://scenes/Player.tscn").instantiate()
	add_child(player)
	player.current_lane = 1
	var before := GameCore.stumbles
	var ob = preload("res://core/Obstacle.gd").new()
	add_child(ob)
	ob.setup("hurdle", 1)
	ob._resolve()
	_check("obstacle: an un-jumped hurdle in your lane costs a life", GameCore.stumbles == before + 1)
	player.jump()
	var ob2 = preload("res://core/Obstacle.gd").new()
	add_child(ob2)
	ob2.setup("hurdle", 1)
	ob2._resolve()
	_check("obstacle: a jumped hurdle is cleared", GameCore.stumbles == before + 1)
	player._vstate = "ground"
	player.current_lane = 0
	var ob3 = preload("res://core/Obstacle.gd").new()
	add_child(ob3)
	ob3.setup("hurdle", 2)
	ob3._resolve()
	_check("obstacle: a different-lane obstacle is dodged", GameCore.stumbles == before + 1)
	ob.free()
	ob2.free()
	ob3.free()
	player.free()
	GameCore.go_to_menu()

## Jump and slide are distinct timed states, one at a time, that return to ground.
func _test_jump_slide() -> void:
	ThemeManager.load_theme("forest")
	var p = preload("res://scenes/Player.tscn").instantiate()
	add_child(p)
	GameCore.start_run()
	p.jump()
	_check("jump: enters airborne state", p.is_airborne())
	p._update_vertical(p._jump_seconds + 0.1)
	_check("jump: returns to ground", not p.is_airborne())
	p.slide()
	_check("slide: enters sliding state", p.is_sliding())
	p._update_vertical(p._slide_seconds + 0.1)
	_check("slide: returns to ground", not p.is_sliding())
	p.slide()
	p.jump()
	_check("vertical: one action at a time (jump blocked mid-slide)",
		p.is_sliding() and not p.is_airborne())
	p.free()
	GameCore.go_to_menu()

## The world journeys through biomes within a run: the sky palette shifts after
## the interval and resets to base on menu — gameplay tuning is never touched.
func _test_biomes() -> void:
	ThemeManager.load_theme("forest")
	var base_top: Color = ThemeManager.color("background_top")
	var base_gem: Color = ThemeManager.gem_color("red")
	var got := {"name": ""}
	var cb := func(n): got["name"] = n
	Biomes.biome_changed.connect(cb)
	GameCore.start_run()
	var interval := int(ThemeManager.get_val("biome_interval", 8))
	for i in interval:
		GameCore.rescue_critter("bunny")
	_check("biome: advances after the interval", got["name"] != "")
	_check("biome: the sky palette shifts", ThemeManager.color("background_top") != base_top)
	_check("biome: gameplay (gem colors) untouched", ThemeManager.gem_color("red") == base_gem)
	Biomes.biome_changed.disconnect(cb)
	GameCore.go_to_menu()
	_check("biome: resets to base on menu", ThemeManager.color("background_top") == base_top)
	SaveManager.unlocked_critters = []

## The Spawner drops a power-up pickup (rotating, valid kind) into the world.
func _test_powerup_spawn() -> void:
	ThemeManager.load_theme("forest")
	var sp = preload("res://core/Spawner.gd").new()
	sp.powerup_scene = preload("res://scenes/Powerup.tscn")
	add_child(sp)
	GameCore.start_run()
	sp._spawn_powerup()
	var pus := sp.get_tree().get_nodes_in_group("powerup")
	_check("powerup: a pickup spawns with a valid kind",
		pus.size() >= 1 and str(pus[pus.size() - 1]._kind) in Powerups.KINDS)
	for p in pus:
		p.queue_free()
	GameCore.go_to_menu()
	sp.free()

## Lane markers sit on the computed lane boundaries, freeze the scroll (but stay
## drawn) under reduce_motion, and scroll when motion is on.
func _test_lane_markers() -> void:
	ThemeManager.load_theme("forest")
	var lm = preload("res://core/LaneMarkers.gd").new()
	add_child(lm)
	_check("markers: dashes built", lm._dashes.size() > 0)
	_check("markers: two dividers for 3 lanes", lm._boundaries.size() == 2)
	var aligned := true
	for d in lm._dashes:
		var on_boundary := false
		for bx in lm._boundaries:
			if absf(d.position.x - bx) < 0.001:
				on_boundary = true
		if not on_boundary:
			aligned = false
	_check("markers: dashes sit on lane boundaries", aligned)
	GameCore.start_run()
	SaveManager.settings["reduce_motion"] = true
	var d0 = lm._dashes[0]
	var zb: float = d0.position.z
	lm._process(0.3)
	_check("markers: frozen under reduce_motion", d0.position.z == zb)
	_check("markers: still drawn under reduce_motion", lm._dashes.size() > 0)
	SaveManager.settings["reduce_motion"] = false
	lm._process(0.05)
	_check("markers: scroll when motion is on", d0.position.z > zb)
	GameCore.go_to_menu()
	lm.free()
	SaveManager.settings["reduce_motion"] = false

## SkyRig builds a valid Environment for every theme and applies themed light
## energy to a sibling DirectionalLight (fog is renderer-only, validated by data).
func _test_atmosphere() -> void:
	for id in ["forest", "space", "ocean"]:
		ThemeManager.load_theme(id)
		var root := Node3D.new()
		add_child(root)
		var ground := MeshInstance3D.new()
		ground.name = "Ground"
		ground.mesh = PlaneMesh.new()
		root.add_child(ground)
		var light := DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		root.add_child(light)
		var sky = preload("res://core/SkyRig.gd").new()
		root.add_child(sky)
		_check("atmosphere[%s]: environment built" % id, sky.environment != null)
		_check("atmosphere[%s]: light energy from theme" % id,
			is_equal_approx(light.light_energy, float(ThemeManager.get_val("light_energy", 1.0))))
		root.free()
	ThemeManager.load_theme("forest")

## The ambient field builds from theme data and never emits under reduce_motion
## (or the headless renderer); it builds for every theme without throwing.
func _test_ambient() -> void:
	for id in ["forest", "space", "ocean"]:
		ThemeManager.load_theme(id)
		var am = preload("res://core/Ambient.gd").new()
		add_child(am)
		var cfg = ThemeManager.get_val("ambient", {})
		_check("ambient[%s]: emitter built" % id, am._p is CPUParticles3D)
		_check("ambient[%s]: amount from theme" % id, am._p.amount == int(cfg.get("amount", 24)))
		SaveManager.settings["reduce_motion"] = true
		am._process(0.1)
		_check("ambient[%s]: off under reduce_motion" % id, not am._p.emitting)
		if DisplayServer.get_name() == "headless":
			SaveManager.settings["reduce_motion"] = false
			am._process(0.1)
			_check("ambient[%s]: off under headless renderer" % id, not am._p.emitting)
		am.free()
	SaveManager.settings["reduce_motion"] = false
	ThemeManager.load_theme("forest")

## Every theme's scenery style builds non-empty props, all outside the lanes.
func _test_scenery_styles() -> void:
	for id in ["forest", "space", "ocean"]:
		ThemeManager.load_theme(id)
		var sc = preload("res://core/Scenery.gd").new()
		add_child(sc)
		var ok: bool = sc._live.size() > 0
		for p in sc._live:
			if absf(p.position.x) < sc._play_half or p.get_child_count() == 0:
				ok = false
		_check("scenery[%s]: props built outside lanes" % id, ok)
		sc.free()
	ThemeManager.load_theme("forest")

## The procedural player builds for every shape and swaps in WITHOUT disturbing
## collision, the hidden box, _body(), or the carry badge.
func _test_player_visual() -> void:
	for shape in ["critter", "rocket", "sub", "unknown_xyz"]:
		var v := ThemeModels.player_visual(shape, Color.WHITE)
		_check("player visual builds for '%s'" % shape, v is Node3D and v.get_child_count() > 0)
		v.free()
	ThemeManager.load_theme("forest")
	var p = preload("res://scenes/Player.tscn").instantiate()
	add_child(p)
	var area = p.get_node_or_null("Area3D")
	_check("player: collision Area3D intact (layer 2 / mask 1)",
		area != null and area.collision_layer == 2 and area.collision_mask == 1)
	var box = p.get_node_or_null("MeshInstance3D")
	_check("player: box placeholder hidden after proc swap", box != null and not box.visible)
	_check("player: _body() is the proc model, not the box",
		p._body() != null and p._body() != box)
	p.carry_color("red")
	var badge = p.get_node_or_null("CarryBadge")
	_check("player: carry badge still shows with a proc body", badge != null and badge.visible)
	p.free()
	ThemeManager.load_theme("forest")

## Gem and cage read as different silhouettes even with zero art (sphere vs ring).
func _test_collectible_silhouette() -> void:
	ThemeManager.load_theme("forest")
	var gem = preload("res://scenes/Gem.tscn").instantiate()
	var cage = preload("res://scenes/Cage.tscn").instantiate()
	add_child(gem)
	add_child(cage)
	gem.setup("red", 0)
	cage.setup("red", 0)
	var gm = gem.get_node("MeshInstance3D").mesh
	var cm = cage.get_node("MeshInstance3D").mesh
	_check("silhouette: gem and cage use different mesh shapes",
		gm != null and cm != null and gm.get_class() != cm.get_class())
	gem.free()
	cage.free()

## Master volume maps to the Master bus in dB and persists.
func _test_master_volume() -> void:
	AudioManager.set_master_volume(0.5)
	_check("volume: master bus reflects the setting in dB",
		is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)))
	_check("volume: setting persisted",
		is_equal_approx(float(SaveManager.settings.get("master_volume", 1.0)), 0.5))
	AudioManager.set_master_volume(1.0)   # restore full

func _find_checkbutton(node: Node, label: String) -> CheckButton:
	if node is CheckButton and label in (node as CheckButton).text:
		return node
	for c in node.get_children():
		var r := _find_checkbutton(c, label)
		if r:
			return r
	return null

## Walk a Control tree looking for a Button/Label whose text contains `substr`.
func _find_text_descendant(node: Node, substr: String) -> bool:
	if node is Button and substr in (node as Button).text:
		return true
	if node is Label and substr in (node as Label).text:
		return true
	for c in node.get_children():
		if _find_text_descendant(c, substr):
			return true
	return false
