#!/usr/bin/env bash
# Checks tools/version/build-id.sh in throwaway repositories: what the menu
# shows after the version for each kind of build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
g() { git -c user.email=check@localhost -c user.name=check "$@"; }

repo="$work/repo"
mkdir -p "$repo/tools/version"
cp "$ROOT/tools/version/build-id.sh" "$repo/tools/version/"
echo a > "$repo/file"
(cd "$repo" && g init -q && g add -A && g commit -q -m one)
id=$(cd "$repo" && git rev-parse --short=7 HEAD)
fails=0
expect() {
  local got
  got=$("$repo/tools/version/build-id.sh" 0.1.0)
  if [[ "$got" != "$2" ]]; then echo "build id $1: got '$got', expected '$2'" >&2; fails=1; fi
}

expect "of a commit" "$id"
echo b > "$repo/file"; expect "with a change" "$id+"
(cd "$repo" && git checkout -q file)
touch "$repo/untracked"; expect "with only an untracked file" "$id"
(cd "$repo" && g tag v0x1x0); expect "with a look-alike tag" "$id"
(cd "$repo" && g tag -a v0.1.0 -m release); expect "of the release tag" ""
echo b > "$repo/file"; expect "of the release tag, with a change" "$id+"
(cd "$repo" && git checkout -q file)
# a copy without git, inside some other repository
outer="$work/outer"
mkdir -p "$outer/src/tools/version"
cp "$ROOT/tools/version/build-id.sh" "$outer/src/tools/version/"
(cd "$outer" && g init -q && g commit -q --allow-empty -m other)
got=$("$outer/src/tools/version/build-id.sh" 0.1.0)
[[ -z "$got" ]] || { echo "build id inside another repository: got '$got', expected nothing" >&2; fails=1; }

[[ "$fails" == 0 ]] || exit 1
echo "build ids: commit, changes, untracked, look-alike tag, release tag, foreign repository all right"
