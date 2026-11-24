#!/usr/bin/env bash
# The game's version is written in three places: hueometry.pro (the app),
# pkgbuild/PKGBUILD (the package) and plugin/manifest.json (the plugin).
# Fails unless they agree, and with a tag (v0.1.0), unless it matches too.
# Usage: tools/check/version.sh [tag]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pro=$(sed -n 's/^VERSION = //p' "$ROOT/hueometry.pro")
pkg=$(sed -n 's/^pkgver=//p' "$ROOT/pkgbuild/PKGBUILD")
plugin=$(sed -n 's/^ *"version": "\([^"]*\)".*/\1/p' "$ROOT/plugin/manifest.json")
if [[ -z "$pro" || "$pro" != "$pkg" || "$pro" != "$plugin" ]]; then
  echo "the versions differ: hueometry.pro '$pro', pkgbuild/PKGBUILD '$pkg', plugin/manifest.json '$plugin'" >&2
  exit 1
fi
if [[ -n "${1:-}" && "$1" != "v$pro" ]]; then
  echo "the tag '$1' is not v$pro" >&2
  exit 1
fi
echo "version $pro everywhere${1:+, and the tag $1}"
