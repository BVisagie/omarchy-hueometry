# shellcheck shell=bash
# Sourced by the bin/ scripts: repository root, pinned versions, tool paths.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/versions.env
source "$ROOT/tools/versions.env"
export PATH="$HOME/.local/bin:$HOME/.elan/bin:$PATH"

need_bend() {
  if ! command -v bend >/dev/null || [[ "$(bend version 2>/dev/null)" != *"$BEND_VERSION"* ]]; then
    echo "Bend $BEND_VERSION is not installed. Run bin/setup." >&2
    exit 1
  fi
}
