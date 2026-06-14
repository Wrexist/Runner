extends Node
## SaveManager (autoload singleton)
## Local-only persistence. COMPLIANCE: this file must NEVER make a network call,
## load an analytics SDK, or collect any personal data. Everything stays in
## user:// on the device. That is what keeps the app COPPA / Kids-Category safe.

const SAVE_PATH := "user://critter_dash_save.json"

var high_score: int = 0
var unlocked_critters: Array = []          # critter ids earned by score
var all_unlocked_iap: bool = false         # set true by the single unlock-all IAP
var settings: Dictionary = {
	"music": true, "sfx": true, "reduce_motion": false,
	"haptics": true, "master_volume": 1.0,
}
var seen_tutorial: bool = false            # first-run "how to play" shown once
var lifetime_rescued: int = 0              # gentle progress stat (never a quota)
var runs_played: int = 0
# Personal-best stats — local-only, celebration-only. NOT a daily streak, quota,
# or any FOMO hook; just "look how you've improved" when the player chooses to look.
var best_streak: int = 0
var most_rescues_in_run: int = 0
var longest_run_seconds: float = 0.0

func _ready() -> void:
	load_game()

## Earn-by-play unlock. Idempotent. Pass save=false to batch several unlocks into
## a single disk write (GameCore does this when a rescue crosses several gates).
func unlock_critter(id: String, save := true) -> void:
	if id not in unlocked_critters:
		unlocked_critters.append(id)
		if save:
			save_game()

func is_unlocked(id: String) -> bool:
	return all_unlocked_iap or id in unlocked_critters

## Wipe gameplay progress (parent-gated in the UI). Keeps user SETTINGS and the
## IAP entitlement — purchases must persist and stay restorable per App Store rules.
func reset_progress() -> void:
	high_score = 0
	unlocked_critters = []
	lifetime_rescued = 0
	runs_played = 0
	seen_tutorial = false
	best_streak = 0
	most_rescues_in_run = 0
	longest_run_seconds = 0.0
	save_game()

func set_all_unlocked(value: bool) -> void:
	all_unlocked_iap = value
	save_game()

## Persist a single setting change immediately (the one funnel the UI uses, so
## "settings autosave on every change" is provably true).
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_game()

## Raise the local-only personal bests after a run and save once. Celebration-only.
func record_run_stats(streak_peak: int, rescues: int, seconds: float) -> void:
	best_streak = maxi(best_streak, streak_peak)
	most_rescues_in_run = maxi(most_rescues_in_run, rescues)
	longest_run_seconds = maxf(longest_run_seconds, seconds)
	save_game()

func save_game() -> void:
	var data := {
		"high_score": high_score,
		"unlocked_critters": unlocked_critters,
		"all_unlocked_iap": all_unlocked_iap,
		"settings": settings,
		"seen_tutorial": seen_tutorial,
		"lifetime_rescued": lifetime_rescued,
		"runs_played": runs_played,
		"best_streak": best_streak,
		"most_rescues_in_run": most_rescues_in_run,
		"longest_run_seconds": longest_run_seconds,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	high_score = int(parsed.get("high_score", 0))
	unlocked_critters = parsed.get("unlocked_critters", [])
	all_unlocked_iap = bool(parsed.get("all_unlocked_iap", false))
	# Merge so new setting keys (e.g. reduce_motion) keep their defaults on
	# saves written by an older build.
	var loaded_settings: Variant = parsed.get("settings", {})
	if loaded_settings is Dictionary:
		settings.merge(loaded_settings, true)
	seen_tutorial = bool(parsed.get("seen_tutorial", false))
	lifetime_rescued = int(parsed.get("lifetime_rescued", 0))
	runs_played = int(parsed.get("runs_played", 0))
	best_streak = int(parsed.get("best_streak", 0))
	most_rescues_in_run = int(parsed.get("most_rescues_in_run", 0))
	longest_run_seconds = float(parsed.get("longest_run_seconds", 0.0))
