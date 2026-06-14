# Critter Dash — Godot 4 Project

A gentle, lane-based **rescue runner** for kids. A **reskinnable engine**: one
set of logic driven entirely by per-theme JSON, so new games ship as new themes
+ art, not new code.

**The differentiator — the Rescue Run:** match a colored gem, then swipe into the
same-colored cage to **rescue** a critter (reward). Skip the gem and that cage is
a **hazard**. One object, two meanings, decided by your preparation.

> 👉 New here? Read [`CLAUDE.md`](CLAUDE.md) for the architecture and the
> non-negotiable Kids-Category compliance rules.

---

## Status: code-complete, content-pending ✅

The full engine, every front-end screen, accessibility, localization, and the
StoreKit IAP integration are wired and **covered by a headless test suite that
runs in CI** (`TESTS: ALL PASS`). It plays now with **placeholder box/sphere
meshes**. What remains can only be done in the Godot editor / on a Mac:
**art-audio import**, **iOS export & signing**, and the **on-device IAP**
(install the native plugin + create the App Store Connect product; the
integration code is already written and feature-detected). See
[`docs/HANDOFF.md`](docs/HANDOFF.md) for the exact next steps.

```
project.godot          Godot 4.3 config + autoloads (load order matters)
icon.svg               Placeholder app icon
core/                  Engine logic — never reskinned (see core/CLAUDE.md)
  GameCore.gd          Run state, score, difficulty ramp, gentle 3-stumble loss, signals
  ThemeManager.gd      Loads themes/<active>/theme.json — source of ALL tuning
  SaveManager.gd       Local-only save (COPPA-safe, no network ever)
  UIManager.gd         Front-end flow: start → run → game-over → gated shop
  Player.gd            Lane movement (swipe + arrow keys, no tilt) + carried color
  Spawner.gd           The Rescue Run hook: gem then matching-color cage, same lane
  Collectible.gd       Gem & cage behavior, scroll, area collision, rescue/stumble
scenes/                Gameplay scenes as text .tscn
  Main.tscn  Player.tscn  Gem.tscn  Cage.tscn
  IAP.gd               One non-consumable "unlock all" — real StoreKit, stub fallback
ui/
  HUD.gd / HUD.tscn    Signal-driven HUD: score, rescues, lives
  UIScreens.gd         Start / Game-Over / Pause / Settings / Album / Tutorial /
                       Parental-Gate / Shop / About (all built from theme data)
themes/                Pure data + art (see themes/CLAUDE.md)
  forest/theme.json    Default theme — "Forest Friends"
  space/theme.json     Reskin proof — "Star Rescue"
  ocean/theme.json     Third theme — "Reef Rescue" (data-only)
localization/          ui_strings.csv — en source + es (see docs/LOCALIZATION.md)
tests/                 Headless logic tests (run in CI) — Tests.gd / Tests.tscn
.github/workflows/     CI: theme-data validation + Godot headless tests
docs/                  Launch plan, asset manifest, handoff, review, prompts
PRIVACY.md             "Data Not Collected" policy for the App Store label
```

---

## Run it

1. Install **Godot 4.3 Standard** (not .NET) from <https://godotengine.org/download>.
2. Open this folder in Godot → press **Play** (runs `scenes/Main.tscn`).
3. **Desktop test (no phone needed):** use **←/→ arrow keys** to change lanes.
   On a device, **swipe** left/right.

**What you should see:** gems and cages scroll toward the player box over a
themed sky. Grab a gem to carry its color (sparkle + pickup sound), then hit the
same-color cage to rescue a critter — particle burst, a happy word floats up, the
score pops, and the rescued critter joins a **conga line that snakes behind you**.
A rescue streak makes the sounds and bursts grow. Hit an *unprepared* cage and you
gently stumble (lose a ❤). Three stumbles ends the run → Game Over → Shop (always
behind the parental gate).

Note: art/audio are placeholder geometry until you import CC0 assets, so the
"sounds" are silent until `theme.json` audio paths point at real `.ogg` files —
the audio system is wired and fail-soft, it just has nothing to play yet.

Switch the whole game to another theme by setting
`ThemeManager.active_theme = "space"` (or `"ocean"`) — no other code changes needed.

---

## Verify (headless, no display)

```bash
godot --headless --path . --import                 # compile/import: no SCRIPT/Parse errors
godot --headless --path . res://tests/Tests.tscn   # logic tests: "TESTS: ALL PASS"
godot --headless --path . --quit-after 120         # boots Main (audio-missing warnings expected)
```

The test suite covers the run loop, scoring, pause, game-over, save/unlocks,
difficulty, IAP (stub + StoreKit event handlers), screen builds, i18n catalog
coverage, and per-theme schema validation. CI runs all of it on every push.

---

## What still needs the Godot editor (Claude can't do these from text)

1. **Import art/audio.** Drop CC0 `.glb` / `.png` / `.ogg` from
   [kenney.nl](https://kenney.nl) / [quaternius.com](https://quaternius.com) into
   `themes/<id>/models|textures|audio/` at the paths the theme already names, then
   let Godot import them (open the editor once, or run `--import`). They load at
   runtime automatically — **no mesh-swapping or scene edits** (`core/ThemeModels.gd`).
   Until then the game runs on charming procedural placeholders.
2. **iOS export + IAP plugin.** Project → Export → add iOS, set bundle id / team,
   add the native `InAppStore` plugin (the StoreKit code in `core/IAP.gd` is
   written and waits for it), create the product in App Store Connect, then
   TestFlight. Bundle id is `com.critterdash.app`.

> 🚀 **Going to the App Store?** Follow [`docs/LAUNCH_PLAN.md`](docs/LAUNCH_PLAN.md)
> — a complete phased roadmap (accounts → art → playtest → QA → IAP → export →
> App Store Connect → TestFlight → review → launch), with store copy in
> [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md).

---

## Extending it

The [`docs/CLAUDE_CODE_PROMPTS.md`](docs/CLAUDE_CODE_PROMPTS.md) sequence drives
further work **one prompt → one test → one commit**. Helpful slash commands live
in `.claude/commands/` (`/new-theme`, `/compliance-check`, `/add-scene`), and a
`kids-compliance-auditor` subagent reviews changes against the Kids-Category rules.

## Compliance (do not skip)

No analytics, no network data collection, no behavioral ad targeting (COPPA). A
parental gate precedes any purchase/external link (Apple Kids). No loot boxes, no
pay-to-win — just one optional flat "unlock all" purchase. Full detail in
[`CLAUDE.md`](CLAUDE.md) and [`PRIVACY.md`](PRIVACY.md).
