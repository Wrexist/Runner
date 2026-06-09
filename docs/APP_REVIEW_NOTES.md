# App Store submission pack — copy/paste

Everything App Store Connect asks for at submission, pre-written and traceable to
the code. Fill the few `<…>` blanks. Kids Category (age band **5 & under**).

---

## App Review Information → Notes (paste verbatim)

```
Critter Dash is a gentle lane-based "rescue runner" for young children
(Apple Kids Category, ages 5 & under).

HOW TO PLAY (for the reviewer):
- Use ←/→ on a keyboard, or swipe / tap a side of the screen on device, to
  change lanes. Grab a colored gem to "carry" its color, then steer into the
  same-colored cage to rescue the critter inside (reward). Hitting a cage you
  did not prepare for is a gentle stumble; three stumbles ends the run.

PARENTAL GATE (Guideline 1.3 / 5.1.4):
- The only purchase and any non-gameplay action are behind a parental gate.
- To reach it: Start screen → "My Critters" → "Unlock All Critters", OR
  Settings → "Reset Progress". The gate asks a two-number addition question
  (e.g. "What is 7 + 8?"); a wrong answer briefly disables the buttons and
  re-rolls, so it cannot be brute-forced by tapping.

IN-APP PURCHASE:
- Exactly one Non-Consumable: "Unlock All Critters"
  (product id: com.critterdash.app.unlockall), plus Restore Purchases.
- No consumables, no currency, no loot boxes, no randomized paid rewards.
- To test: pass the parental gate to open the Shop, tap the unlock, then
  "Restore Purchases" to confirm restore works.

PRIVACY / DATA:
- No data collection of any kind. No analytics, no ads, no third-party SDKs,
  no network calls. All progress is saved locally on device only. This matches
  the "Data Not Collected" privacy label and PrivacyInfo.xcprivacy in the build.

CONTACT: <your email>
```

> **Before you submit for review:** the native StoreKit plugin must be wired so
> the purchase is real (currently a stub for internal TestFlight — see
> LAUNCH_PLAN Phase 6). A simulated purchase will be rejected under Guideline 2.1.

---

## Privacy "nutrition label" answers (App Store Connect → App Privacy)

- **Do you or your partners collect data from this app?** → **No.**
  (This single answer produces the "Data Not Collected" label. It is accurate:
  `SaveManager` writes only to `user://`; there are no SDKs or network calls —
  audited in `docs/REVIEW.md`.)
- **Privacy Policy URL:** `<host PRIVACY.md somewhere public, e.g.
  https://critterdash.app/privacy or a GitHub Pages URL>` — required field even
  though no data is collected.

## Age Rating questionnaire — expected answers
All content categories **None / No**: no violence (rescuing, not fighting), no
scary/mature themes, no profanity, no gambling/contests, no unrestricted web,
no user-generated content, no ads. Result should be **4+** / Kids 5 & under.

## App information you'll need (have ready)
- **Name:** Critter Dash   **Subtitle/promo/keywords:** see `docs/STORE_LISTING.md`
- **Bundle id:** `com.critterdash.app`   **SKU:** e.g. `critterdash-001`
- **Category:** Primary **Games**; this app targets the **Kids** age band.
- **Support URL** + **Marketing URL:** `<your URLs>`
- **Screenshots:** required sizes — 6.7" (1290×2796) and 6.5" (1242×2688) at
  minimum; capture from your iPhone running a TestFlight build (portrait).
- **IAP localized display name:** "Unlock All Critters"; **description:**
  "Unlock every critter forever — a single one-time purchase."

## TestFlight test plan (run on your iPhone each build)
1. Controls: swipe AND tap-a-side both change lanes; pause button works.
2. Audio plays; music loops with no audible click; nothing is harsh/loud.
3. Background the app mid-run → it auto-pauses; reopening → Resume.
4. Lose 3 times → gentle Game Over → "Play Again".
5. Parental gate: wrong answer disables buttons ~1.5s; correct opens the Shop.
6. IAP: buy → "All critters unlocked!"; delete + reinstall → Restore Purchases
   re-unlocks (sandbox account; only meaningful once the real plugin is wired).
7. Settings: Music/Sounds/Reduce-motion/Difficulty persist across relaunch.
8. Reduce Motion ON → bobbing/spins/particles stop; game still fully playable.

## Common Kids-Category rejection causes — already handled
- Simulated purchases → **wire the real plugin first** (the one open item).
- Gate bypassable by a child → gate re-rolls + disables on wrong answers.
- External links not behind a gate → there are **no** outbound links in the app.
- Data collection mismatch → none collected; label + manifest agree with code.
