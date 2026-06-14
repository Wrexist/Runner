# Critter Dash — Claude Code Prompt Sequence

**How to use this:** Open the `critter-dash` folder in Claude Code (with Opus).
Run ONE prompt. Test in the Godot editor. Commit. Then run the next.
Do **not** batch prompts — if something breaks you want to know which step did it.

**Before prompt 1:** make sure `git init` is done and the scaffold files are committed,
so the model has a clean baseline and you can roll back.

---

## Context primer (paste ONCE at the start of the session)

```
You are working inside a Godot 4.3 project called Critter Dash — a gentle,
lane-based "rescue runner" game for young children (Kids Category on the App Store).

Architecture already built in /core (read these files before doing anything):
- GameCore.gd     : autoload. Run state, scoring, difficulty ramp, signals
                    (run_started, run_ended, score_changed, critter_rescued).
- ThemeManager.gd : autoload. Loads themes/forest/theme.json. ALL tuning and
                    asset paths come from theme.json — never hardcode them.
- SaveManager.gd  : autoload. Local-only save. NEVER add network calls or analytics.
- Player.gd       : lane movement via swipe/drag (NO tilt). Has carry_color/
                    carried_color/clear_color for the rescue mechanic.
- Spawner.gd      : spawns a colored gem then a matching-color cage in the same lane.
- Collectible.gd  : gem & cage behavior. Grab matching gem then hit cage = rescue.

Hard rules (Kids Category compliance — do not violate even if asked):
1. No analytics SDKs, no network data collection, no behavioral ad targeting.
2. No loot boxes, no randomized paid rewards, no pay-to-win currency.
3. A parental gate must appear before any purchase button or external link.
4. Gentle difficulty — no harsh punishment, no rage-inducing spikes.

Style: GDScript, typed where practical, small focused files, comments only where
non-obvious. Read existing files and match their conventions before writing new code.

Confirm you've read the /core files and understood the rescue mechanic before we start.
```

---

## Prompt 1 — Scenes with placeholder geometry

```
Create these as Godot 4.3 .tscn text files, wired to the existing scripts,
using BoxMesh/SphereMesh placeholders (NO external assets yet):

- scenes/Player.tscn: Node3D with Player.gd attached. Child MeshInstance3D
  (a small BoxMesh) and an Area3D + CollisionShape3D (BoxShape3D). Put the
  root in group "player". The Area3D is what Collectibles detect.
- scenes/Gem.tscn: Area3D with Collectible.gd attached, kind = "gem".
  Child MeshInstance3D (SphereMesh) + CollisionShape3D. Connect the Area3D's
  body_entered signal to _on_body_entered. NOTE: gems/cages are Area3D and the
  player has an Area3D — check whether we need area_entered instead of
  body_entered and fix the collision approach so detection actually fires.
  Explain what you changed and why.
- scenes/Cage.tscn: same as Gem but kind = "cage", use a BoxMesh.
- scenes/Main.tscn: Node3D root with: Camera3D positioned behind and above the
  player looking down the track (-Z is forward), a DirectionalLight3D, a large
  ground plane (PlaneMesh), an instance of Player.tscn at origin, and a Spawner
  node (Spawner.gd) with Gem.tscn and Cage.tscn assigned to its exported fields.

After creating them, tell me exactly what to click "Play" on and what I should
see, and list anything you were unsure about. Then stop.
```

**Test:** Press Play. You should see boxes scrolling toward a player box.
Arrow keys change lanes. Commit: `feat: placeholder scenes + working loop`.

---

## Prompt 2 — Fix collision detection properly

```
Now that scenes exist, verify the rescue mechanic actually triggers. Player has
an Area3D; gems/cages are Area3D. Make collision detection reliable: set up the
correct signal (area_entered vs body_entered), collision layers, and masks so
that ONLY the player detects collectibles and detection fires every time.
Update Collectible.gd and the .tscn files as needed. Explain the layer/mask setup
in a comment. Then tell me how to verify a rescue prints to the console. Stop.
```

**Test:** Grab a gem (matching color), hit the same-color cage → console logs a
rescue. Commit: `fix: reliable area collision for rescue mechanic`.

---

## Prompt 3 — HUD

```
Create ui/HUD.tscn + ui/HUD.gd as a CanvasLayer. Show: current score (top center,
large, readable for kids) and a rescued-trail counter with a small icon. Drive it
ENTIRELY from GameCore signals (score_changed, critter_rescued) — no polling in
_process. Pull text color from ThemeManager.color("ui_text"). Add HUD as a child
of Main.tscn. Then stop and tell me what to verify.
```

**Test:** Score and rescue count update live. Commit: `feat: signal-driven HUD`.

---

## Prompt 4 — Start screen, game-over, parental gate

```
Create ui/StartScreen.tscn and ui/GameOver.tscn (+ scripts).
- StartScreen: title, a big Play button (calls GameCore.start_run()), and a small
  high-score readout from SaveManager.high_score.
- GameOver: shows final score, "new best!" if is_high (from run_ended signal),
  rescued count this run, a Play Again button, and a "Shop" button.
- Parental gate: create ui/ParentalGate.tscn — a simple math/hold-button gate
  ("Ask a grown-up: tap and hold for 3 seconds" or a single-digit math question).
  This MUST appear before the Shop/any purchase opens. Wire the Shop button to
  show the gate first.
Manage screen flow from Main.tscn or a small UIManager — your call, explain it.
Then stop and tell me the flow to test.
```

**Test:** Play → die → game over → Shop → parental gate appears first.
Commit: `feat: menus + parental gate before shop`.

---

## Prompt 5 — Rescued critters follow in a trail

```
When a critter is rescued, spawn a small placeholder mesh that follows the player
in a trailing conga line (each follower trails the one ahead with a short delay/
smoothing, like Snake). Cap the visible trail length for performance (e.g. 12) but
keep counting beyond that. Use the critter id from the rescue. Keep it smooth and
cheap. Then stop and tell me what to verify.
```

**Test:** Rescues add followers that snake behind you. Commit: `feat: rescue trail`.

---

## Prompt 6 — Juice pass (the "fun")

```
Add game feel WITHOUT changing core logic:
- Rescue: a quick scale-pop tween on the rescued critter + a small particle burst.
- Gem pickup: subtle sparkle + pitch-up pickup sound.
- Lane change: tiny tilt/lean on the player mesh that settles back.
- A gentle camera follow with slight smoothing.
Route all audio through theme.json paths via ThemeManager. If an audio file is
missing, fail silently (don't crash). Keep it tasteful and kid-soft — no harsh
screen shake. Then stop and tell me what to verify.
```

**Test:** Everything feels responsive and soft. Commit: `feat: juice + audio hooks`.

---

## Prompt 7 — One-time IAP ("unlock all critters")

```
Wire a SINGLE non-consumable in-app purchase that unlocks all critters by setting
SaveManager.all_unlocked_iap = true and saving. Use the Godot iOS IAP plugin
approach (research the current plugin and StoreKit integration for Godot 4 first;
tell me which plugin and how to install it). The Shop screen (behind the parental
gate) shows ONE clearly-priced button + a Restore Purchases button. No currency,
no packs, no randomization. If the plugin isn't installed yet, stub the purchase
behind a clear TODO and a test toggle so I can verify the unlock flow now, and
give me the exact install steps for the real plugin. Then stop.
```

**Test:** Purchase (or test toggle) flips all_unlocked_iap and persists.
Commit: `feat: single unlock-all IAP + restore`.

---

## Prompt 8 — Prove the reskin (second theme)

```
Create themes/space/theme.json and a themes/space/ folder mirroring forest, with
different palette, names, speeds, gem colors, and rescuable critter ids — but
reusing placeholder meshes for now. Change ThemeManager.ACTIVE_THEME to space,
run, and confirm the game reskins with ZERO changes to any /core or /scenes code.
If anything required a code change to reskin, that's a bug in our data-driven
design — fix it so themes are pure data. Report what (if anything) you had to fix.
Then stop.
```

**Test:** Switching the theme constant changes the whole game, no code edits.
Commit: `feat: second theme proves reskinnable engine`.

---

## After the sequence — your editor + asset work
- Replace BoxMesh placeholders with free CC0 .glb models (kenney.nl / quaternius.com).
- Set up the iOS export preset, signing (reuse your Fastlane Match setup), TestFlight.
- Playtest with an actual child before polishing further. Watch where they get
  confused — that's your real backlog, not your own assumptions.

## A note on prompt discipline
If the model produces a big diff that "should work," resist running the next
prompt until you've actually pressed Play. Untested AI changes compound into
debugging nightmares. One prompt, one test, one commit.
