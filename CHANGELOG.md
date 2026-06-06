# Changelog

All notable changes to Critter Dash. This project follows
[one logical change per commit](CLAUDE.md#commit-discipline).

## [Unreleased]

### Added
- **Complete, runnable engine.** Missing autoloads (`ThemeManager`, `SaveManager`,
  `UIManager`, `AudioManager`, `Effects`), gameplay scripts (`Player`,
  `Collectible`), `project.godot`, and all scenes (`Main`, `Player`, `Gem`,
  `Cage`, `HUD`) — the project now opens and plays with placeholder geometry.
- **Gentle game loop.** Three-stumble recoverable loss (was: nothing ever ended
  a run); slow difficulty ramp; celebration-only rescue streak.
- **Juice pass.** Themed music + fail-soft SFX (pitch climbs with the streak),
  gentle particle bursts, rescued-critter conga-line trail, smooth camera follow,
  themed sky, player lean, score pops, floating praise words.
- **Accessibility.** Carried color is shown on the player (tint + shape badge);
  every gem/cage carries a redundant primitive **shape** so play never depends on
  hue alone (color-blind support). Tap-a-side-to-move for tiny hands.
- **Screens.** First-run **visual** tutorial (shapes/colors, not text — usable by
  pre-readers), Settings (music/sfx + Easy/Normal difficulty), Pause (+ auto
  pause on app backgrounding), Critter Album, New-Best celebration.
- **Easy/Normal difficulty presets** (theme data, default Easy for ages 3–6:
  flat speed, slower start, wider reaction window), chosen in Settings.
- **Compliance surfaces.** Parental gate (retries in place on a wrong answer) is
  the only path to the single unlock-all Shop, which lives behind the calm Album
  rather than the loss moment. `PRIVACY.md` ("Data Not Collected").
- **Reskinnability.** Gem colors/symbols and the gem→cage gap are theme data now;
  second `space` theme proves zero-code reskin. Lifetime progress stats.
- **Launch-readiness.** `core/IAP.gd` abstraction (single seam for the real
  StoreKit plugin), Reduce-Motion + parent-gated Reset-Progress settings,
  `ios/PrivacyInfo.xcprivacy` (Apple privacy manifest), and a full
  `docs/LAUNCH_PLAN.md` (phased App Store roadmap) + `docs/STORE_LISTING.md`.
- **Tooling.** Root + nested `CLAUDE.md`, `.claude/` (SessionStart hook, slash
  commands, compliance subagent), `.gitignore`, MIT `LICENSE`, GitHub Actions CI
  (theme-JSON validation, headless project load, **headless logic tests**).

### Fixed
- Crash on first rescue (dot-access on JSON-parsed Dictionaries → `.get()`).
- `seen_tutorial` was saved but never loaded (tutorial re-showed every launch).
- Post-death score bump (now `add_score`/`rescue_critter` are guarded).
- Stale visuals (carried color, trail, in-flight collectibles, paw counter) on
  abandon-to-menu and between runs.
- HUD lingering on menus (now hides off-run); parental-gate brute-force hardening.

> Editor-only work remaining (cannot be done from text): import CC0 art/audio,
> create the iOS export preset, and wire the native IAP plugin (currently a clearly
> marked `TODO(iap)` stub).
