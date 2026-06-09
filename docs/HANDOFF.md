# Handoff — where Critter Dash stands & what's next

A pickup point after the "project review & optimize" stream. The **code/data
layer is complete and CI-green**; everything remaining genuinely needs the
editor, binary art, or an Apple account — i.e. it's your side now.

Branch: `claude/project-review-optimize-lKlyf`.

---

## ✅ Done (this stream)

- **Identifiers locked:** bundle `com.critterdash.app`, IAP `com.critterdash.app.unlockall` (`core/IAP.gd`).
- **About / Credits screen** — version, a plain "no ads / no tracking / nothing
  leaves this device" privacy promise, Godot credit, and data-driven `credits[]`
  attribution per theme.
- **Localization** — every UI string routed through `tr()`; catalog at
  `localization/ui_strings.csv` (English source + full Spanish). English is
  byte-for-byte unchanged until a locale is imported. Guide: `docs/LOCALIZATION.md`.
- **CI guards** (run on every push/PR via `.github/workflows/ci.yml`):
  - i18n **coverage** — every `tr("…")` literal must exist in the catalog.
  - **theme schema** — auto-discovers every `themes/<id>/` and validates keys,
    `res://` paths, distinct color-blind gem symbols, and a free starter critter.
- **Third theme `ocean`** ("Reef Rescue") — data-only, proving the reskin path a
  second time (validated by CI with zero test changes).
- **Compliance audit** — PASS on all four Kids/COPPA rules (`docs/REVIEW.md`).
- **Two real bugs fixed** (each with a test):
  - critter unlocks are now **deterministic** (reach the score → unlocked), not RNG-gated.
  - parental gate **can't be serial-tapped** (answers lock ~1.5 s after a wrong tap).
- **Docs added:** `SETUP_PHASE0.md`, `ASSET_MANIFEST.md`, `CREDITS.md`,
  `LOCALIZATION.md`, `REVIEW.md`, this file.

**State:** `godot --headless --path . res://tests/Tests.tscn` → `TESTS: ALL PASS`;
clean headless boot.

---

## ▶️ What YOU do next (in order)

### 1. Phase 0 — accounts & tooling  → `docs/SETUP_PHASE0.md`
Apple Developer Program; install Xcode + Godot 4.3 + iOS export templates;
create the App Store Connect record for `com.critterdash.app`; open the project
and press Play.

### 2. Phase 2 — art & audio (biggest lever)  → `docs/ASSET_MANIFEST.md`
Source **CC0** models/audio (Kenney, Quaternius, Poly Pizza). Exact file list,
paths, and specs are in the manifest. Log each asset in `docs/CREDITS.md` as you go.
- **Minimum to ship: the Forest 12 files.** Space + Ocean are free "new world" updates.

### 3. Then come back to me 🤖
With assets in the repo I can: swap the placeholder meshes in
`scenes/Player.tscn` / `Gem.tscn` / `Cage.tscn`, point trail/album at real
critter models, fill each theme's `credits[]`, and (optional) import the
localization CSV + add an in-game language picker.

### 4. Phases 6–11 — IAP, export, TestFlight, submit  → `docs/LAUNCH_PLAN.md`
The **one remaining code blocker** is the real StoreKit IAP: `core/IAP.gd` has
three `TODO(iap)` seams where the stub grants the unlock locally. Wire a Godot 4
iOS IAP plugin there before submission (needs Mac + account).

---

## Quick verification (run anytime)
```bash
godot --headless --path . --import                 # no SCRIPT/Parse errors
godot --headless --path . res://tests/Tests.tscn   # "TESTS: ALL PASS"
godot --headless --path . --quit-after 120         # boots Main (audio-missing warnings are expected)
```

## The three things only you can do
1. Import binary art/audio and wire it into themes (editor).
2. iOS export, signing, TestFlight (Mac + Xcode + Apple account).
3. The real IAP plugin (native; the seam is ready in `core/IAP.gd`).
