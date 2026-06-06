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
