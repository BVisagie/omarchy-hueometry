#!/usr/bin/env bash
# Regression cases for plugin-guard.sh: each bad plugin must fail it, and a
# clean one pass.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
guard="$ROOT/tools/check/plugin-guard.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
n=0
expect() {  # expect <pass|fail> <description> <file> <content>
  n=$((n + 1))
  local d="$work/p$n"
  mkdir -p "$d"
  echo 'import QtQuick' > "$d/Main.qml"
  [[ -n "$3" ]] && printf '%s\n' "$4" > "$d/$3"
  local rc=0
  "$guard" "$d" >/dev/null 2>&1 || rc=$?
  if [[ "$1" == pass && "$rc" != 0 ]] || [[ "$1" == fail && "$rc" != 1 ]]; then
    echo "plugin guard test: expected $1 for $2 (exit $rc)" >&2
    exit 1
  fi
}
expect pass "a clean plugin" "" ""
expect pass "a hyphenated omarchy-pkg-add mention" README.md "Install it: omarchy-pkg-add qt6-multimedia"
expect fail "pacman -Syu" README.md "run pacman -Syu"
expect fail "sudo pacman -S" README.md "sudo pacman -S foo"
expect fail "omarchy pkg add" README.md "omarchy pkg add foo"
expect fail "an argument array" Widget.qml 'Quickshell.execDetached(["pacman", "-S", "foo"])'
expect fail "a quoted git clone" Widget.qml "Quickshell.execDetached(['git', 'clone', 'x'])"
expect fail "curl" Widget.qml 'Quickshell.execDetached(["curl", "x"])'
expect fail "a setup-named file" Setup.qml "import QtQuick"
expect fail "a systemd unit" hueometry.service "[Unit]"
expect fail "a sudoers file" sudoers.d "x"
expect fail "visudo" README.md "visudo -c"
expect fail "a .sudoers file" hueometry.sudoers "x"
expect fail "a SUDOERS_FILE assignment" README.md "SUDOERS_FILE=/x"
expect pass "a negated sudo" README.md "No sudo or pkexec is required."
expect fail "sudo in a sentence" README.md "Run it with sudo."
expect fail "sudo after an invalid byte" notes.txt $'x\xff sudo rm'
expect fail "curl after an invalid byte" notes.txt $'x\xff curl x'
expect fail "sudo right after a non-ASCII letter" README.md "需要使用sudo命令"

expect fail "an array across lines" Widget.qml $'Quickshell.execDetached([\n  "cargo",\n  "install", "x"])'
expect pass "an ordinary array" Widget.qml 'Quickshell.execDetached(["omarchy-shell", "shell", "summon", "x", "{}"])'
d="$work/exec"; mkdir -p "$d"; echo 'import QtQuick' > "$d/Main.qml"; chmod g+x "$d/Main.qml"
rc=0; "$guard" "$d" >/dev/null 2>&1 || rc=$?
[[ "$rc" == 1 ]] || { echo "plugin guard test: a group-executable file passed (exit $rc)" >&2; exit 1; }
rc=0; "$guard" "$work/missing" >/dev/null 2>&1 || rc=$?
[[ "$rc" == 2 ]] || { echo "plugin guard test: a missing folder did not error (exit $rc)" >&2; exit 1; }
echo "plugin guard test: $((n + 2)) cases"
