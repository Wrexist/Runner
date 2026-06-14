# AI art prompt pack — Critter Dash

Copy/paste prompts for generating the app icon, logo, in-game models, textures,
and store art with your own AI tools. Tuned to the actual theme palettes so the
generated art harmonizes with the in-game UI/backgrounds.

**Style bible (use in every prompt for consistency):**
> soft rounded shapes, chunky low-poly / kawaii, friendly faces, big eyes, flat
> pastel colors, soft ambient light, no sharp edges, no scary or aggressive
> features — designed for toddlers (Apple Kids, ages 5 & under).

**Global negative prompt (append to image-gen prompts):**
> text, words, letters, watermark, logo, UI, buttons, photorealism, gore, scary,
> sharp teeth, weapons, dark/horror, harsh shadows, busy background, drop shadow,
> Apple devices, rounded-corner frame

**Licensing — important:** only use a tool whose terms grant **commercial use and
ownership** of outputs (most paid tiers do; verify). Log every generated asset in
`docs/CREDITS.md` (tool + date + "AI-generated, commercial license"). This is an
App Store title, so provenance must be clean.

---

## 1. App icon  → `ios/icons/icon_1024.png`
Square **1024×1024, opaque, NO transparency, NO rounded corners** (Apple masks
it), no text. The committed placeholder is a flat fox face on mint — replace it.

**Prompt (primary — fox, matches forest theme):**
```
App icon for a children's game, a single cute fox face centered, friendly smile,
big round eyes, soft rounded low-poly kawaii style, flat pastel colors, mint-green
background (#a8e6cf), warm orange fox (#f09a5e) with cream muzzle, tiny pink
cheeks (#ff8b94), navy facial details (#3d405b), soft even lighting, simple bold
shapes that read at small size, fills ~80% of the frame, centered, no text,
flat vector illustration, 1024x1024
```

**Alternate concepts (same style, pick your favorite):**
- `...a cute fox cradling a glowing rescue gem...` (ties to the rescue mechanic)
- `...a friendly fox peeking out of a heart shape...`
- A neutral mascot instead of fox: `...a round pastel critter mascot, ambiguous
  cute animal, big eyes...` (works across all themes)

**After generating:** export exactly **1024×1024, PNG, no alpha**, save as
`ios/icons/icon_1024.png`, commit. (Flatten any transparency onto the bg color.)

---

## 2. Logo / wordmark (store + title screen)
The title screen currently renders `display_name` as text, so a logo is optional
marketing art. Generate on a transparent OR solid background; **horizontal lockup**.
```
Playful logo wordmark "Critter Dash" for a toddler mobile game, soft rounded
bubbly hand-lettered font, thick friendly letters, mint and coral pastel palette
(#a8e6cf, #ff8b94, #3d405b outline), a tiny cute fox mascot peeking over the
letters, flat vector, clean, high contrast, transparent background
```
> Tip: AI is unreliable at spelling. Generate the lettering *style*, then set the
> actual word "Critter Dash" in a vector editor using a similar rounded font if
> the AI misspells it.

---

## 3. In-game 3D models  → `themes/<id>/models/*.glb`
The engine loads **`.glb`** at the paths below (auto-wired by `core/ThemeModels.gd`
— just drop files in). Image generators give 2D PNGs, which won't work here; use a
**text-to-3D** tool that **exports `.glb`** (e.g. Meshy, Tripo, Rodin, Luma Genie —
verify glb export + commercial terms). Then in a free tool (Blender) confirm:
**Y-up, ~1–2 units tall, origin at the base, low poly.**

**Per-model 3D prompts** (prepend the style bible). Each = one file:

### Forest — `themes/forest/models/`
| File | Prompt |
|---|---|
| `fox.glb` | cute chunky low-poly fox, sitting upright, big friendly eyes, soft rounded, warm orange + cream, game-ready |
| `bunny.glb` | cute chunky low-poly bunny, round body, long soft ears, pastel, game-ready |
| `hedgehog.glb` | cute low-poly hedgehog, round, soft non-spiky quills, friendly face, game-ready |
| `owl.glb` | cute low-poly baby owl, round, big eyes, pastel feathers, game-ready |
| `deer.glb` | cute low-poly fawn, small, gentle, tiny antlers, soft brown, game-ready |
| `gem.glb` | simple faceted gemstone, smooth low-poly, **plain white/grey** (engine tints it), game-ready |
| `cage.glb` | small friendly woven basket / soft barred carrier, **plain white/grey**, rounded, not a scary cage, game-ready |

### Space — `themes/space/models/` (palette: deep violet #1b1b3a / cyan #7ee8fa)
| File | Prompt |
|---|---|
| `rocket.glb` | cute chunky low-poly toy rocket, rounded, pastel, friendly, game-ready |
| `blob.glb` | cute round low-poly alien blob, big eyes, smiling, pastel, game-ready |
| `robo.glb` | cute low-poly round robot, friendly, rounded, pastel, game-ready |
| `comet.glb` | cute low-poly comet with a soft glowing tail, rounded, game-ready |
| `starpup.glb` | cute low-poly star-shaped puppy creature, soft, friendly, game-ready |
| `crystal.glb` | smooth low-poly crystal shard, **plain white/grey** (engine tints), game-ready |
| `pod.glb` | small rounded rescue pod / capsule, **plain white/grey**, friendly, game-ready |

### Ocean ("Reef Rescue") — `themes/ocean/models/` (aqua #41c7d8 / coral #ff7f6e)
| File | Prompt |
|---|---|
| `sub.glb` | cute chunky low-poly toy submarine, round porthole, pastel, friendly, game-ready |
| `clownfish.glb` | cute low-poly clownfish, round, big eyes, soft, game-ready |
| `seahorse.glb` | cute low-poly seahorse, rounded, pastel, friendly, game-ready |
| `turtle.glb` | cute low-poly baby sea turtle, round shell, smiling, game-ready |
| `dolphin.glb` | cute low-poly dolphin, smooth rounded, friendly, pastel, game-ready |
| `pearl.glb` | smooth round pearl, **plain white/grey** (engine tints), game-ready |
| `net.glb` | small soft kelp pod / gentle net bundle, **plain white/grey**, rounded, game-ready |

> Gems and cages are **tinted in code** to the gem colors, so model them
> white/grey — a pre-colored gem would fight the tint.

---

## 4. Ground textures  → `themes/<id>/textures/*.png`
Image-gen works here. Must be **seamless/tileable**, square, 512 or 1024px.
| File | Prompt (append: "seamless tileable texture, top-down, flat, soft, no shadows") |
|---|---|
| `forest/textures/grass.png` | soft stylized cartoon grass, gentle green, tiny flowers, pastel |
| `space/textures/starfield.png` | soft dark starfield, deep violet + cyan twinkles, gentle |
| `ocean/textures/sand.png` | soft stylized sea-floor sand, pale aqua, gentle ripples |
> Verify tiling: many tools have a "seamless/tiling" toggle — use it, then check
> the edges line up.

---

## 5. Store screenshots / key art (marketing, not in build)
For the App Store listing (capture real gameplay too, but hero art helps):
```
Key art for a gentle toddler endless-runner mobile game "Critter Dash", a cute
fox running down three soft pastel lanes rescuing happy little animals from
friendly cages, mint and coral palette, soft rounded low-poly kawaii style, bright
cheerful, soft lighting, no text, vertical 9:16 composition
```

---

## Workflow summary
1. Generate the **icon** (§1) → save as `ios/icons/icon_1024.png` → commit. Done.
2. Generate **3D models** (§3) via a text-to-3D tool → export `.glb` → drop at the
   paths → they appear in-game automatically. Start with the **Forest 7** to ship.
3. Generate **ground textures** (§4) and **audio** (real CC0 `.ogg`, see
   `docs/ASSET_MANIFEST.md`) to replace the placeholder WAVs.
4. Log everything in `docs/CREDITS.md`. Rebuild via the `iOS build` workflow.
