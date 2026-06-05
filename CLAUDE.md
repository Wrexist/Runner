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
  GameCore.gd          Autoload. Run state, score, difficulty ramp, lives, streak, signals
  ThemeManager.gd      Autoload. Loads themes/<active>/theme.json. Source of all tuning
  SaveManager.gd       Autoload. Local-only save (COPPA-safe). No network. Ever.
  AudioManager.gd      Autoload. Themed music + SFX, fail-soft, respects sound toggles
  Effects.gd           Autoload. Gentle particle bursts + scale "pop" tweens (juice)
  UIManager.gd         Autoload. Front-end screen flow (start/gameover/gate/shop)
  Player.gd            Lane movement (swipe/tap/arrows, NO tilt) + lean + visible carried color
  Spawner.gd           The Rescue Run hook: gem then matching cage, same lane
  Collectible.gd       Gem & cage behavior, scroll, collision, rescue/stumble + juice + shape badge
  Trail.gd             Rescued critters snake behind the player (capped conga line)
  CameraRig.gd         Smoothed camera follow (subtle, no shake)
  SkyRig.gd            Themed world background + ambient light (reskins for free)
  Shapes.gd            Per-color primitive "symbol badges" (color-blind accessibility)
scenes/                Gameplay scenes (text .tscn — Claude can edit these)
  Main.tscn            Camera, light, ground, WorldEnvironment, Player, Trail, Spawner, HUD
  Player.tscn  Gem.tscn  Cage.tscn
ui/
  HUD.gd/.tscn         Signal-driven in-run HUD (score, rescues, lives, pause button)
  UIScreens.gd         Start / GameOver / Pause / Settings / Album / Tutorial /
                       ParentalGate / Shop — all built from theme data
tests/
  Tests.gd/.tscn       Headless logic tests for the core loop (run in CI)
themes/                Pure data + art. See themes/CLAUDE.md
  forest/theme.json    Default theme ("Forest Friends")
  space/theme.json     Proof the reskin works with zero code changes
docs/                  Build plan + the Claude Code prompt sequence
```

**Autoload order (in `project.godot`):** `SaveManager → ThemeManager → GameCore
→ AudioManager → Effects → UIManager`. Everything after the first two depends on
them being ready (AudioManager/UIManager subscribe to GameCore signals).

### Fun comes from "juice," not compulsion (important)

We make this game feel great the **legitimate** way — responsive controls,
particle bursts, a pickup/rescue sound that pitches up on a streak, rescued
critters that visibly follow you, score pops and happy floating words, smooth
camera. We do **NOT** build engagement-maximizing dark patterns aimed at kids
(variable-ratio rewards, FOMO/daily-streak pressure, currency pulls, "one more"
loops). The `streak` is celebration-only: it never punishes, never gates content.
This is both an ethics line and what keeps the app App-Store-approvable.

## How to run & test

- **In the editor:** open the folder in Godot 4.3, press **Play** (`Main.tscn`).
  Desktop fallback: **←/→ arrow keys** change lanes (no touch device needed).
- **What you should see:** gems + cages scroll toward the player box; matching a
  gem then hitting its cage logs/scores a rescue; three unprepared cages end the
  run → Game Over → Shop (behind the parental gate).
- **Headless sanity check (CI / no display):**
  `godot --headless --path . --quit-after 2` — loads the project and exits.
- **Headless logic tests:** `godot --headless --path . res://tests/Tests.tscn`
  (exits 0 if all pass, 1 on failure). These assert the core-loop rules without
  a display and run in CI. Add a case here when you change run/score/pause logic.

**Screen flow (UIManager):** Start → (Play; first ever → Tutorial) → run →
GameOver → (Play Again | My Critters). Pause overlay on the pause button or auto
on app backgrounding → Resume / Settings / Home. Settings + Album reachable from
Start. The single unlock-all Shop lives behind the Album and is ALWAYS gated by
the ParentalGate.

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
