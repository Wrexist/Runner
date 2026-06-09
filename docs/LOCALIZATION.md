# Localization

The UI is **translation-ready**. Every user-facing string is wrapped in `tr()`,
and the catalog lives in `localization/ui_strings.csv`. Until a translation is
imported and registered, `tr()` returns the **English source unchanged** — so
the game reads identically in English with zero behavior change. That's why this
scaffolding is safe to ship before any locale is finished.

## How it works (translation-by-source-string)

We use the **English text itself as the key** (msgid). So in code:

```gdscript
UIScreens._button(tr("Play"))            # static
UIScreens._label(tr("Score: %d") % n)    # templated — see the rule below
```

…and the catalog maps that English source to each locale.

> **Format rule:** `tr()` runs *before* `%`. Always translate the **template**,
> then format: `tr("Score: %d") % n` — never `tr("Score: %d" % n)`. Keep the
> `%d` / `%s` specifiers identical across every locale.

## The catalog — `localization/ui_strings.csv`

```
keys,es
Play,Jugar
Back,Atrás
...
```

- First column header is **`keys`**; its cells are the **English source strings**.
- Each additional column is a **locale code** (`es`, `fr`, `de`, …) with the
  translation. Ships with Spanish (`es`) filled in as a working example.
- Fields with commas are quoted (standard CSV), e.g.
  `"Grab the gem, reach the matching cage!","¡Agarra la gema...!"`.

## Activate a locale (🖥️ editor step — one-time)

The `.csv` is the source of truth; Godot compiles it to binary `.translation`
files in the editor (those live under `.godot/` and are gitignored — regenerated
on open, never committed).

1. Open the project in **Godot 4.3**. It auto-imports `ui_strings.csv`,
   producing one `.translation` per locale column (e.g. `ui_strings.es.translation`).
2. **Project → Project Settings → Localization → Translations** → **Add…** the
   generated `.translation` file(s). Godot writes this into `project.godot` under
   `[internationalization] locale/translations` — **commit `project.godot`.**
3. Run. By default Godot picks the locale from the **device language**; a Spanish
   device now shows Spanish. To force it while testing:
   `TranslationServer.set_locale("es")`.

> We intentionally do **not** pre-register translations in `project.godot` here,
> because the binary `.translation` files don't exist until step 1 — registering
> a missing resource would break the headless build/CI. Do it after importing.

## Add a new language

1. Add a column to the CSV (header = locale code, e.g. `fr`) and fill every cell.
2. Re-open the editor (re-imports) and Add the new `.translation` (step 2 above).

## Add a new UI string

1. Wrap it in `tr("…")` in code.
2. Add a row to `ui_strings.csv`: the English source under `keys`, a translation
   in **every** locale column (don't leave blanks — a blank cell imports as an
   empty string and would render nothing).
3. `tests/Tests.gd` `_test_localization` guards structure (header, no blank
   translations, a few known keys). Run the suite after editing the catalog.

## In-game language picker (implemented)

Settings shows a **Language** button that cycles the available locales, calls
`TranslationServer.set_locale(code)`, persists `SaveManager.settings["locale"]`,
and re-lays-out the screen so every label re-translates. `UIManager` re-applies
the saved locale on boot.

It is **self-hiding**: the button only appears when more than one locale is
loaded (`TranslationServer.get_loaded_locales()`), so in the English-only build —
before you do the editor import step above — there's no dead UI. Import the
Spanish `.translation` and the picker appears automatically. By default the game
also follows the **device language** with no picker interaction needed.
