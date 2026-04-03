#!/usr/bin/env bash
set -euo pipefail

# Prefer Release build (consistent signing with distributed versions)
# Fall back to Debug for development iteration
RELEASE_APP="build/Build/Products/Release/WakeyWakey.app"
DEBUG_APP="build/Build/Products/Debug/WakeyWakey.app"

if [[ -d "$RELEASE_APP" ]]; then
  APP="$RELEASE_APP"
  CONFIG="Release"
  echo "Installing Release build (Developer ID signed)"
elif [[ -d "$DEBUG_APP" ]]; then
  APP="$DEBUG_APP"
  CONFIG="Debug"
  echo "Installing Debug build (Development signed)"
  echo "  Note: Use 'build_release.sh' for consistent signing with releases"
else
  echo "No build found. Run build_debug.sh or build_release.sh first." >&2
  exit 1
fi

cp -R "$APP" /Applications/
echo "WakeyWakey installed to /Applications"

# Install wakey CLI to /usr/local/bin
WAKEY_BIN="build/Build/Products/${CONFIG}/wakey"
if [[ -f "$WAKEY_BIN" ]]; then
  mkdir -p /usr/local/bin
  cp "$WAKEY_BIN" /usr/local/bin/wakey
  echo "wakey CLI installed to /usr/local/bin/wakey"
else
  echo "wakey CLI binary not found — skipping CLI install"
fi
