# themes/ — pure data + art (no code)

A theme is the *entire* difference between two shipped games. Adding a theme must
require **zero** changes to `core/`, `scenes/`, or `ui/`. If you find yourself
editing code to make a theme work, fix the engine to read that value from
`theme.json` instead — that's the whole point of this architecture.

## How to add a theme

1. Create `themes/<id>/theme.json` (copy an existing one as a template).
2. Drop CC0 art/audio into `themes/<id>/models|textures|audio/` and point the
   `assets` / `audio` paths at them. Use Kenney.nl / Quaternius (CC0).
3. Set `ThemeManager.active_theme = "<id>"` (or call `load_theme("<id>")`).
4. Run. The palette, names, speeds, gem colors, critters, and audio all change
   with no code edits. If anything needed a code edit, that's a bug — file it.

> **CI validates every theme.** `tests/Tests.gd` `_test_theme_schema` auto-discovers
> each `themes/<id>/` and asserts the required keys, `res://` asset/audio paths,
> distinct color-blind gem symbols, and a free starter critter (`unlock_score: 0`).
> Run `godot --headless --path . res://tests/Tests.tscn` after adding a theme.

## theme.json keys (all consumed by core via ThemeManager.get_val)

| key | used by | notes |
|---|---|---|
| `display_name` | StartScreen | title text |
| `palette.{background_top,background_bottom,accent,ui_text}` | UI/HUD | hex colors |
| `lanes`, `lane_width` | Player, Spawner | track geometry |
| `scroll_speed_start/max`, `speed_ramp_per_second` | GameCore | difficulty ramp |
| `gem_colors` | Spawner | which gem/cage colors appear |
| `gem_palette` | ThemeManager.gem_color | optional name→hex map (else built-in defaults) |
| `gem_symbols` | ThemeManager.gem_symbol | optional name→shape map for color-blind play |
| `spawn_interval_start/min` | Spawner | pacing (tightens as run speeds up) |
| `gem_cage_gap` | Spawner | gem→cage spacing = reaction window (difficulty lever) |
| `max_stumbles` | GameCore | lives before a gentle run-end (default 3) |
| `difficulty.{easy,normal}` | ThemeManager.diff_val | per-preset overrides of speed/ramp/spawn/gap; chosen in Settings (default easy) |
| `assets.*` | (art wiring) | model/texture paths |
| `rescuable_critters[]` | GameCore | `{id, model, unlock_score}` earn-by-play |
| `audio.*` | juice/audio | music + sfx paths; missing = silent, never crash |
| `credits[]` | About screen | optional attribution; each entry a string or `{asset, author, license}`. Any **CC-BY** asset MUST be listed here. Mirror `docs/CREDITS.md`. |

Tuning that has a `difficulty` override is read via `ThemeManager.diff_val(key)`
(preset → top-level → default). Everything else uses `get_val`.

## Compliance note

`unlock_score` gates are **earned by play**, never randomized and never sold.
The only purchase is the single global "unlock all" IAP handled outside themes.

Current themes: **forest** (default) and **space** (reskin proof).
