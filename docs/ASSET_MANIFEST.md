# Asset Manifest — exactly what to source (Phase 2)

Every file slot the engine reads, the exact path it must land at, the spec it
must meet, and a specific **CC0** pack to get it from. Paths come straight from
`themes/<id>/theme.json` — drop a file at the path and it just works (engine
fails soft if missing, so you can add them one at a time).

> **Licensing rule for a Kids app:** prefer **CC0** (public-domain, no
> attribution, no strings). CC-BY is allowed but *requires* crediting the author
> on a Credits screen — avoid it unless you love something. Never use anything
> "free for personal use only." Keep a row in `docs/CREDITS.md` for each asset
> even when CC0 (good hygiene for review).

> **Key efficiency:** gems and cages are **one model each, tinted in code**
> (`Collectible.gd`), and the player's carried-color marker is tinted too. So you
> need **one** neutral gem and **one** neutral cage per theme — *not* one per
> color. Model them light grey / white so the tint reads true.

---

## Format specs (apply to every asset)

| Type | Format | Spec |
|---|---|---|
| 3D models | **`.glb`** (binary glTF) | Low-poly (≈300–3k tris). **Y-up**, real-world-ish scale ~1–2 Godot units tall, origin centered at the base. Baked/simple materials. Animation optional — the engine just displays + leans them; a built-in idle is a bonus, not required. |
| Ground texture | **`.png`** | **Seamless/tileable**, power-of-two **512²** or **1024²**. It scrolls, so tiling must be invisible. |
| Music | **`.ogg`** (Vorbis) | **Loopable**, ~30–60 s, gentle/major-key, soft attack. No sudden loud hits (Kids = no rage spikes). |
| SFX | **`.ogg`** (Vorbis) | Short (<1 s), soft, pleasant. `rescue` = happy chime, `gem` = light "ping", `miss` = a *gentle* "aw", never harsh/buzzer. |

---

## FOREST theme (default — **ship this one first**)

Drop into `themes/forest/{models,textures,audio}/`.

| Slot (theme.json key) | File path | What it is | Exact source suggestion (CC0) |
|---|---|---|---|
| `assets.player_model` | `models/fox.glb` | The player critter (a fox) | **Quaternius — Animated Animals / Cute Animals** (fox). Fallback: **Kenney — Animal Pack Redux** (fox). |
| `assets.gem_model` | `models/gem.glb` | One neutral gem (tinted red/blue/yellow in code) | **Kenney — Generic Items / Platformer Kit** (gem/crystal), or any low-poly faceted gem. Model it **white/grey**. |
| `assets.cage_model` | `models/cage.glb` | One neutral cage/crate (tinted per color) | **Kenney — Survival Kit / Pirate Kit** (cage/crate). A simple barred box reads best. Model it **white/grey**. |
| `assets.ground_texture` | `textures/grass.png` | Seamless grass the track scrolls over | **Kenney — Pattern Pack / Background Elements**, or any CC0 seamless grass (512²). |
| `rescuable_critters[0]` bunny (unlock 0) | `models/bunny.glb` | Rescued critter | **Quaternius / Kenney — Animal Pack Redux** (rabbit). |
| `rescuable_critters[1]` hedgehog (50) | `models/hedgehog.glb` | Rescued critter | Quaternius animal set; substitute a similar small critter if no hedgehog. |
| `rescuable_critters[2]` owl (150) | `models/owl.glb` | Rescued critter | **Kenney — Animal Pack Redux** (owl). |
| `rescuable_critters[3]` deer (300) | `models/deer.glb` | Rescued critter | **Quaternius — Animated Animals** (deer). |
| `audio.music` | `audio/music.ogg` | Looping gentle theme | **Kenney — Music Loops / Music Jingles** (CC0). Or **Pixabay Music** (royalty-free; check terms). Avoid incompetech unless you'll credit (CC-BY). |
| `audio.rescue` | `audio/rescue.ogg` | Happy chime on rescue | **Kenney — Interface Sounds / Casual Audio** (CC0). |
| `audio.gem_pickup` | `audio/gem.ogg` | Light pickup "ping" | **Kenney — Interface Sounds** (CC0). |
| `audio.miss` | `audio/miss.ogg` | Gentle "aw" on a stumble | **Kenney — Casual Audio** (a soft, non-harsh tone). |

**Forest count: 7 models + 1 texture + 4 audio = 12 files.**

---

## SPACE theme (reskin proof — can ship later / as an update)

Drop into `themes/space/{models,textures,audio}/`. The whole **Kenney — Space
Kit** (CC0) covers most of this in one download.

| Slot | File path | What it is | Exact source suggestion (CC0) |
|---|---|---|---|
| `assets.player_model` | `models/rocket.glb` | Player rocket | **Kenney — Space Kit** (rocket). |
| `assets.gem_model` | `models/crystal.glb` | Neutral crystal (tinted blue/purple/orange) | **Kenney — Space Kit** (crystal/shard) or a faceted gem. White/grey. |
| `assets.cage_model` | `models/pod.glb` | Neutral rescue pod (tinted) | **Kenney — Space Kit** (pod/capsule). White/grey. |
| `assets.ground_texture` | `textures/starfield.png` | Seamless starfield | Any CC0 seamless starfield (512²/1024²). |
| `rescuable_critters` | `models/blob.glb`, `robo.glb`, `comet.glb`, `starpup.glb` | 4 rescued critters (unlock 0/50/150/300) | **Kenney — Space Kit / Alien UFO Pack** (alien blob, robot, etc.); a comet can be a glowy sphere. |
| `audio.*` | `audio/music.ogg`, `rescue.ogg`, `gem.ogg`, `miss.ogg` | Same 4 as forest, space-flavored | **Kenney — Sci-Fi Sounds + Music Loops** (CC0). |

**Space count: 7 models + 1 texture + 4 audio = 12 files.**

---

## OCEAN theme ("Reef Rescue" — data-only, art pending)

Drop into `themes/ocean/{models,textures,audio}/`. A gentle underwater reskin;
gems are tinted coral/aqua/gold (one neutral model, tinted in code).

| Slot | File path | What it is | Exact source suggestion (CC0) |
|---|---|---|---|
| `assets.player_model` | `models/sub.glb` | Player (little sub or fish) | **Kenney — Pirate Kit / Fish Pack**, or a low-poly submarine. |
| `assets.gem_model` | `models/pearl.glb` | Neutral pearl/bubble (tinted) | A simple sphere/pearl; model it white/grey. |
| `assets.cage_model` | `models/net.glb` | Neutral net/kelp pod (tinted) | **Kenney — Pirate Kit** (net/cage) or a simple barred box. White/grey. |
| `assets.ground_texture` | `textures/sand.png` | Seamless sea floor | Any CC0 seamless sand (512²/1024²). |
| `rescuable_critters` | `models/clownfish.glb`, `seahorse.glb`, `turtle.glb`, `dolphin.glb` | 4 sea critters (unlock 0/50/150/300) | **Quaternius / Poly Pizza — sea life** (CC0). |
| `audio.*` | `audio/music.ogg`, `rescue.ogg`, `gem.ogg`, `miss.ogg` | Gentle, watery versions | **Kenney — Music Loops + Interface/Casual Audio** (CC0). |

**Ocean count: 7 models + 1 texture + 4 audio = 12 files.**

---

## Where to get them (all CC0 unless noted)

- **Kenney** — https://kenney.nl/assets — *Animal Pack Redux, Space Kit, Survival
  Kit, Platformer Kit, Interface Sounds, Casual Audio, Sci-Fi Sounds, Music
  Loops/Jingles.* All CC0. **Best single source — start here.**
- **Quaternius** — https://quaternius.com — CC0 low-poly **animated animals**
  (great for fox/deer/critters with idle anims).
- **Poly Pizza** — https://poly.pizza — searchable CC0 model library (filter to CC0).
- **OpenGameArt** — https://opengameart.org — filter license to **CC0** (textures, audio).
- **Pixabay** — https://pixabay.com/music/ & /sound-effects/ — royalty-free
  (verify the per-item license; most need no attribution).

## Minimum to feel "finished"
If you only do the **Forest** 12 files, the game is shippable and looks
intentional. Space can land as a free "new world" update — and it's also your
proof that a third theme costs *art only, zero code*.

## Grand total
**Forest (ship) = 12 files.** Each extra world (Space, Ocean) is another 12 —
all *art only, zero code*. Realistically a weekend per world of downloading +
light scaling/cleanup in Blender (export `.glb`, Y-up, scaled to ~1–2 units).
