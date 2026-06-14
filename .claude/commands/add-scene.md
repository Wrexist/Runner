---
description: Add a new Godot 4 scene wired to an existing/new script
argument-hint: <SceneName> [node-type]
---

Create `scenes/$1.tscn` (or `ui/$1.tscn` if it's UI) as a **Godot 4.3 text
.tscn** wired to its script. Follow the conventions already used in
`scenes/Main.tscn`, `Player.tscn`, `Gem.tscn`:

- `format=3`; declare `[ext_resource]` for scripts/packed scenes and
  `[sub_resource]` for meshes/shapes; reference them via `ExtResource("…")` /
  `SubResource("…")`.
- Keep `load_steps` roughly accurate (Godot is lenient but be tidy).
- For collectible-style detection use `Area3D` + `area_entered` and the existing
  collision layer/mask scheme (collectibles layer 1/mask 2, player layer 2/mask 1).
- Read any tunable value from `ThemeManager`, never hardcode theme data.

After writing it, tell me exactly what to instance it under (e.g. add it to
`Main.tscn`) and what I should see when I press Play. List anything you were
unsure about, since these can't be verified without the editor here.
