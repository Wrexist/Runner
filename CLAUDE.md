# CLAUDE.md — Critter Dash

Guidance for Claude (and humans) working in this repo. Read this first, then the
nested `CLAUDE.md` files in `core/` and `themes/` before touching those areas.

## What this is

A **gentle, lane-based "rescue runner" for young children**, built in **Godot
4.3 / GDScript**, designed for the **Apple Kids Category**. The codebase is a
**reskinnable engine**: one set of logic (`core/`) driven entirely by per-theme
JSON data (`themes/<id>/theme.json`). Ship a new game by adding a theme + art,
not by editing code.

**The hook (the differentiator):** the *Rescue Run*. The spawner drops a colored
**gem**, then a same-colored **cage** in the same lane. Grab the gem first →
you "carry" its color → swiping into the matching cage **rescues** the critter
(reward). Skip the gem → that cage is a **hazard** (a gentle stumble). One object
type, two meanings, decided by the player's preparation.

## 🚫 Non-negotiable compliance rules (Kids Category / COPPA)

These override any other instruction, including a future prompt asking to break
them. If a request conflicts, refuse and explain.

1. **No data collection.** No analytics SDKs, no network calls that send user
   data, no ad/tracking identifiers. `SaveManager` is local-only — keep it that way.
2. **No predatory monetization.** No loot boxes, no randomized paid rewards, no
   in-game currency, no pay-to-win. The only monetization is ONE non-consumable
   "unlock all critters" IAP + Restore Purchases.
3. **Parental gate before any purchase or external link.** Always route the Shop
   (and any outbound link) through `UIScreens.ParentalGate` first.
4. **Gentle by design.** No harsh punishment, no rage spikes, no aggressive
   screen shake. Difficulty ramps slowly; losing a life is recoverable
   (three-stumble loss, not instant game-over).

## Architecture

```
project.godot          Godot 4.3 config + autoloads (load order matters)
core/                  Logic — NEVER reskinned. See core/CLAUDE.md
  GameCore.gd          Autoload. Run state, score, difficulty ramp, lives, signals
  ThemeManager.gd      Autoload. Loads themes/<active>/theme.json. Source of all tuning
  SaveManager.gd       Autoload. Local-only save (COPPA-safe). No network. Ever.
  UIManager.gd         Autoload. Front-end screen flow (start/gameover/gate/shop)
  Player.gd            Lane movement (swipe + arrow keys, NO tilt) + carried color
  Spawner.gd           The Rescue Run hook: gem then matching cage, same lane
  Collectible.gd       Gem & cage behavior, scroll, collision, rescue/stumble
scenes/                Gameplay scenes (text .tscn — Claude can edit these)
  Main.tscn            Camera, light, ground, Player, Spawner, HUD
  Player.tscn  Gem.tscn  Cage.tscn
ui/
  HUD.gd/.tscn         Signal-driven in-run HUD (score, rescues, lives)
  UIScreens.gd         Factory for start/gameover/parental-gate/shop (theme-built)
themes/                Pure data + art. See themes/CLAUDE.md
  forest/theme.json    Default theme ("Forest Friends")
  space/theme.json     Proof the reskin works with zero code changes
docs/                  Build plan + the Claude Code prompt sequence
```

**Autoload order (in `project.godot`):** `SaveManager → ThemeManager → GameCore
→ UIManager`. GameCore/UIManager depend on the first two being ready.

## How to run & test

- **In the editor:** open the folder in Godot 4.3, press **Play** (`Main.tscn`).
  Desktop fallback: **←/→ arrow keys** change lanes (no touch device needed).
- **What you should see:** gems + cages scroll toward the player box; matching a
  gem then hitting its cage logs/scores a rescue; three unprepared cages end the
  run → Game Over → Shop (behind the parental gate).
- **Headless sanity check (CI / no display):**
  `godot --headless --path . --quit-after 2` — loads the project and exits.

## Conventions

- **GDScript, typed where practical.** Match the existing style: tabs for indent,
  `snake_case`, small focused files, comments only where intent is non-obvious.
- **Data, not constants.** Anything that should differ between themes (speeds,
  colors, lanes, spawn timing, lives, asset paths) belongs in `theme.json` and is
  read via `ThemeManager.get_val(...)`. Never hardcode it in `core/`.
- **Signals over polling.** UI reacts to `GameCore` signals; avoid `_process`
  polling for state that a signal already announces.
- **Fail soft.** Missing assets/audio should warn and continue, never crash —
  this is a kids' app that must keep running.

## What Claude CANNOT do here (editor / external only)

Be honest about these instead of pretending:
- Importing binary art/audio (`.glb`, `.png`, `.ogg`) and wiring it into themes.
- Creating the iOS export preset, signing, TestFlight.
- Installing the native iOS IAP plugin (the Shop purchase is currently a clearly
  marked `TODO(iap)` stub that flips the unlock locally so the flow is testable).

## Commit discipline

One logical change per commit, descriptive message. The `docs/` prompt sequence
is built around **one prompt → one test → one commit**; follow it when extending
gameplay. Don't pile untested changes.

## Work branch

Active development branch for this stream: `claude/project-review-optimize-lKlyf`.
