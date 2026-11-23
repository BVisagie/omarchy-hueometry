#!/usr/bin/env bash
# Fails when a commit since BASE changes LAWS.bend or SPEC.bend without a
# "Laws-Change:" trailer. The laws are the owner's specification.
set -euo pipefail
base="${1:-origin/main}"
if ! git rev-parse --verify --quiet "$base" >/dev/null; then
  echo "laws-trailer: base $base not found; skipped" >&2
  exit 0
fi
bad=0
while read -r sha; do
  if git diff-tree --no-commit-id --name-only -r "$sha" | grep -qx -e LAWS.bend -e SPEC.bend; then
    if ! git log -1 --format=%B "$sha" | grep -q '^Laws-Change: .\+'; then
      echo "commit $sha changes LAWS.bend or SPEC.bend without a Laws-Change: trailer" >&2
      bad=1
    fi
  fi
done < <(git rev-list "$base..HEAD")
exit "$bad"
