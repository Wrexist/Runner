---
description: Scaffold a new reskin theme (data-only, zero code changes)
argument-hint: <theme-id> "<Display Name>"
---

Create a new theme named `$1` with display name `$2`, proving the reskinnable
engine. Do this WITHOUT editing anything in `core/`, `scenes/`, or `ui/`.

Steps:
1. Read `themes/CLAUDE.md` and an existing `themes/*/theme.json` as a template.
2. Create `themes/$1/theme.json` with every key the engine reads (see the table
   in `themes/CLAUDE.md`): palette, lanes, speeds, `gem_colors`,
   `spawn_interval_*`, `max_stumbles`, `assets.*`, `rescuable_critters[]`,
   `audio.*`. Pick a distinct palette and critter set so the reskin is obvious.
2. Create empty placeholder dirs `themes/$1/models`, `/textures`, `/audio` and
   point the asset paths at them (real CC0 art gets dropped in later).
3. Tell me to set `ThemeManager.active_theme = "$1"` to preview it.
4. If anything would require a code change to work, STOP and report it — that is
   a bug in the data-driven design, not a theme problem. Fix the engine to read
   the value from `theme.json` instead.

Keep it pure data. Then summarize what changed and how to preview it.
