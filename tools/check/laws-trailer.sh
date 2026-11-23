#!/usr/bin/env bash
# Usage: laws-trailer.sh [BASE] [HEAD]
# Fails when a commit in BASE..HEAD changes LAWS.bend or SPEC.bend without a
# "Laws-Change: <reason>" trailer. The laws are the owner's specification.
# A merge counts as changing a file only when its result differs from what
# Git's own merge of its parents gives (or that merge conflicts on the file):
# merging commits that were already checked passes, while a merge that edits
# or hand-resolves the laws must carry the trailer.
set -euo pipefail
base="${1:-origin/main}"
head="${2:-HEAD}"
if [[ "$base" =~ ^0+$ ]]; then
  base=origin/main
fi
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  # e.g. the old head of a force-pushed branch: check against main instead
  echo "laws-trailer: cannot resolve base $base; checking against origin/main" >&2
  base=origin/main
  if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
    echo "laws-trailer: cannot resolve origin/main either" >&2
    exit 1
  fi
fi
if ! git rev-parse --verify --quiet "$head^{commit}" >/dev/null; then
  echo "laws-trailer: cannot resolve head $head" >&2
  exit 1
fi
commits=$(git rev-list "$base..$head")
bad=0
while read -r sha; do
  [[ -n "$sha" ]] || continue
  if git rev-parse --verify --quiet "$sha^2" >/dev/null; then
    if auto=$(git merge-tree --write-tree "$sha^1" "$sha^2" 2>/dev/null | head -1); then
      files=$(git diff --no-renames --name-only "$auto" "$sha" -- LAWS.bend SPEC.bend)
    else
      # Git's merge conflicts: count the laws only if they were part of it
      files=$(git diff --no-renames --name-only "$sha^1" "$sha" -- LAWS.bend SPEC.bend)
    fi
  elif git rev-parse --verify --quiet "$sha^1" >/dev/null; then
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
