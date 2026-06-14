#!/usr/bin/env bash
# SessionStart hook for Critter Dash.
# Prints quick orientation and runs whatever sanity checks the environment can.
# Always exits 0 — this hook must never block a session from starting.

set -u

echo "=== Critter Dash — session orientation ==="
echo "Godot 4.3 kids' rescue-runner. Reskinnable engine: core/ logic + themes/<id>/theme.json data."
echo "Read CLAUDE.md first. Compliance rules (Kids Category/COPPA) are non-negotiable."
echo

# Active theme (best-effort, no jq dependency).
if [ -f themes/forest/theme.json ]; then
  echo "Themes present: $(find themes -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | tr '\n' ' ')"
fi

# GDScript headless validation if Godot is available; skip gracefully otherwise.
if command -v godot >/dev/null 2>&1; then
  echo "Godot found — running headless import/validate (non-blocking)..."
  godot --headless --path . --quit-after 2 >/tmp/critter_godot.log 2>&1 || true
  if grep -qiE "SCRIPT ERROR|Parse Error" /tmp/critter_godot.log; then
    echo "⚠️  Godot reported script/parse errors — see /tmp/critter_godot.log"
  else
    echo "✓ Godot loaded the project with no script/parse errors."
  fi
else
  echo "Godot not installed in this environment — skipping headless validation."
  echo "(Gameplay must be verified by pressing Play in the Godot 4.3 editor.)"
fi

# Optional GDScript linting if the toolforge tools are present.
if command -v gdlint >/dev/null 2>&1; then
  echo "Running gdlint (non-blocking)..."
  gdlint core ui 2>&1 | head -20 || true
fi

exit 0
