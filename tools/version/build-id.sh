#!/usr/bin/env bash
# Names this build beyond its version: nothing for a clean build of the
# release tag itself (v<version>), otherwise the short commit, with "+" when
# tracked files have uncommitted changes (so a patched build of the release
# never passes for the release). Prints nothing outside a git checkout.
# Usage: tools/version/build-id.sh <version>
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 0
# only Hueometry's own checkout: a source archive unpacked inside another
# repository must not take that repository's commit
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ "$(cd "$top" && pwd -P)" == "$(pwd -P)" ]] || exit 0
# untracked files (build folders, makepkg's output) do not count
dirty=""
if [[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
  dirty="+"
fi
if [[ -z "$dirty" ]] && git tag --points-at HEAD 2>/dev/null | grep -Fqx -- "v$1"; then
  exit 0
fi
id=$(git rev-parse --short=7 HEAD 2>/dev/null) || exit 0
printf '%s%s\n' "$id" "$dirty"
