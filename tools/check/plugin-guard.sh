#!/usr/bin/env bash
# Keeps the assembled plugin clear of what the plugin marketplace's security
# baseline (omacom/omarchy-plugin-marketplace, SECURITY.md) reports for
# review: setup-named files, executable files, and package-manager,
# privilege, service or download commands. Hueometry needs none of them, so
# any match is a mistake. Usage: tools/check/plugin-guard.sh [plugin-folder]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
dir="${1:-$ROOT/dist/plugin}"
fails=0
say() { echo "plugin guard: $*" >&2; fails=1; }

while IFS= read -r f; do say "setup-like file name: ${f#"$dir"/}"; done \
  < <(find "$dir" -path "$dir/.git" -prune -o -type f -print | awk -F/ 'tolower($NF) ~ /install|installer|setup|uninstall/')
while IFS= read -r f; do say "executable file: ${f#"$dir"/}"; done \
  < <(find "$dir" -path "$dir/.git" -prune -o -type f -perm -u+x -print)

patterns=(
  '\bomarchy[[:space:]]+pkg[[:space:]]+(add|drop|remove|update)\b'
  '\b(pacman|paru|yay|apt|apt-get|dnf|zypper|apk)[[:space:]]+(-[A-Za-z]*[SRU]|install|remove|upgrade|add|del)\b'
  '\b(pip|pip3|pipx|npm|pnpm|yarn|bun|cargo|go|gem)[[:space:]]+(install|add)\b'
  '\bbrew[[:space:]]+(install|uninstall|upgrade)\b'
  '\b(sudo|pkexec|systemctl|systemd-run|curl|wget)\b'
  '\bgit[[:space:]]+(clone|fetch|pull)\b'
)
for p in "${patterns[@]}"; do
  while IFS= read -r hit; do say "command the marketplace would review: ${hit#"$dir"/}"; done \
    < <(grep -rIEn --exclude-dir=.git "$p" "$dir" || true)
done

[[ "$fails" == 0 ]] || exit 1
echo "plugin guard: no setup files, executables or reviewed commands"
