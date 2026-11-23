#!/usr/bin/env bash
# Fails when a commit since BASE changes LAWS.bend or SPEC.bend without a
# "Laws-Change: <reason>" trailer. The laws are the owner's specification.
# A merge counts as changing a file when it differs from its first parent.
set -euo pipefail
base="${1:-origin/main}"
if [[ "$base" =~ ^0+$ ]]; then
  base=origin/main
fi
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "laws-trailer: cannot resolve base $base" >&2
  exit 1
fi
bad=0
while read -r sha; do
  if git rev-parse --verify --quiet "$sha^1" >/dev/null; then
    files=$(git diff --name-only "$sha^1" "$sha")
  else
    files=$(git show --name-only --format= "$sha")
  fi
  if grep -qx -e LAWS.bend -e SPEC.bend <<<"$files"; then
    reason=$(git log -1 --format='%(trailers:key=Laws-Change,valueonly,separator=%x20)' "$sha" | tr -d '[:space:]')
    if [[ -z "$reason" ]]; then
      echo "commit $sha changes LAWS.bend or SPEC.bend without a Laws-Change: trailer" >&2
      bad=1
    fi
  fi
done < <(git rev-list "$base..HEAD")
exit "$bad"
