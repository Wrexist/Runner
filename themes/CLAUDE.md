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
| `move_speed` | Player | how fast the player slides between lanes (feel; default 12) |
| `scroll_speed_start/max`, `speed_ramp_per_second` | GameCore | difficulty ramp |
| `gem_colors` | Spawner | which gem/cage colors appear |
| `gem_palette` | ThemeManager.gem_color | optional name→hex map (else built-in defaults) |
| `gem_symbols` | ThemeManager.gem_symbol | optional name→shape map for color-blind play |
| `spawn_interval_start/min` | Spawner | pacing (tightens as run speeds up) |
| `gem_cage_gap` | Spawner | gem→cage spacing = reaction window (difficulty lever) |
| `max_stumbles` | GameCore | lives before a gentle run-end (default 3) |
| `difficulty.{easy,normal}` | ThemeManager.diff_val | per-preset overrides of speed/ramp/spawn/gap; chosen in Settings (default easy) |
| `assets.*` | `ThemeModels` (auto-loaded) | model/texture paths — dropped-in `.glb`/`.png` load at runtime, no scene edits; procedural placeholders until then |
| `rescuable_critters[]` | GameCore | `{id, model, unlock_score}` earn-by-play |
| `audio.*` | juice/audio | music + sfx paths; missing = silent, never crash |
| `credits[]` | About screen | optional attribution; each entry a string or `{asset, author, license}`. Any **CC-BY** asset MUST be listed here. Mirror `docs/CREDITS.md`. |

Tuning that has a `difficulty` override is read via `ThemeManager.diff_val(key)`
(preset → top-level → default). Everything else uses `get_val`.

## Polish-overhaul tunables (all optional; code has safe defaults)

These were added to make the game feel like a top-tier runner. They are OPTIONAL
(every reader passes a default), but `tests/Tests.gd` `_test_theme_schema_extended`
enforces PARITY: each must be present in **every** theme or **none**. Add a key to
all three themes and to `EXTENDED_KEYS` in the same change.

| key | used by | default | notes |
|---|---|---|---|
| `swipe_threshold_px` | Player | 40 | px before a drag counts as a swipe |
| `tap_dead_zone_frac` | Player | 0.12 | ignore taps within this frac of centre |
| `lane_change_cooldown` | Player | 0.0 | min seconds between lane changes (0 = off) |
| `carry_glow` / `carry_badge_scale` | Player | 1.4 / 1.0 | carried-colour badge emission / size |
| `haptic_ms` | Effects.haptic | `{light:12,rescue:25}` | vibration ms per kind (mobile only) |
| `warmup_seconds` | GameCore (`diff_val`) | 2.5 | grace period before the speed ramp |
| `milestone_rescues` | GameCore | `[25,50,100]` | rescue counts that fire a celebration |
| `spawn_patterns` | Spawner | (single fallback) | array of `{type:single|rest|double, weight}` |
| `forgiveness_z` / `near_miss_z` | Collectible | 0.6 / 0.8 | reward pickup tolerance / dodge window |
| `stumble_flash_alpha` / `stumble_flash_time` | HUD→ScreenFX | 0.18 / 0.25 | gentle stumble dim (alpha ≤ 0.25, no shake) |
| `gem_emission` | Collectible | 0.8 | gem glow (cages stay matte) |
| `glow_intensity` | SkyRig | 0.4 | world glow post-FX |
| `ground_uv_speed` | SkyRig | 0.04 | ground scroll rate |
| `camera_follow` / `camera_smooth` | CameraRig | 0.4 / 5.0 | lane-follow amount / lerp speed |
| `camera_zoom_amount` | CameraRig | 0.0 | extra FOV° at max speed (0 = off; subtle, bounded) |
| `audio.{menu_music,ui_click,whoosh,near_miss,jingle}` | AudioManager | (fail-soft) | extra SFX/music keys; silent until sourced |
| `critter_detail` | ThemeModels | "full" | "full" feature-built creatures vs "simple" two-blob |
| `player_shape` | Player/ThemeModels | "critter" | procedural player silhouette: critter / rocket / sub |
| `scenery` | Scenery | `{style,…}` | side props `{style,density,max_props,min_x_margin,side_band,scale_min,scale_max}` |
| `ambient` | Ambient | `{style,…}` | drifting field `{style,amount,color,box,speed}` |
| `fog_enabled` / `fog_density` | SkyRig | false / 0 | optional gentle distance fog for depth |
| `ambient_energy` | SkyRig | 0.7 | ambient light energy |
| `light_energy` / `light_color` | SkyRig | 1.0 / — | DirectionalLight tuning (fail-soft if absent) |
| `lane_marker` | LaneMarkers | `{enabled,…}` | dashed lane dividers `{enabled,color,dash_len,dash_gap}` |

Nested-object keys (`scenery`, `ambient`, `lane_marker`, `haptic_ms`) are
parity-checked at the TOP level; their fields are code-defaulted, so a theme only
needs the key present.

COMPLIANCE: `spawn_patterns` can never wall the track — the Spawner enforces "≥1
lane always clear" in code regardless of data, and `scenery` props are clamped to
`|x| ≥ play_half` so they never enter a travel lane. Forgiveness only helps
rewards (the hazard stays fair). Streaks/milestones/near-miss are celebration-only.
Every new visual freezes/suppresses under `reduce_motion`; ambient particles are
also off under the headless renderer. All procedural — no imported art, no shaders.

## Compliance note

`unlock_score` gates are **earned by play**, never randomized and never sold.
The only purchase is the single global "unlock all" IAP handled outside themes.

Current themes: **forest** (default), **space** (reskin proof), and **ocean**
("Reef Rescue" — data-only, art pending).
