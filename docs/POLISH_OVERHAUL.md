# Polish Overhaul — "top-tier runner" pass

A code + data + tests pass to make Critter Dash feel like a polished App Store
endless runner, without touching the Kids-Category / COPPA guarantees. No art or
audio binaries, no iOS export, and no real IAP plugin are part of this (those are
editor/external-only); everything here is GDScript, `theme.json` data, and tests.

## What changed (by area)

- **Game feel / input** — data-driven swipe threshold + tap dead-zone, input
  buffering with an optional lane-change cooldown, a glowing/pulsing carried-colour
  badge, and opt-out gentle haptics.
- **Difficulty & pacing** — a warm-up grace period before the speed ramp; a
  data-driven spawn-pattern system (single / rest / double) that adds danger
  zones and guaranteed breathing room; a reward-only forgiveness window; object
  pooling for gems/cages.
- **Feedback & juice** — a new `ScreenFX` autoload (gentle flash / vignette /
  confetti), floating `+N` popups, a visible streak badge, near-miss "Whew!",
  a gentle stumble dim, and milestone + critter-unlock celebrations.
- **UI/UX** — screen fade-ins, button roles + press-pop + click sound, real
  toggle switches, a dimmed pause overlay, an in-run difficulty badge, and
  personal-best stats on Game Over.
- **Audio** — menu music, lane whoosh, near-miss/jingle SFX, a pause fade, and a
  master-volume control. All new entries are fail-soft theme keys.
- **Visuals (procedural, no art)** — distinct gem (glowing jewel) vs cage (ring)
  silhouettes, a gradient sky, a scrolling ground, and data-driven glow/camera.
- **Persistence** — settings autosave funnel, locale persistence, and local-only
  per-run best stats.

## Procedural scenery & characters (a later visual pass)

A second pass made the world look *complete* — still 100% procedural (no imported
art, no shaders), data-driven, and gentle:

- **Characters** — rescued critters are feature-assembled (body + head + eyes plus
  a deterministic set of ears/tail/fin/antennae/snout from the id hash, so each
  friend is distinct), and the **player** is a themed procedural silhouette
  (forest critter / space rocket / ocean sub) instead of a bare box — swapped in
  through the existing `.glb` seam so collision, bob/lean, and the carry badge are
  untouched.
- **Side scenery** (`core/Scenery.gd`) — pooled, scrolling trees / asteroids /
  coral down both sides; a **code invariant** clamps every prop to `|x| ≥ play_half`
  so it can never enter a travel lane.
- **Ambient particles** (`core/Ambient.gd`) — one cheap drifting field that follows
  the player: fireflies / stars / bubbles.
- **Atmosphere** — optional distance **fog** for depth + themed ambient/light
  tuning (`SkyRig`).
- **Lane markers** (`core/LaneMarkers.gd`) — dashed dividers on the lane
  boundaries, scrolling like racing stripes.

Guarantees these uphold (all test-asserted): (a) **reduce_motion** freezes/suppresses
every new motion & particle path while the static dressing and lane markers stay
drawn; (b) lane-exclusion + lane-clarity are **code invariants**; (c) **no art,
no shaders**; (d) **headless-safe** (no emission/render assumptions under `headless`).

## Compliance — still all green

These were design constraints on every change above, asserted by tests:

- **No data collection / no network** — `SaveManager` stays local-only; nothing
  new sends data.
- **No predatory monetization** — no currency, no loot boxes, no randomized paid
  rewards. The only purchase is still the single non-consumable "unlock all"
  behind the parental gate. The Game-Over screen has **no** purchase button
  (test-enforced).
- **No FOMO / dark patterns** — streaks, milestones, near-miss, and best-stats are
  celebration-only: they never gate content, never count down, and never nag you
  to come back. The streak resets silently (no shaming).
- **Gentle by design** — warm-up grace, a code-enforced "≥1 lane always clear"
  spawn invariant, reward-only forgiveness, and a capped, no-shake/no-strobe
  stumble dim. `reduce_motion` is honored by every new motion/particle/haptic path.

## Verifying

- `godot --headless --path . res://tests/Tests.tscn` → `TESTS: ALL PASS`.
- Press Play on `Main.tscn` in the Godot 4.3 editor for the feel-check
  (see the plan's verification checklist).
