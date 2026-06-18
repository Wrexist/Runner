extends Node
## Biomes (autoload) — within a single run the WORLD journeys through a gentle
## day → dusk → night → dawn cycle: the sky, ground, and scenery re-skin every few
## rescues, so "every run is an adventure." PURELY cosmetic — it overrides only the
## visual palette (via ThemeManager), never gem colors, speeds, or spawns.

signal biome_changed(name: String)

const NAMES := ["Dawn", "Day", "Dusk", "Night"]

var _index := 0
var _marker := 0          # rescue count at the last biome change
var _base_top := Color.WHITE
var _base_bottom := Color.WHITE
var _base_accent := Color.WHITE

func _ready() -> void:
	GameCore.run_started.connect(_on_run_started)
	GameCore.critter_rescued.connect(_on_rescued)
	GameCore.returned_to_menu.connect(_reset)
	GameCore.run_ended.connect(func(_s, _h): _reset())

func _on_run_started() -> void:
	_index = 0
	_marker = 0
	ThemeManager.clear_overrides()           # start at the base palette
	_base_top = ThemeManager.color("background_top", Color(0.5, 0.7, 0.9))
	_base_bottom = ThemeManager.color("background_bottom", Color(0.7, 0.8, 0.9))
	_base_accent = ThemeManager.color("accent", Color(1.0, 0.6, 0.6))

func _reset() -> void:
	_index = 0
	_marker = 0
	ThemeManager.clear_overrides()

func _on_rescued(_id: String, total: int) -> void:
	var interval := maxi(int(ThemeManager.get_val("biome_interval", 8)), 2)
	if total - _marker >= interval:
		_marker = total
		_index += 1
		_apply()

## Re-skin to the current biome — a procedural time-of-day shift of the BASE
## palette (so green grass journeys through the day rather than turning magenta).
func _apply() -> void:
	var phase := _index % NAMES.size()
	SaveManager.discover("biome:" + NAMES[phase])
	if phase == 0:                           # back to base (Dawn)
		ThemeManager.clear_overrides()
		emit_signal("biome_changed", NAMES[0])
		return
	var top := _base_top
	var bot := _base_bottom
	var acc := _base_accent
	match phase:
		1:                                   # Day — bright
			top = _base_top.lightened(0.12)
			bot = _base_bottom.lightened(0.10)
		2:                                   # Dusk — golden warmth
			top = _base_top.lerp(Color(1.0, 0.62, 0.30), 0.45)
			bot = _base_bottom.lerp(Color(1.0, 0.58, 0.34), 0.35)
			acc = _base_accent.lerp(Color(1.0, 0.5, 0.2), 0.3)
		3:                                   # Night — cool + dim
			top = _base_top.darkened(0.45).lerp(Color(0.10, 0.10, 0.30), 0.4)
			bot = _base_bottom.darkened(0.40).lerp(Color(0.12, 0.12, 0.28), 0.3)
	ThemeManager.set_overrides({"palette": {
		"background_top": top, "background_bottom": bot, "accent": acc}})
	emit_signal("biome_changed", NAMES[phase])

func current_name() -> String:
	return NAMES[_index % NAMES.size()]
