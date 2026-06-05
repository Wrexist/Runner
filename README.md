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

## Status: playable scaffold ✅

The full engine is wired and runs with **placeholder box/sphere meshes** — press
Play and the loop works. What remains is **art/audio import** and **iOS export**,
which can only be done in the Godot editor (see below).

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
ui/
  HUD.gd / HUD.tscn    Signal-driven HUD: score, rescues, lives
  UIScreens.gd         Start / Game-Over / Parental-Gate / Shop (built from theme)
themes/                Pure data + art (see themes/CLAUDE.md)
  forest/theme.json    Default theme — "Forest Friends"
  space/theme.json     Reskin proof — "Star Rescue"
docs/                  Build plan + the Claude Code prompt sequence
PRIVACY.md             "Data Not Collected" policy for the App Store label
```

---

## Run it

1. Install **Godot 4.3 Standard** (not .NET) from <https://godotengine.org/download>.
2. Open this folder in Godot → press **Play** (runs `scenes/Main.tscn`).
3. **Desktop test (no phone needed):** use **←/→ arrow keys** to change lanes.
   On a device, **swipe** left/right.

**What you should see:** gems and cages scroll toward the player box. Grab a gem
to carry its color, then hit the same-color cage to rescue a critter (score +10,
🐾 counter rises). Hit an *unprepared* cage and you stumble (lose a ❤). Three
stumbles ends the run → Game Over → Shop (always behind the parental gate).

Switch the whole game to the other theme by setting
`ThemeManager.active_theme = "space"` — no other code changes needed.

---

## What still needs the Godot editor (Claude can't do these from text)

1. **Import art/audio.** Drop CC0 `.glb` / `.png` / `.ogg` from
   [kenney.nl](https://kenney.nl) / [quaternius.com](https://quaternius.com) into
   `themes/<id>/models|textures|audio/` and point the theme's `assets`/`audio`
   paths at them. Get the loop feeling right with gray boxes first.
2. **iOS export preset.** Project → Export → add iOS, set bundle id / team, wire
   the IAP plugin (the Shop's purchase is a marked `TODO(iap)` stub today), then
   TestFlight.

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
