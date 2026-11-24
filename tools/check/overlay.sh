#!/usr/bin/env bash
# Runs the assembled plugin's overlay in a separate Quickshell instance (no
# window, no change to the running desktop) and checks it gets its host and
# saves. Needs quickshell; skipped where it is not installed (CI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if ! command -v quickshell >/dev/null; then
  echo "quickshell is not installed here; skipped the overlay check"
  exit 0
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$ROOT/tests/shell/." "$work/"
mkdir -p "$work/plugin"
cp -r "$ROOT/dist/plugin/." "$work/plugin/"
# the version the shell would pass from the manifest
version=$(sed -n 's/^ *"version": "\([^"]*\)".*/\1/p' "$ROOT/dist/plugin/manifest.json")
[[ -n "$version" ]] || { echo "dist/plugin/manifest.json has no version" >&2; exit 1; }
sed -i "s|@MANIFEST_VERSION@|$version|g" "$work/shell.qml"
# the stand-in OverlayWindow is an item, not a layer-shell window
sed -i '/WlrLayershell.namespace/d' "$work/plugin/Overlay.qml"
mkdir -p "$work/config/hueometry"
echo '{"muted":true}' > "$work/config/hueometry/settings.json"
out=$(XDG_DATA_HOME="$work/data" XDG_CONFIG_HOME="$work/config" timeout 20 quickshell -p "$work/shell.qml" 2>&1 || true)
if ! grep -q "OVERLAY ok" <<<"$out" || ! [[ -s "$work/data/hueometry/progress-plugin.json" ]]; then
  echo "$out" | grep -v usedbeforedeclared | tail -20 >&2
  echo "the plugin overlay did not start the game with its host" >&2
  exit 1
fi
echo "plugin overlay: the game has its host and saves"
