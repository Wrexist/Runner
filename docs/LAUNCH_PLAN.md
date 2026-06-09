# Critter Dash — Complete Launch Plan (to the App Store)

Everything needed to take this from "verified, runnable engine" to "live in the
Apple **Kids** Category," organized as phases → steps with checkboxes, owners,
and exit criteria. Work top to bottom; each phase has a clear "done when."

## Owner legend
- 🤖 **Repo/code** — doable in this repository (GDScript, data, docs). Much is already done.
- 🖥️ **Editor/Mac** — requires the Godot 4.3 editor and/or a Mac with Xcode (binary assets, export, signing).
- 🍎 **Apple** — requires an Apple Developer account / App Store Connect.

## 🚦 Compliance gates (must hold at every phase — see CLAUDE.md)
- No data collection, no analytics, no network calls that send user data, no ad/tracking IDs.
- Exactly ONE non-consumable IAP ("unlock all critters") + Restore. No currency, loot boxes, or pay-to-win.
- Parental gate before any purchase or external link.
- Gentle by design: recoverable loss, gradual difficulty, no harsh punishment.
> If any task below conflicts with these, the gate wins.

---

## Status snapshot (already done & verified)
✅ Complete data-driven engine (core/ logic + themes/<id>/theme.json).
✅ Rescue-Run mechanic, gentle 3-stumble loss, slow difficulty ramp + Easy/Normal presets.
✅ Juice: audio (fail-soft), particles, rescue-trail conga line, camera, themed sky, score/streak feedback.
✅ Accessibility: visible carried color + redundant shape badges (color-blind), tap/swipe/keys, Reduce-Motion.
✅ Full screen flow: Tutorial (visual), HUD, Pause (+ auto-pause on backgrounding), Settings, Album, Game Over.
✅ Parental gate → single unlock-all Shop (behind the calm Album); IAP abstraction (`core/IAP.gd`) stubbed.
✅ Local-only save (COPPA-safe), lifetime stats, `PRIVACY.md`, `ios/PrivacyInfo.xcprivacy`.
✅ Headless logic tests + CI; project verified to compile/boot/pass tests on Godot 4.3.

What's left is mostly **🖥️ editor / 🍎 Apple** work, plus a little 🤖 polish. That's the rest of this document.

---

## Phase 0 — Accounts & tooling
**Goal:** be able to build and submit at all.
- [ ] 🍎 Enrol in the **Apple Developer Program** ($99/yr).
- [ ] 🖥️ A **Mac** with the latest **Xcode** installed (required to export/sign iOS).
- [ ] 🖥️ Install **Godot 4.3 Standard** and its **iOS export templates** (Editor → Manage Export Templates).
- [ ] 🍎 In App Store Connect, reserve the **app name** and create the App ID / bundle identifier (`com.critterdash.app`).
- [x] 🤖 Bundle id locked in: `core/IAP.gd` `PRODUCT_ID = com.critterdash.app.unlockall` (set the export preset to `com.critterdash.app`).

**Done when:** you can open the project in Godot and see an iOS export option.

---

## Phase 1 — Finish the code/data layer (🤖, small)
**Goal:** nothing code-shaped left before content.
- [x] 🤖 Engine, screens, accessibility, IAP abstraction, tests (done this stream).
- [x] 🤖 **Localization scaffolding** — all UI strings wrapped in `tr()`, catalog at `localization/ui_strings.csv` (en source + es), guide in `docs/LOCALIZATION.md`. Activating a locale is a 🖥️ editor import step.
- [x] 🤖 Set real `PRODUCT_ID` (`com.critterdash.app.unlockall`); `IAP.price_text()` will read the store price once the plugin is in.
- [x] 🤖 Add a short **Credits/About** screen (reachable from Start): version, "no ads / no tracking / no data" promise, Godot credit, and data-driven `credits[]` attribution per theme.

**Done when:** `godot --headless --path . res://tests/Tests.tscn` prints `TESTS: ALL PASS` and the game boots clean.

---

## Phase 2 — Art & audio (🖥️, the biggest external lift)
**Goal:** replace placeholder boxes/spheres with charming, kid-friendly assets — per theme, zero code changes.
**→ Exact shopping list (every file path + spec + CC0 source): [`docs/ASSET_MANIFEST.md`](ASSET_MANIFEST.md).**
- [ ] 🖥️ Source **CC0** low-poly models from kenney.nl / quaternius.com / poly.pizza:
      player, gem, cage, and 4 rescuable critters per theme.
- [ ] 🖥️ Source **CC0** audio (kenney.nl / freesound CC0): looping music, gem pickup, rescue, miss.
- [ ] 🖥️ Drop files into `themes/<id>/models|textures|audio/` at the paths the theme's `assets`/`audio` already name. **That's it** — `core/ThemeModels.gd` loads them at runtime (player, gems, cages, ground texture, and the rescue/Album critters), with procedural placeholders until then. No scene edits, no mesh-swapping.
- [x] 🤖 Models/textures auto-load fail-soft from theme paths (was a manual mesh-swap); rescue trail + Album already use the real critter models when present.
- [ ] 🤖 Keep `gem_palette`/`gem_symbols` honest: each gem color stays visually distinct AND shape-distinct.
- [ ] 🖥️ Design the **app icon** (1024×1024, no transparency, no rounded corners) and a launch screen.

**Compliance check:** no "creatures getting hurt" framing; cages = gentle rescue, never violence.
**Done when:** both themes look finished; audio plays; `godot --headless` still loads with no errors.

---

## Phase 3 — Game feel & real-kid playtest (🖥️)
**Goal:** it's *fun* and *fair* for ages 3–6, proven with real children.
- [ ] 🖥️ Tune `theme.json` `difficulty.easy/normal` after watching real play (speed, spawn pacing, `gem_cage_gap`).
- [ ] 🖥️ Playtest with **3–6 year-olds**; watch where they get confused (the tutorial, the color match).
- [ ] 🤖 Fold playtest findings back into tuning/tutorial copy (data + one screen — cheap to iterate).
- [ ] 🖥️ Verify the conga-line trail, particle bursts, and sounds feel delightful (and gentle in Reduce-Motion).

**Done when:** a first-time 4-year-old completes a rescue without help within a minute.

---

## Phase 4 — QA, devices & performance (🖥️)
**Goal:** rock-solid on the phones/tablets parents actually use.
- [ ] 🖥️ Test on a **range of iPhones/iPads** (oldest supported + newest, smallest screen + iPad).
- [ ] 🖥️ Confirm **portrait lock**, safe-area insets (notch/Dynamic Island), and large tap targets.
- [ ] 🖥️ Verify **auto-pause on backgrounding**, phone-call interruption, and audio-route changes.
- [ ] 🖥️ Check sustained-run **performance/heat/battery** (it's a runner — long sessions happen).
- [ ] 🖥️ Confirm 🐾/❤ glyphs render with your chosen font (swap to texture icons if the font lacks them).
- [ ] 🖥️ Full **screen-flow regression**: Start→Tutorial→run→Pause→Settings(all toggles, Reset behind gate)→Album→Shop(gate)→Restore→Game Over→Play Again.

**Done when:** no crashes, no soft-locks, smooth on the oldest target device.

---

## Phase 5 — Localization (🤖 scaffold + 🖥️ import)
**Goal:** sell globally; gameplay is already language-free, so this is UI strings + the store listing.
- [ ] 🤖 Externalize UI strings (they're centralized in `ui/UIScreens.gd`/`ui/HUD.gd`) via `tr()` keys.
- [ ] 🤖 Add `localization/strings.csv` (key,en,…) and register it in `project.godot`
      (`internationalization/locale/translations`).
- [ ] 🖥️ Let the editor import the CSV → `.translation`; verify languages switch.
- [ ] 🖥️ Translate at least the launch locales; keep UI icon-first for pre-readers regardless.
> Deferred intentionally so the verified build stayed stable; it's a contained change.

**Done when:** switching device language changes the UI; store listing localized for launch markets.

---

## Phase 6 — Monetization: the real IAP (🖥️ + 🍎)
**Goal:** turn the `core/IAP.gd` stub into a real StoreKit purchase. Implement the 3 `TODO(iap)` spots.
- [x] 🤖 **Integration code written** in `core/IAP.gd` against the `InAppStore` iOS
      singleton, **feature-detected**: `_ready()` inits + fetches product info,
      `price_text()` returns the store's localized price, `purchase_unlock_all()`
      / `restore()` drive the real plugin and an event-queue poller grants +
      finishes transactions. With no plugin present (desktop/CI) it falls back to
      the testable stub, so the build stays green. Still needs the 3 device steps below.
- [ ] 🍎 In App Store Connect, create ONE **Non-Consumable** IAP, id = `IAP.PRODUCT_ID`, set price tier, add a localized name/description, and a review screenshot.
- [ ] 🖥️ Install the **`InAppStore` Godot 4 iOS plugin** (godotengine/godot-ios-plugins) and add it to the iOS export. (Verify the event field names match `IAP.gd`'s defensive reads.)
- [ ] 🖥️ Test purchase **and** Restore with a **Sandbox** Apple ID (Restore is required by review).
- [ ] 🍎 Fill **Paid Apps / banking & tax** agreements (purchases won't work until active).

**Compliance check:** still exactly one non-consumable, gate precedes the buy button, Restore present.
**Done when:** a sandbox account can buy, see "All critters unlocked!", reinstall, and Restore.

---

## Phase 7 — iOS export, signing & on-device build (🖥️ + 🍎)
**Goal:** a signed `.ipa` that runs on a real device.
- [ ] 🖥️ Godot → Project → **Export → add iOS**: set bundle id, app name, version/build, **portrait** orientation, minimum iOS, team.
- [ ] 🖥️ Add the **app icon set** and **launch screen**; set the required iPhone/iPad icons.
- [ ] 🖥️ Bundle **`ios/PrivacyInfo.xcprivacy`** into the app (verify the required-reason API list against the final binary).
- [ ] 🍎 Create signing assets: App ID, distribution **certificate**, **provisioning profile** (or use Xcode automatic signing / your Fastlane Match setup).
- [ ] 🖥️ Export the Xcode project, build in **Xcode**, resolve any capability/entitlement prompts (In-App Purchase capability ON).
- [ ] 🖥️ Run on a **physical device** (not just simulator) — confirm input, audio, pause, IAP.

**Done when:** the signed build installs and plays on a real iPhone.

---

## Phase 8 — App Store Connect setup (🍎)
**Goal:** the app record is configured for the **Kids** Category.
- [ ] 🍎 Create the **app record**; set primary category **Games** and enable the **Kids** Category (pick the age band: 5 & under fits this game).
- [ ] 🍎 **Age rating** questionnaire: answer all "none" (no violence, no user-generated content, no web, no gambling).
- [ ] 🍎 **App Privacy** ("nutrition label"): declare **Data Not Collected** (matches `PRIVACY.md` + the manifest).
- [ ] 🍎 Add the **privacy policy URL** (host `PRIVACY.md` content somewhere public).
- [ ] 🍎 Confirm **no third-party SDKs**, no analytics, no ads (Kids Category forbids third-party ads/analytics that aren't kid-safe).
- [ ] 🍎 Pricing: free app + the single IAP; set availability/territories.

**Done when:** the Kids Category toggle is on and the privacy label says "Data Not Collected."

---

## Phase 9 — Store listing & ASO (🤖 draft → 🍎 enter, 🖥️ media)
**Goal:** a listing parents trust and find. Draft copy lives in `docs/STORE_LISTING.md`.
- [ ] 🤖 Draft **name, subtitle, promotional text, description, keywords** (see STORE_LISTING.md).
- [ ] 🖥️ Capture **screenshots** for required device sizes (6.7"/6.5" iPhone, 12.9" iPad) — show the rescue, the trail, the album.
- [ ] 🖥️ (Optional) Record a **15–30s App Preview** video.
- [ ] 🍎 Enter listing + upload media; localize listing for launch markets (Phase 5).

**Done when:** the product page reads clearly and the screenshots show the actual game.

---

## Phase 10 — TestFlight beta (🍎 + 🖥️)
**Goal:** catch real-world issues before public review.
- [ ] 🖥️ Upload the build to **TestFlight**; complete export-compliance (no non-exempt encryption).
- [ ] 🍎 Invite a few parent+kid testers; collect crash logs/feedback (TestFlight crash logs are not analytics).
- [ ] 🤖/🖥️ Fix anything found; bump build number; re-upload.

**Done when:** a clean TestFlight build with no crashes across testers.

---

## Phase 11 — Submit for review (🍎)
**Goal:** pass App Review the first time.
- [ ] 🍎 Attach the IAP to the version; provide **review notes** + a **demo of the parental gate** and how to reach/Restore the purchase.
- [ ] 🍎 Re-confirm the **Kids checklist**: parental gate before purchase/links, no third-party ads/analytics, no external links outside a gate, accurate privacy label.
- [ ] 🍎 Submit. If rejected, read the guideline cited, fix, resubmit (common Kids rejections: data collection, missing/parent-bypassable gate, links out, simulated purchases).

**Done when:** status = **Ready for Sale** (or set to manual release).

---

## Phase 12 — Launch & post-launch (🍎 + 🤖)
**Goal:** ship, support, and improve — without ever adding tracking.
- [ ] 🍎 Release (phased rollout is fine). Watch **App Store Connect** sales + crash reports (Apple-provided, no SDK).
- [ ] 🤖 Keep `CHANGELOG.md` current; use the `themes/` system to ship a **second game** as a reskin (the engine's whole point).
- [ ] 🤖 Address feedback via gentle, compliant updates (content, themes, polish) — never compulsion mechanics.
- [ ] 🍎 Respond to reviews; keep the privacy posture and Kids compliance intact on every update.

**Done when:** live, stable, and a reskin path proven.

---

## Quick reference — repo verification (run anytime)
```bash
godot --headless --path . --import                 # compile/import: expect no SCRIPT/Parse errors
godot --headless --path . res://tests/Tests.tscn   # logic tests: expect "TESTS: ALL PASS"
godot --headless --path . --quit-after 120         # boot Main: only fail-soft "audio not found" + a benign headless-renderer notice
```

## The three things only YOU can do (be honest about these)
1. **Art/audio import** and wiring (binary files — editor only).
2. **iOS export, signing, TestFlight** (Mac + Xcode + Apple account).
3. **The real IAP plugin** (native; the code seam is ready in `core/IAP.gd`).
