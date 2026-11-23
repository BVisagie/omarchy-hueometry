#!/usr/bin/env bash
# Usage: laws-trailer.sh [BASE] [HEAD]
# Fails when a commit in BASE..HEAD changes LAWS.bend or SPEC.bend without a
# "Laws-Change: <reason>" trailer. The laws are the owner's specification.
# A merge counts as changing a file when it differs from its first parent.
set -euo pipefail
base="${1:-origin/main}"
head="${2:-HEAD}"
if [[ "$base" =~ ^0+$ ]]; then
  base=origin/main
fi
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "laws-trailer: cannot resolve base $base" >&2
  exit 1
fi
if ! git rev-parse --verify --quiet "$head^{commit}" >/dev/null; then
  echo "laws-trailer: cannot resolve head $head" >&2
  exit 1
fi
commits=$(git rev-list "$base..$head")
bad=0
while read -r sha; do
  [[ -n "$sha" ]] || continue
  if git rev-parse --verify --quiet "$sha^1" >/dev/null; then
    files=$(git diff --no-renames --name-only "$sha^1" "$sha" -- LAWS.bend SPEC.bend)
  else
    files=$(git show --no-renames --name-only --format= "$sha" -- LAWS.bend SPEC.bend)
  fi
  if grep -qx -e LAWS.bend -e SPEC.bend <<<"$files"; then
    reason=$(git log -1 --format='%(trailers:key=Laws-Change,valueonly,separator=%x20)' "$sha" | tr -d '[:space:]')
    if [[ -z "$reason" ]]; then
      echo "commit $sha changes LAWS.bend or SPEC.bend without a Laws-Change: trailer" >&2
      bad=1
    fi
  fi
done <<<"$commits"
exit "$bad"
