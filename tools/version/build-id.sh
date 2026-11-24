#!/usr/bin/env bash
# Names this build beyond its version: nothing for a build of the release tag
# itself (v<version>), otherwise the short commit, with "+" when tracked files
# have uncommitted changes. Prints nothing outside a git checkout.
# Usage: tools/version/build-id.sh <version>
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 0
# only Hueometry's own checkout: a source archive unpacked inside another
# repository must not take that repository's commit
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ "$(cd "$top" && pwd -P)" == "$(pwd -P)" ]] || exit 0
if git tag --points-at HEAD 2>/dev/null | grep -Fqx -- "v$1"; then
  exit 0
fi
id=$(git rev-parse --short=7 HEAD 2>/dev/null) || exit 0
# untracked files (build folders, makepkg's output) do not count
if [[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
  id="$id+"
fi
printf '%s\n' "$id"
