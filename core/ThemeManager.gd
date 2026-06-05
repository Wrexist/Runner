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

func _ready() -> void:
	load_theme(active_theme)

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
	active_theme = theme_id
	emit_signal("theme_loaded", theme_id)
	return true

## Generic typed-with-default getter used by core logic.
func get_val(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)

## Convenience accessors with safe fallbacks so a missing key never crashes.
func color(name: String, fallback: Color = Color.WHITE) -> Color:
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
