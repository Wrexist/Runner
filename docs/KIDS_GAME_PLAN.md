# Reskinnable Kids' Game — Build Plan (Godot, iOS-first)

> **Governing rule (non-negotiable):** This is a Kids Category app. Every decision is filtered through Apple's *Kids* guidelines, COPPA, and the UK/EU age-appropriate design codes. No behavioral nudging, no loot boxes, no pay-to-win, no behavioral ad targeting. Repeatability and unlockables come from *skill and content*, not compulsion loops. Breaking this rule = rejection or account flag.

---

## 1. Strategy: build the engine, not the game

Your real asset is a **reskinnable core**. Build one clean engine, then ship multiple themed games from it with new art, sound, and config — no logic rewrites. This is exactly the engine/store/UI separation pattern you already use elsewhere.

```
GameCore (logic, never reskinned)
  ├── ThemeConfig (JSON: art paths, palette, sounds, strings, difficulty curve)
  ├── ContentPacks (unlockables: characters, skins, sound sets)
  └── Skins/<theme>/ (3D models, textures, audio, icons)
```

To make a new game: duplicate `Skins/`, write a new `ThemeConfig.json`, rebuild. That's the whole reskin.

---

## 2. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Engine | **Godot 4.x** | `.tscn` scenes are text → Claude Code can build scenes, not just scripts |
| Language | **GDScript** | Native, fastest to iterate; Claude writes it well |
| 3D assets | **Kenney.nl**, **Quaternius**, **Poly Pizza** | Free, CC0, low-poly, kid-friendly, tiny file size |
| Audio | **Kenney audio packs**, **Freesound (CC0)** | Free, clean, no licensing traps |
| Monetization | **Godot IAP plugin** (one-time purchases) | No randomized boxes |
| Ads (optional) | **AdMob via `godot-admob-ios`**, child-directed config | Non-coercive only |
| Analytics | **Minimal / none for kids** | COPPA restricts data collection from minors |
| CI | GitHub Actions (export templates) | Fits your existing setup |

**Free 3D asset libraries (all usable commercially, attribution varies):**
- Kenney.nl — the gold standard for low-poly game kits, CC0
- Quaternius — free low-poly model packs, CC0
- Poly Pizza — searchable free 3D model directory
- Sketchfab — filter by "Downloadable" + CC license (check each)

---

## 3. Compliant "fun" — what replaces the addiction layer

| You asked for | Compliant version that ships |
|---|---|
| Maximize dopamine / addictive | **Game feel ("juice")**: responsive controls, particle bursts, satisfying sound, screen shake, reward animations. Legitimate craft, not compulsion. |
| Infinite repeatability | **Procedural levels** + score chasing + skill mastery. Replayable because it's *fun to get better*, not because of a Skinner box. |
| Unlockable characters/sounds | **Earned through play** (score milestones) **or** one-time cosmetic IAP. No randomized unlocks. |
| In-game currency, pay-to-win | ❌ Cut. Replace with: one-time "unlock everything" IAP + optional cosmetic packs. Fair, flat, parent-friendly. |
| Loot boxes / packs | ❌ Cut entirely. Banned in Kids Category. |
| Rewarded ads for coins | If used at all: kid-safe AdMob config, optional, never gating core progression. Honestly — consider shipping ad-free and charging $2.99. Cleaner, better reviews, fits your one-time-purchase preference. |

**Recommended monetization model:** free to play core loop, single $2.99–$4.99 IAP to unlock all characters/themes + remove any ads. This is the model that passes review *and* respects the parents who actually hold the credit card.

---

## 4. Reskinnable core loop (genre-agnostic)

Every concept below shares this skeleton, so the engine is built once:

1. **Tap/swipe/tilt input** → simple, one-handed, no reading required
2. **Procedural obstacle/target generation** → infinite content
3. **Score + escalating difficulty** → mastery curve
4. **Collect/avoid feedback** → juice (sound + particle + animation)
5. **Run ends → reward screen** → progress toward next unlock
6. **Unlock screen** → characters/skins/sounds (earned or IAP)

`GameCore` implements all six. Each theme just swaps what the "target," "obstacle," and "character" *look and sound like*.

---

## 5. The 10 concepts (ranked, with honest assessment)

Ranked by **fit for: reskinnability + kid-appeal + buildability in Godot by a CLI-first dev**.

### Tier 1 — build one of these first

**1. Endless Runner ("Critter Dash")**
- *Loop:* character auto-runs, swipe to dodge/jump/collect. Procedural track.
- *Unlocks:* 12+ animal characters, trail effects, biome skins.
- *Reskins as:* space, jungle, ocean, candy world — same code.
- *Why #1:* maximally reskinnable, dead-simple input, infinite by design, huge proven kid appeal. Low-poly asset packs exist for exactly this.
- *Risk:* crowded genre. Differentiate on charm + polish, not mechanics.

**2. Tap-to-Stack ("Tower Tumble")**
- *Loop:* tap to drop blocks/animals, stack as high as possible. Physics.
- *Unlocks:* block themes, character toppers, background worlds.
- *Why high:* Godot physics makes this trivial; satisfying juice; truly endless.
- *Risk:* shallow; needs strong feel to stand out.

**3. Match-3 Lite ("Bubble Friends")**
- *Loop:* match colored 3D orbs/creatures. No timers (kid-friendly).
- *Unlocks:* orb skins, board themes, character cheer animations.
- *Why high:* infinite levels, gentle, very reskinnable.
- *Risk:* match-3 is saturated and often where predatory monetization lives — keep yours clean and it'll stand out *because* it's clean.

### Tier 2 — strong but more work

**4. Whack-a-Mole 3D ("Pop Pals")** — tap creatures popping from holes. Easy, juicy, reskinnable. Risk: very simple, short session appeal.

**5. Maze Collector ("Maze Munchers")** — tilt/swipe a character through procedural mazes collecting items. Risk: tilt controls frustrate small kids; offer swipe fallback.

**6. Rhythm Tapper ("Beat Buddies")** — tap to the beat, characters dance. Great juice, strong unlock hook (sound sets!). Risk: audio sync is fiddly in Godot; rhythm games are harder than they look.

**7. Feed-the-Pet ("Hungry Hatchlings")** — flick/drop correct food to creatures. Teaches matching. Risk: thin loop without clever escalation.

### Tier 3 — interesting but riskier for a first build

**8. Bubble Shooter 3D** — aim and pop. Reskinnable, infinite. Risk: aiming is hard for under-5s.

**9. Slice-It ("Fruit Friends")** — swipe to slice flying objects. Very juicy. Risk: "slicing" + kids can read as mildly violent to some reviewers; keep it fruit/jelly, never creatures-getting-hurt.

**10. Color-Sort Puzzle ("Rainbow Sort")** — sort 3D objects by color into bins. Calm, educational, easy. Risk: lowest "excitement," but lowest risk and genuinely good for youngest kids + parents.

---

## 6. Recommended pick

**Start with #1 (Critter Dash) or #2 (Tower Tumble).** Both are the most reskinnable, the most buildable in Godot via Claude Code, and the most proven with kids. Tower Tumble is the *faster* first ship (physics does the work); Critter Dash has the *higher* ceiling and reskin value. Given you want a reskinnable engine specifically, Critter Dash teaches the engine more.

---

## 7. Build sequence (for Claude Code, Godot project)

1. **Scaffold** — Godot 4 project, folder structure, `GameCore` autoload singleton, `ThemeConfig.json` loader.
2. **Input layer** — abstracted (tap/swipe/tilt) so themes can choose.
3. **Procedural generator** — obstacle/target spawner driven by config difficulty curve.
4. **Core loop** — run start → play → fail → reward, fully data-driven.
5. **Juice pass** — particles, tweens, screen shake, audio hooks (the "fun").
6. **Unlock system** — earned (score milestones) persisted locally (no server, no data collection).
7. **First theme** — wire one Kenney/Quaternius asset pack as `Skins/theme_a/`.
8. **IAP** — single "unlock all" purchase via Godot iOS IAP plugin.
9. **(Optional) Ads** — `godot-admob-ios`, child-directed treatment, non-gating.
10. **Settings/parental gate** — Apple requires a parental gate before any purchase or external link in Kids apps.
11. **iOS export + TestFlight** — export templates, signing (reuse your Fastlane Match setup).
12. **Reskin test** — duplicate theme, prove a second game ships from the same core.

Each step = one commit, your usual discipline.

---

## 8. Compliance checklist before submission

- [ ] No third-party analytics SDKs that collect from minors (COPPA)
- [ ] Parental gate before IAP, ads, or any external link
- [ ] AdMob (if used) set to child-directed + restricted ad content
- [ ] No loot boxes, no randomized rewards for money, no pay-to-win
- [ ] Privacy policy + correct App Store "Data Not Collected" declaration
- [ ] Age rating set correctly; opted into Kids Category if targeting under-13
- [ ] No links out, no social features, no cross-promotion to non-kids apps

---

## 9. The one thing most likely to sink this

Not the code — the **Kids Category compliance**. Solo devs get rejected here repeatedly because they bolt monetization on first and discover the rules last. Build clean from step 1. The good news: a clean kids' game with real polish and a fair one-time price has *less* competition than the predatory pile, and parents actively seek it out. That's your edge, not a constraint.
