#!/usr/bin/env bash
# Install the Squawkr widget as a native Omarchy (Quickshell) status-bar plugin — a logo in the
# bar that opens a native panel on click. All additive and reversible; configs are backed up,
# never clobbered, and nothing under /usr/share/omarchy is touched.
#
#   ./install.sh            copy the QML plugin; PRINT the config step.
#   ./install.sh --wire     also register the bar module in shell.json, backing it up first,
#                           then reload the shell. Also removes the retired chromium-panel
#                           stack (launcher, loopback server, Hyprland float rule) if present.
#
# The panel is a native QML popup (KeyboardPanel: outside-click/Esc/popout coordination come
# from the shell). It talks straight to the Squawkr plugin API over https — no local server.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QML_SRC="$SRC/omarchy-plugin/squawkr"
PLUGINS="$HOME/.config/omarchy/plugins"
WIRE=0; [ "${1:-}" = "--wire" ] && WIRE=1

backup() { [ -f "$1" ] && cp "$1" "$1.bak.$(date +%s)" && echo "  (backed up $1)"; }

mkdir -p "$PLUGINS/squawkr"

# 1. the native QML plugin (bar widget + panel + views + logic)
cp "$QML_SRC"/manifest.json "$QML_SRC"/BarWidget.qml "$QML_SRC"/Panel.qml \
   "$QML_SRC"/HomeView.qml "$QML_SRC"/DetailView.qml "$QML_SRC"/SearchView.qml \
   "$QML_SRC"/TrackedMini.qml "$QML_SRC"/StatBlock.qml "$QML_SRC"/DRow.qml \
   "$QML_SRC"/CondIcon.qml "$QML_SRC"/RunwayStrip.qml "$QML_SRC"/HeightMeter.qml \
   "$QML_SRC"/Squawkr.js "$QML_SRC"/squawkr-mark.svg "$PLUGINS/squawkr/"
echo "✓ plugin     → $PLUGINS/squawkr/ ($(ls "$PLUGINS/squawkr" | wc -l) files)"

# 2. retire the chromium-panel stack (pre-native eras): launcher, server, watcher, Hyprland
#    float rule. The retired web widget kept prefs in the browser profile, so the native panel
#    starts fresh and seeds from the Omarchy location. The [.] keeps pkill from matching this
#    script's own command line.
PORT="${SQUAWKR_WIDGET_PORT:-8770}"
if pkill -f "app=http://127.0.0.1:${PORT}/index[.]html" 2>/dev/null; then echo "✓ closed the retired chromium panel"; fi
if pkill -f "squawkr-widget/serve[.]py" 2>/dev/null; then echo "✓ stopped the retired loopback server"; fi
if pkill -f "[f]ocus-watch\\.py" 2>/dev/null; then echo "✓ stopped retired focus watchers"; fi
rm -f "$HOME/.local/bin/squawkr-widget-launch.sh" "$HOME/.local/bin/squawkr-widget-outside-click.sh" \
      "$HOME/.local/share/squawkr-widget/serve.py" "$HOME/.local/share/squawkr-widget/focus-watch.py" \
      "$HOME/.local/share/squawkr-widget/.visible" \
      "$HOME/.config/omarchy/hooks/theme-set.d/squawkr-widget" 2>/dev/null || true
HYPR="$HOME/.config/hypr/hyprland.lua"
if grep -q "chrome-127.0.0.1__index.html-Default\|squawkr-widget-outside-click\|_sq_outside" "$HYPR" 2>/dev/null; then
  backup "$HYPR"
  python3 - "$HYPR" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().splitlines()
KEYS = ("chrome-127.0.0.1__index.html-Default", "squawkr-widget-outside-click", "_sq_outside")
drop = {i for i, l in enumerate(lines) if any(k in l for k in KEYS) or (l.lstrip().startswith("--") and "squawkr" in l.lower())}
out = [l for i, l in enumerate(lines) if i not in drop]
p.write_text("\n".join(out).rstrip("\n") + "\n")
print("  ✓ removed the retired chromium float rule from " + sys.argv[1])
PY
  hyprctl reload >/dev/null 2>&1 && echo "  ✓ hyprland reloaded"
fi
echo

SHELL_JSON="$HOME/.config/omarchy/shell.json"

if [ "$WIRE" = "1" ]; then
  echo "Wiring shell.json (bar module)…"
  # add the module to the bar, start of the RIGHT group — idempotent. Right, not centre,
  # so a centred display notch (e.g. a MacBook) doesn't hide it.
  backup "$SHELL_JSON"
  python3 - "$SHELL_JSON" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); cfg = json.loads(p.read_text()); lay = cfg["bar"]["layout"]
for g in ("left", "center", "right"):
    lay[g] = [w for w in lay.get(g, []) if w.get("id") != "squawkr.panel"]
lay.setdefault("right", []).insert(0, {"id": "squawkr.panel"})
p.write_text(json.dumps(cfg, indent=2) + "\n")
print("  ✓ shell.json right:", [w.get("id") for w in lay["right"]])
PY
  omarchy-shell shell reloadConfig >/dev/null 2>&1 && echo "  ✓ shell reloaded"
  echo
  echo "Done — the Squawkr logo is in your bar. Click it to open the panel."
else
  cat <<STEPS
NOT modifying your config. Add this (or re-run with --wire):

1. Bar module — add {"id":"squawkr.panel"} to bar.layout.right in ~/.config/omarchy/shell.json,
   then:  omarchy-shell shell reloadConfig

State (token + tracked fields) lives in ~/.local/share/squawkr-widget/state.json. First run
seeds the home field from the Omarchy location (weather.json pin or IP) — see README.md.
STEPS
fi
