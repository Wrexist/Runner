extends Node
## ThemeManager (autoload singleton)
## Loads the active theme's theme.json and exposes its values to the whole game.
## GOLDEN RULE: all tuning, colors, asset paths and audio paths come from here.
## Core/game logic must NEVER hardcode a value that belongs in a theme — that is
## what makes the engine reskinnable with zero code changes.

signal theme_loaded(theme_id: String)

const THEMES_DIR := "res://themes/"

## Change this constant (or call load_theme) to reskin the whole game.
var active_theme: String = "forest"

var _data: Dictionary = {}
## Optional in-run visual overrides (set by the Biomes system as the world shifts
## through times-of-day). Currently a `{"palette": {name: Color/hex}}` map; checked
## by color() so the sky/ground/scenery re-skin without touching gameplay tuning.
var _overrides: Dictionary = {}

func _ready() -> void:
	load_theme(active_theme)

## Apply a transient visual override and re-skin (emits theme_loaded so SkyRig /
## Scenery / Ambient / LaneMarkers re-apply). Gameplay keys are untouched.
func set_overrides(ov: Dictionary) -> void:
	_overrides = ov
	emit_signal("theme_loaded", active_theme)

func clear_overrides() -> void:
	if _overrides.is_empty():
		return
	_overrides = {}
	emit_signal("theme_loaded", active_theme)

## Load a theme by folder id (e.g. "forest", "space"). Returns success.
func load_theme(theme_id: String) -> bool:
	var path := "%s%s/theme.json" % [THEMES_DIR, theme_id]
	if not FileAccess.file_exists(path):
		push_error("ThemeManager: theme file not found: %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ThemeManager: cannot open %s" % path)
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ThemeManager: invalid JSON in %s" % path)
		return false
	_data = parsed
	_overrides = {}                 # a fresh theme clears any biome override
	active_theme = theme_id
	emit_signal("theme_loaded", theme_id)
	return true

## Generic typed-with-default getter used by core logic.
func get_val(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)

## The active difficulty preset id (from local settings; default gentle).
func difficulty() -> String:
	return str(SaveManager.settings.get("difficulty", "easy"))

## A tuning value that may be overridden by the active difficulty preset
## (theme.json "difficulty": {"easy": {...}, "normal": {...}}). Falls back to the
## top-level theme value, then the supplied default — always fail-soft.
func diff_val(key: String, default_value: Variant = null) -> Variant:
	# Fail-soft: tolerate a malformed "difficulty" block in a future theme
	# instead of throwing on a typed assignment.
	var presets_v: Variant = _data.get("difficulty", {})
	var presets: Dictionary = presets_v if presets_v is Dictionary else {}
	var preset_v: Variant = presets.get(difficulty(), {})
	var preset: Dictionary = preset_v if preset_v is Dictionary else {}
	if preset.has(key):
		return preset[key]
	return get_val(key, default_value)

## Convenience accessors with safe fallbacks so a missing key never crashes.
func color(name: String, fallback: Color = Color.WHITE) -> Color:
	# A live biome override wins, then the theme palette, then the fallback.
	var pal_ov: Dictionary = _overrides.get("palette", {})
	if pal_ov.has(name):
		var v: Variant = pal_ov[name]
		return v if v is Color else Color(str(v))
	var pal: Dictionary = _data.get("palette", {})
	if pal.has(name):
		return Color(pal[name])
	return fallback

func asset(name: String, fallback: String = "") -> String:
	var a: Dictionary = _data.get("assets", {})
	return a.get(name, fallback)

func audio(name: String, fallback: String = "") -> String:
	var a: Dictionary = _data.get("audio", {})
	return a.get(name, fallback)

func display_name() -> String:
	return str(_data.get("display_name", "Critter Dash"))

## Gem/cage color by name. Themes may override via a "gem_palette" map in
## theme.json; otherwise a friendly built-in default is used (fail-soft).
func gem_color(name: String) -> Color:
	var pal: Dictionary = _data.get("gem_palette", {})
	if pal.has(name):
		return Color(pal[name])
	return _default_gem_color(name)

func _default_gem_color(name: String) -> Color:
	match name:
		"red": return Color(0.92, 0.32, 0.32)
		"blue": return Color(0.32, 0.52, 0.92)
		"yellow": return Color(0.95, 0.85, 0.32)
		"green": return Color(0.40, 0.80, 0.45)
		"purple": return Color(0.70, 0.42, 0.86)
		"orange": return Color(0.96, 0.60, 0.26)
		_: return Color.WHITE

## A redundant SHAPE id per color for color-blind play. Themes may override via
## a "gem_symbols" map; otherwise each color maps to a distinct primitive.
func gem_symbol(name: String) -> String:
	var syms: Dictionary = _data.get("gem_symbols", {})
	if syms.has(name):
		return str(syms[name])
	match name:
		"red": return "box"
		"blue": return "sphere"
		"yellow": return "cylinder"
		"green": return "prism"
		"purple": return "torus"
		"orange": return "capsule"
		_: return "sphere"
