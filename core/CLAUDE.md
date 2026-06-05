# core/ — engine logic (never reskinned)

These files are the genre-agnostic engine. They must survive every reskin
unchanged. If a reskin ever *requires* editing a file here, that's a bug in the
data-driven design — push the varying value into `theme.json` instead.

## The four autoloads (see project.godot for load order)

- **GameCore.gd** — single source of truth for a run. Owns `state`
  (MENU/PLAYING/GAME_OVER), `score`, `elapsed`, `current_speed`, `stumbles`,
  `rescued_this_run`. Emits `run_started`, `run_ended(score, is_high)`,
  `score_changed(score)`, `critter_rescued(id, total)`, `stumbled(lives_left)`.
  The difficulty ramp and the gentle three-stumble loss live here.
- **ThemeManager.gd** — loads `themes/<active_theme>/theme.json`. Everyone reads
  tuning through `get_val(key, default)`, `color()`, `asset()`, `audio()`.
  Change `active_theme` (or call `load_theme()`) to reskin the whole game.
- **SaveManager.gd** — local-only persistence in `user://`. 🚫 Never add a network
  call, analytics, or any data collection here. This file is a compliance surface.
- **AudioManager.gd** — plays themed music + SFX from `ThemeManager.audio(...)`.
  Fail-soft (missing file = silent warning, never a crash); honors the local
  `SaveManager.settings` music/sfx toggles. Auto-reacts to GameCore signals.
- **Effects.gd** — fire-and-forget visual juice: `burst(pos, color, amount)` and
  `pop(node)`. Kept gentle (no harsh shake). Autoload Node3D children render in
  the same root World3D as Main.
- **UIManager.gd** — owns front-end screen flow and enforces the parental gate
  before the Shop.

## Feel / juice helpers (subscribe to GameCore, change no core logic)

- **Trail.gd** — on `critter_rescued`, adds a follower that snakes behind the
  player using `Player.history_point()`. Visible length is capped (`MAX_VISIBLE`)
  while GameCore keeps counting beyond it.
- **CameraRig.gd** (on Main's Camera3D) — subtle smoothed follow of the player's
  lane. **SkyRig.gd** (on Main's WorldEnvironment) — builds the themed background.
- The `streak` celebration is positive-only feedback. Do not turn it into a
  punishment, a timer, or a content gate.

## Gameplay scripts

- **Player.gd** — lane movement via swipe/drag + arrow-key fallback (NO tilt).
  Holds `carried_color` for the rescue mechanic (`carry_color`/`clear_color`).
- **Spawner.gd** — the Rescue Run hook: a gem then a same-color cage, same lane.
- **Collectible.gd** — gem/cage behavior. Collision uses `area_entered` (both
  player and collectibles are `Area3D`). Layers: collectibles = layer 1 / mask 2,
  player Area3D = layer 2 / mask 1, so only the player↔collectible pair detects.

## Rules when editing here

1. Read a value from `ThemeManager` rather than hardcoding it.
2. Announce state changes via signals; let UI/feed-forward systems subscribe.
3. Keep functions small and typed. No silent crashes — degrade gracefully.
4. Do not introduce timers/spikes that make the game feel punishing.
