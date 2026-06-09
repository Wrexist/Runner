# Pre-Content Health Check — Critter Dash

A whole-project review done before sinking time into art/audio (Phase 2). Scope:
every `.gd` file in `core/`, `ui/`, `tests/`; all `scenes/*.tscn`; theme data;
privacy manifest. Compliance was audited against the four non-negotiable Kids /
COPPA rules in `CLAUDE.md`.

**Bottom line:** the code/data layer is in strong, shippable-for-dev shape. One
real gameplay bug and a few polish items below; nothing blocks continuing to
Phase 2. The only hard blocker for *App Store submission* is the known IAP stub.

---

## Compliance (Kids Category / COPPA) — PASS on all four rules

| Rule | Verdict | Evidence |
|---|---|---|
| No data collection / network / local-only save | ✅ PASS | `SaveManager.gd` writes only `user://`; zero `HTTPRequest`/socket/SDK/`shell_open` in any `.gd`. No `addons/`. |
| No predatory monetization | ✅ PASS | `IAP.gd` — one non-consumable + Restore; Shop has only Unlock/Restore/Back; no currency/loot; streak is celebration-only. |
| Parental gate before Shop / links | ✅ PASS | `UIManager.gd` — the *only* path to `make_shop()` is `_open_shop_gated()`; reset is gated too; no outbound links exist. |
| Gentle by design | ✅ PASS | `GameCore.stumble()` — 3-stumble recovery, no instant game-over; smooth camera, no shake; auto-pause on focus loss; `reduce_motion` honored in Camera/Player/Effects. |

Privacy manifest (`ios/PrivacyInfo.xcprivacy`) and `PRIVACY.md` both declare no
tracking / no data collection, consistent with the code.

---

## Code health by area

- **Engine core** (`GameCore`, `ThemeManager`, `SaveManager`) — clean, typed,
  signal-driven, fail-soft. Save merges unknown keys forward; IAP entitlement
  survives `reset_progress()` (correct per App Store rules).
- **Gameplay** (`Spawner`, `Collectible`, `Player`) — collision layers/masks and
  `area_entered → _on_area_entered` wiring are correct in `Gem.tscn`/`Cage.tscn`;
  lane-x math matches between Spawner and Player; spawner avoids repeating a lane.
- **Juice/audio** (`Effects`, `Trail`, `AudioManager`) — all fail-soft; missing
  audio stays silent with a warning; particles/pops are gentle.
- **Scene wiring** (`Main.tscn`) — Spawner has both scenes assigned; Player, HUD,
  Trail, Camera, Sky all present.
- **Tests** — 9 logic suites + screen build, i18n catalog/coverage, and theme
  schema guards. `TESTS: ALL PASS`; clean headless boot.

---

## Findings

### 🟠 Should-fix

1. **Score-based critter unlocks are gated behind RNG — Album promise isn't
   literally true.** `core/Collectible.gd:77` rescues a *random* critter
   (`_pick_critter_id()`), and `core/GameCore.gd:106-108` only unlocks the
   critter that was randomly rescued *and* whose `unlock_score ≤ score`. So
   reaching the threshold (e.g. score 300 for "deer") does **not** unlock that
   critter until the RNG happens to surface it on a rescue. The Album shows
   "Reach 300" (`ui/UIScreens.gd`), implying deterministic unlocking.
   **Fix (small, safe, matches documented intent):** on score/rescue, unlock
   *every* critter whose `unlock_score ≤ score`, independent of which critter was
   rescued. Removes the RNG dependency and makes the Album hint truthful.

2. **Parental gate can be serial-tapped.** `ui/UIScreens.gd` ParentalGate shows
   3 answers (1 correct + 2 distractors) and re-rolls on a wrong tap with no
   delay, so tapping all three quickly always passes. Industry-standard math
   gates usually add a short (1–2 s) cooldown on a wrong answer. **Fix:** briefly
   disable the answer buttons after a wrong tap.

### 🟡 Nice-to-have

3. **Surface the privacy line / policy in About.** The About screen states "no
   tracking / no data," but the `PRIVACY.md` policy isn't referenced in-app.
   Showing the policy text (no tappable link needed) strengthens the submission.
4. **`Player.move_speed` (lane-slide feel) is hardcoded** at `Player.gd:11`.
   Everything else themeable lives in `theme.json`; consider moving this too for
   consistency (not required — it's a feel constant, not a per-theme need).
5. **Doc nit:** `Effects.gd` header says "Autoload Node3D children," but `Effects`
   extends `Node`. Behavior is correct (spatial nodes attach to the nearest
   viewport world); just tidy the comment.

### 🔴 Blocker — for App Store submission only (already known/documented)

6. **IAP is a local stub.** `core/IAP.gd:36` grants the unlock immediately
   (`TODO(iap)`), intentionally, so the flow is testable. Must be replaced with
   the real StoreKit plugin before submission — see `LAUNCH_PLAN.md` Phase 6.
   Does not affect development or TestFlight-internal testing.

---

## Recommended next actions

- Apply fixes **#1** and **#2** now (both small, safe, improve correctness/
  review-readiness; each gets a test). Optionally **#3–#5** as light polish.
- **#6** stays parked until the native plugin step (needs Xcode/account).
- Then proceed to **Phase 2** content with `docs/ASSET_MANIFEST.md`.
