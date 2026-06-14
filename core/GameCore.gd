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
# --- Celebration-only feedback signals (carry no penalty, gate no content) ---
signal critter_unlocked(id: String)          # a NEW critter just crossed its score gate
signal milestone_reached(kind: String, value: int)  # e.g. ("rescues", 25)
signal near_miss                             # dodged an unprepared cage by a hair
signal points_popped(amount: int, world_pos: Vector3)  # for floating "+N" text
signal shield_used                           # a shield power-up absorbed a stumble

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
var _streak_peak: int = 0                    # best streak reached this run (for stats)

## True only when a run is actively playing (not menu, game-over, or paused).
## Every gameplay _process loop gates on this so pause freezes the world while
## the HUD/tweens keep animating.
func is_running() -> bool:
	return state == State.PLAYING and not paused

## The speed the WORLD scrolls at — the difficulty ramp (current_speed) softened
## by an active "slow" power-up. Scrolling systems read this (not current_speed).
func scroll_speed() -> float:
	return current_speed * Powerups.slow_multiplier()

func start_run() -> void:
	score = 0
	elapsed = 0.0
	stumbles = 0
	streak = 0
	_streak_peak = 0
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
	# Gentle, predictable pacing — never punishing spikes. Every run opens with a
	# warm-up grace period (speed held at the starting value, room to settle in),
	# then a smooth ramp toward the cap. On "easy" the ramp is 0, so speed stays
	# flat for the youngest players.
	var smax := float(ThemeManager.diff_val("scroll_speed_max", 18.0))
	if elapsed <= float(ThemeManager.diff_val("warmup_seconds", 2.5)):
		current_speed = float(ThemeManager.diff_val("scroll_speed_start", 8.0))
		return
	var ramp := float(ThemeManager.diff_val("speed_ramp_per_second", 0.15))
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
	_streak_peak = maxi(_streak_peak, streak)
	SaveManager.lifetime_rescued += 1   # persisted on run end
	# A gentle, generous bonus for a hot streak — caps so it never snowballs.
	# Doubled while a "double" power-up is active (celebration only).
	add_score((10 + mini(streak, 5)) * Powerups.rescue_multiplier())
	# Earn-by-score unlock: unlock EVERY critter whose threshold is now met, not
	# just the one this rescue happened to surface. This makes the Album's
	# "Reach N" promise deterministic instead of waiting on the random rescue pick.
	# Skip already-owned critters and batch a single save so a milestone rescue
	# doesn't trigger one disk write per critter.
	var newly_unlocked := false
	for c in ThemeManager.get_val("rescuable_critters", []):
		var cid := str(c.get("id", ""))
		if cid != "" and score >= int(c.get("unlock_score", 0)) and not SaveManager.is_unlocked(cid):
			SaveManager.unlock_critter(cid, false)
			newly_unlocked = true
			emit_signal("critter_unlocked", cid)
	if newly_unlocked:
		SaveManager.save_game()
	emit_signal("critter_rescued", id, rescued_this_run.size())
	emit_signal("streak_changed", streak)
	_check_milestones()

## Celebrate hitting a rescue milestone (e.g. 25/50/100 this run). Thresholds are
## data-driven; this is pure positive feedback — it never gates content or nags.
func _check_milestones() -> void:
	var n := rescued_this_run.size()
	for m in ThemeManager.get_val("milestone_rescues", [25, 50, 100]):
		if n == int(m):
			emit_signal("milestone_reached", "rescues", n)
			return

## Gentle "three strikes" loss: hitting an unprepared cage costs a life, not an
## instant game-over. Kids get to recover; the run only ends after max_stumbles.
func stumble() -> void:
	if state != State.PLAYING:
		return
	# A shield power-up absorbs the hit entirely — forgiving, never a punishment.
	if Powerups.consume_shield():
		emit_signal("shield_used")
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
	# Record this run's personal bests + persist everything in one save.
	SaveManager.record_run_stats(_streak_peak, rescued_this_run.size(), elapsed)
	emit_signal("run_ended", score, is_high)
