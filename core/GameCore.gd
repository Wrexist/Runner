extends Node
## GameCore (autoload singleton)
## Owns run state, scoring, and the difficulty ramp.
## Genre-agnostic enough to survive reskins; reads tuning from ThemeManager.

signal run_started
signal run_ended(score: int, is_high: bool)
signal score_changed(score: int)
signal critter_rescued(id: String, total_rescued: int)
signal stumbled(lives_remaining: int)
signal streak_changed(streak: int)
signal new_best                              # first time this run beats the old best
signal paused_changed(is_paused: bool)
signal returned_to_menu

enum State { MENU, PLAYING, GAME_OVER }

var state: int = State.MENU
var score: int = 0
var rescued_this_run: Array = []
var elapsed: float = 0.0
var current_speed: float = 8.0
var stumbles: int = 0
## Consecutive rescues without a stumble. Drives *celebration* feedback only —
## it never punishes and never gates content. Pure "you're doing great" juice.
var streak: int = 0
var paused: bool = false
var _announced_best: bool = false

## True only when a run is actively playing (not menu, game-over, or paused).
## Every gameplay _process loop gates on this so pause freezes the world while
## the HUD/tweens keep animating.
func is_running() -> bool:
	return state == State.PLAYING and not paused

func start_run() -> void:
	score = 0
	elapsed = 0.0
	stumbles = 0
	streak = 0
	paused = false
	_announced_best = false
	rescued_this_run = []
	current_speed = float(ThemeManager.diff_val("scroll_speed_start", 8.0))
	state = State.PLAYING
	emit_signal("run_started")
	emit_signal("score_changed", score)
	emit_signal("streak_changed", streak)

# --- Pause (manual + automatic on app backgrounding) ---
func pause() -> void:
	if state != State.PLAYING or paused:
		return
	paused = true
	emit_signal("paused_changed", true)

func resume() -> void:
	if not paused:
		return
	paused = false
	emit_signal("paused_changed", false)

## Abandon the current run and go back to the menu (no score recorded).
func go_to_menu() -> void:
	paused = false
	state = State.MENU
	emit_signal("paused_changed", false)
	emit_signal("returned_to_menu")

func _notification(what: int) -> void:
	# Auto-pause if the app loses focus / is backgrounded — never punish a kid
	# because a call came in or a parent took the phone.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pause()

func _process(delta: float) -> void:
	if not is_running():
		return
	elapsed += delta
	# Gentle, predictable speed ramp — never punishing spikes. On "easy" the
	# ramp is 0, so speed stays flat for the youngest players.
	var ramp := float(ThemeManager.diff_val("speed_ramp_per_second", 0.15))
	var smax := float(ThemeManager.diff_val("scroll_speed_max", 18.0))
	current_speed = min(current_speed + ramp * delta, smax)

func add_score(amount: int) -> void:
	if state != State.PLAYING:
		return
	score += amount
	emit_signal("score_changed", score)
	# Celebrate the moment you pass your previous best (only if you had one).
	if not _announced_best and SaveManager.high_score > 0 and score > SaveManager.high_score:
		_announced_best = true
		emit_signal("new_best")

func rescue_critter(id: String) -> void:
	if state != State.PLAYING:
		return
	rescued_this_run.append(id)
	streak += 1
	SaveManager.lifetime_rescued += 1   # persisted on run end
	# A gentle, generous bonus for a hot streak — caps so it never snowballs.
	add_score(10 + mini(streak, 5))
	# Earn-by-score unlock: unlock EVERY critter whose threshold is now met, not
	# just the one this rescue happened to surface. This makes the Album's
	# "Reach N" promise deterministic instead of waiting on the random rescue pick.
	for c in ThemeManager.get_val("rescuable_critters", []):
		var cid := str(c.get("id", ""))
		if cid != "" and score >= int(c.get("unlock_score", 0)):
			SaveManager.unlock_critter(cid)
	emit_signal("critter_rescued", id, rescued_this_run.size())
	emit_signal("streak_changed", streak)

## Gentle "three strikes" loss: hitting an unprepared cage costs a life, not an
## instant game-over. Kids get to recover; the run only ends after max_stumbles.
func stumble() -> void:
	if state != State.PLAYING:
		return
	stumbles += 1
	streak = 0
	var max_stumbles := int(ThemeManager.get_val("max_stumbles", 3))
	emit_signal("stumbled", maxi(max_stumbles - stumbles, 0))
	emit_signal("streak_changed", streak)
	if stumbles >= max_stumbles:
		end_run()

func end_run() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	var is_high := score > SaveManager.high_score
	if is_high:
		SaveManager.high_score = score
	SaveManager.runs_played += 1
	SaveManager.save_game()   # persist high score + lifetime stats together
	emit_signal("run_ended", score, is_high)
