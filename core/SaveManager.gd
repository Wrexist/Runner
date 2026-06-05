extends Node
## SaveManager (autoload singleton)
## Local-only persistence. COMPLIANCE: this file must NEVER make a network call,
## load an analytics SDK, or collect any personal data. Everything stays in
## user:// on the device. That is what keeps the app COPPA / Kids-Category safe.

const SAVE_PATH := "user://critter_dash_save.json"

var high_score: int = 0
var unlocked_critters: Array = []          # critter ids earned by score
var all_unlocked_iap: bool = false         # set true by the single unlock-all IAP
var settings: Dictionary = {"music": true, "sfx": true}

func _ready() -> void:
	load_game()

## Earn-by-play unlock. Idempotent + auto-saves.
func unlock_critter(id: String) -> void:
	if id not in unlocked_critters:
		unlocked_critters.append(id)
		save_game()

func is_unlocked(id: String) -> bool:
	return all_unlocked_iap or id in unlocked_critters

func set_all_unlocked(value: bool) -> void:
	all_unlocked_iap = value
	save_game()

func save_game() -> void:
	var data := {
		"high_score": high_score,
		"unlocked_critters": unlocked_critters,
		"all_unlocked_iap": all_unlocked_iap,
		"settings": settings,
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
	settings = parsed.get("settings", settings)
