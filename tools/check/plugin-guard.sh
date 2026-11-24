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
  if [[ "${base,,}" =~ \.(service|timer|socket)$ ]]; then say "systemd unit file: ${f#"$dir"/}"; fi
  rel="${f#"$dir"/}"
  # the scanner's sudoers path rule: a sudoers or sudoers.d path part, or *.sudoers
  if [[ "${rel,,}" =~ (^|/)(sudoers(\.d)?(/|$)|[^/]+\.sudoers$) ]]; then say "sudoers file: $rel"; fi
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
  "\\b(visudo|systemctl|systemd-run|curl|wget)\\b"
  "/etc/sudoers"
  "\\bsudoers(_file)?[[:space:]]*="
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

# sudo and pkexec unless explicitly negated, by the scanner's own rule
set +e
priv=$(tr '\n' '\0' <<<"$files" | xargs -0 -r python3 "$ROOT/tools/check/privilege.py")
rc=$?
set -e
# xargs: 0 none, 123 some hits (privilege.py exited 1), anything else an error
if (( rc != 0 && rc != 123 )); then echo "plugin guard: could not scan $dir for sudo" >&2; exit 2; fi
while IFS= read -r hit; do
  [[ -n "$hit" ]] && say "privilege the marketplace would review: ${hit#"$dir"/}"
done <<<"$priv"

# argument arrays can span lines: check them again with each text file
# joined into one line (the scanner joins them too)
arrays=(
  "${q}${pm}${sep}${pmverb}${q}"
  "${q}omarchy${sep}pkg${sep}(add|drop|remove|update)${q}"
  "${q}(pip|pip3|pipx|npm|pnpm|yarn|bun|cargo|go|gem)${sep}(install|add)${q}"
  "${q}brew${sep}(install|uninstall|upgrade)${q}"
  "${q}(sudo|pkexec|visudo|systemctl|systemd-run|curl|wget)${q}"
  "${q}git${sep}(clone|fetch|pull)${q}"
)
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  grep -Iq . "$f" 2>/dev/null || continue   # text files only
  joined=$(tr '\n\r\t' '   ' < "$f")
  joined=${joined,,}
  for p in "${arrays[@]}"; do
    if [[ "$joined" =~ $p ]]; then say "command the marketplace would review (argument array): ${f#"$dir"/}: ${BASH_REMATCH[0]}"; fi
  done
done <<<"$files"

[[ "$fails" == 0 ]] || exit 1
echo "plugin guard: no setup files, executables or reviewed commands"
