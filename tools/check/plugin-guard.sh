#!/usr/bin/env bash
# Keeps the assembled plugin clear of what the plugin marketplace's security
# baseline (omacom/omarchy-plugin-marketplace, SECURITY.md) reports for
# review: setup-named files, executable files, and package-manager,
# privilege, service or download commands, written as shell text or as a
# QML argument array. Hueometry needs none of them, so any match is a
# mistake. Patterns follow the scanner's and, like it, ignore case.
# Usage: tools/check/plugin-guard.sh [plugin-folder]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
dir="${1:-$ROOT/dist/plugin}"
[[ -d "$dir" ]] || { echo "plugin guard: no plugin at $dir" >&2; exit 2; }
fails=0
say() { echo "plugin guard: $*" >&2; fails=1; }

# (command substitution under set -e: a find error stops the guard)
files=$(find "$dir" -path "$dir/.git" -prune -o -type f -print)
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  base=$(basename "$f")
  if [[ "${base,,}" =~ install|installer|setup|uninstall ]]; then say "setup-like file name: ${f#"$dir"/}"; fi
  if [[ -x "$f" ]] || [[ -n "$(find "$f" -perm /111)" ]]; then say "executable file: ${f#"$dir"/}"; fi
done <<<"$files"

q='["'"'"']'          # a quote, for argument arrays such as ["pacman", "-S"]
sep="${q}[[:space:]]*,[[:space:]]*${q}"
pm='(pacman|paru|yay|apt|apt-get|dnf|zypper|apk)'
pmverb='(-[a-z]*[sru]|install|remove|upgrade|add|del)'
patterns=(
  "\\bomarchy[[:space:]]+pkg[[:space:]]+(add|drop|remove|update)\\b"
  "\\bomarchy$sep""pkg$sep(add|drop|remove|update)$q"
  "\\b${pm}[[:space:]]+${pmverb}\\b"
  "$q$pm$sep$pmverb$q"
  "\\b(pip|pip3|pipx|npm|pnpm|yarn|bun|cargo|go|gem)[[:space:]]+(install|add)\\b"
  "$q(pip|pip3|pipx|npm|pnpm|yarn|bun|cargo|go|gem)$sep(install|add)$q"
  "\\bbrew[[:space:]]+(install|uninstall|upgrade)\\b"
  "\\b(sudo|pkexec|systemctl|systemd-run|curl|wget)\\b"
  "\\bgit[[:space:]]+(clone|fetch|pull)\\b"
  "${q}git$sep(clone|fetch|pull)$q"
)
for p in "${patterns[@]}"; do
  set +e
  hits=$(grep -rIEin --exclude-dir=.git "$p" "$dir")
  rc=$?
  set -e
  # grep: 0 found, 1 none, anything else an error
  if (( rc > 1 )); then echo "plugin guard: could not scan $dir" >&2; exit 2; fi
  while IFS= read -r hit; do
    [[ -n "$hit" ]] && say "command the marketplace would review: ${hit#"$dir"/}"
  done <<<"$hits"
done

[[ "$fails" == 0 ]] || exit 1
echo "plugin guard: no setup files, executables or reviewed commands"
