#!/usr/bin/env bash
set -euo pipefail

APP="build/Build/Products/Debug/WakeyWakey.app"
if [[ ! -d "$APP" ]]; then
  echo "App not found: $APP. Build first." >&2
  exit 1
fi

cp -R "$APP" /Applications/
echo "WakeyWakey installed to /Applications"
