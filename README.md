# Critter Dash — Godot Project

A gentle, lane-based **rescue runner** for kids. Reskinnable engine.
Differentiator: the **Rescue Run** mechanic — match a colored gem, then swipe
into the same-colored cage to rescue a critter that joins your trail. One object
is both reward and hazard depending on your prep.

---

## What's built (and works as text/code)

```
project.godot          Godot 4 config, autoloads, portrait, mobile renderer
core/
  GameCore.gd          Run state, scoring, difficulty ramp, signals
  ThemeManager.gd      Loads theme.json -> fully reskinnable
  SaveManager.gd       Local-only save (COPPA-safe, no network)
  Player.gd            Lane movement (swipe/drag, no tilt) + carried-color
  Spawner.gd           The Rescue Run hook (gem -> matching cage)
  Collectible.gd       Gem & cage behavior, scroll, collision, rescue
themes/forest/
  theme.json           All tuning + asset paths for one skin
```

---

## STEP 1 — Install Godot (your Mac)

1. Download **Godot 4.3 Standard** (not .NET) from https://godotengine.org/download
2. It's a single app, no installer. Drag to Applications.
3. Open it → **Import** → select this `critter-dash` folder → it loads.

## STEP 2 — Things Claude Code CANNOT do for you (editor-only, ~30 min)

These need clicking in the Godot editor. There's no text-only path:

1. **Create the scenes** (`Main.tscn`, `Player.tscn`, `Gem.tscn`, `Cage.tscn`).
   In the editor: New Scene → add nodes below → attach the matching script →
   save into `scenes/`.
   - `Player.tscn`: `Node3D` (attach Player.gd) → child `MeshInstance3D` +
     `Area3D` with `CollisionShape3D`. Add Player to group **"player"**.
   - `Gem.tscn` / `Cage.tscn`: `Area3D` (attach Collectible.gd, set `kind`) →
     child `MeshInstance3D` + `CollisionShape3D`. Connect `body_entered`
     signal to `_on_body_entered`.
   - `Main.tscn`: `Node3D` → `Camera3D` (behind/above, angled down) →
     directional light → ground plane → Player instance → Spawner node
     (assign Gem.tscn and Cage.tscn to its exported fields in the Inspector).
2. **Import a 3D asset pack.** Download a free CC0 low-poly animal pack from
   **kenney.nl** or **quaternius.com**, drop `.glb` files into
   `themes/forest/models/`, then point `theme.json` asset paths at them.
3. **iOS export preset.** Project → Export → Add iOS → set bundle id, team.

> Use placeholder box meshes first. Get the loop working, THEN add art.
> Don't block yourself on assets — gray boxes prove the game.

## STEP 3 — Claude Code prompt sequence (run these in order)

1. "Generate `scenes/Player.tscn`, `Gem.tscn`, `Cage.tscn`, `Main.tscn` as Godot
   4 `.tscn` text files wired to the existing scripts, using BoxMesh placeholders."
2. "Add a HUD scene (`ui/HUD.tscn` + script) showing score and rescued-trail count,
   driven by GameCore signals."
3. "Add a start screen and game-over screen with a parental-gate before any
   purchase button (Apple Kids requirement)."
4. "Make rescued critters spawn and follow the player in a trailing conga line."
5. "Add a juice pass: tween pop on rescue, particle burst, audio hooks via theme.json."
6. "Wire the Godot iOS IAP plugin for a single 'unlock all critters' purchase
   that sets SaveManager.all_unlocked_iap."
7. "Write a second theme folder (`themes/space/`) with its own theme.json to
   prove the reskin works with zero code changes."

## Compliance reminders (don't skip)
- No analytics SDKs. No network calls collecting data. (COPPA)
- Parental gate before IAP / external links. (Apple Kids Category)
- No randomized boxes, no pay-to-win, no behavioral ad targeting.
- Consider shipping ad-free at one fixed price — cleaner review, better fit.

## Testing without a Mac build
Press **Play** in the Godot editor. Use arrow keys (left/right) to change lanes —
the keyboard fallback is built into Player.gd so you can test the loop on desktop
before any iOS export.
