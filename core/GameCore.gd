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

func start_run() -> void:
	score = 0
	elapsed = 0.0
	stumbles = 0
	streak = 0
	rescued_this_run = []
	current_speed = float(ThemeManager.get_val("scroll_speed_start", 8.0))
	state = State.PLAYING
	emit_signal("run_started")
	emit_signal("score_changed", score)
	emit_signal("streak_changed", streak)

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	# Gentle, predictable speed ramp — never punishing spikes.
	var ramp := float(ThemeManager.get_val("speed_ramp_per_second", 0.15))
	var smax := float(ThemeManager.get_val("scroll_speed_max", 18.0))
	current_speed = min(current_speed + ramp * delta, smax)

func add_score(amount: int) -> void:
	score += amount
	emit_signal("score_changed", score)

func rescue_critter(id: String) -> void:
	rescued_this_run.append(id)
	streak += 1
	# A gentle, generous bonus for a hot streak — caps so it never snowballs.
	add_score(10 + mini(streak, 5))
	# Earn-by-score unlock check against theme config. Bracket/.get access is
	# unambiguous on JSON-parsed Dictionaries and stays safe if a key is missing.
	for c in ThemeManager.get_val("rescuable_critters", []):
		if c.get("id", "") == id and score >= int(c.get("unlock_score", 0)):
			SaveManager.unlock_critter(id)
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
		SaveManager.save_game()
	emit_signal("run_ended", score, is_high)
