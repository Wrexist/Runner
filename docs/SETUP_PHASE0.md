# Phase 0 — Accounts & Tooling (runbook)

Concrete, checkable steps with your real identifiers filled in. Repo-side items
are done; the rest need your Apple account / Mac. See `docs/LAUNCH_PLAN.md` for
the full journey.

## Your project identifiers (locked)
| Thing | Value |
|---|---|
| App display name | **Critter Dash** |
| Bundle identifier (App ID) | **`com.critterdash.app`** |
| IAP product id (non-consumable) | **`com.critterdash.app.unlockall`** |
| Min iOS target (suggested) | iOS 14+ |
| Orientation | Portrait |
| Category | Games → **Kids** (age band 5 & under) |

> Repo: `core/IAP.gd` `PRODUCT_ID` is already set to the IAP id above. ✅

## A. Apple Developer account  🍎
- [ ] Enrol in the **Apple Developer Program** (`https://developer.apple.com/programs/`, $99/yr). Individual or Organization both fine; Kids Category is allowed for both.
- [ ] Accept the latest **Program License Agreement** in App Store Connect.
- [ ] (Before IAP works) complete **Agreements, Tax, and Banking** → "Paid Apps" agreement active.

## B. Mac & build tools  🖥️
- [ ] A **Mac** running a current macOS.
- [ ] Install **Xcode** from the Mac App Store, then open it once to install command-line tools and accept its license.
- [ ] Install **Godot 4.3 (Standard)** from `https://godotengine.org/download`.
- [ ] In Godot: **Editor → Manage Export Templates → Download and Install** (this pulls the iOS templates — required to export).

## C. Create the App ID & app record  🍎
- [ ] App Store Connect → **Apps → +** → New App.
      - Platform: iOS · Name: `Critter Dash` · Primary language · Bundle ID: create/select **`com.critterdash.app`** · SKU: any (e.g. `critterdash-001`).
- [ ] In the bundle ID's **Capabilities**, enable **In-App Purchase** (usually on by default).
- [ ] Reserve the name now even if you submit later (names are first-come).

## D. Open the project & confirm it runs  🖥️
- [ ] Open this folder in Godot 4.3 → press **Play** (`scenes/Main.tscn`). Use ←/→ (or tap/swipe) — confirm the loop.
- [ ] Sanity (optional, headless): `godot --headless --path . res://tests/Tests.tscn` → `TESTS: ALL PASS`.

## E. iOS export preset — values to enter (you'll use these in Phase 7)  🖥️
Project → **Export → Add… → iOS**, then set:
- **App Store Team ID:** (from your Apple Developer account)
- **Bundle Identifier:** `com.critterdash.app`
- **Display Name:** `Critter Dash`
- **Version / Build:** `1.0` / `1`
- **Orientation:** Portrait
- **Required icons & launch screen:** add in Phase 2 (art) / Phase 7.
- **Privacy manifest:** bundle `ios/PrivacyInfo.xcprivacy` (already in the repo).
- **Capabilities:** In-App Purchase ON.

## Exit criteria (Phase 0 done when…)
- ✅ Apple Developer account active.
- ✅ Xcode + Godot 4.3 + iOS export templates installed.
- ✅ App record created in App Store Connect with bundle id `com.critterdash.app`.
- ✅ The project opens in Godot and plays.

**Next:** Phase 2 (art & audio) is the biggest lever on "feels finished" — start
sourcing CC0 models/audio while the account/agreements process. Phase 1's
optional polish (localization scaffolding, Credits screen) can be done in the
repo in parallel.
