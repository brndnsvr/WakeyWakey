#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WakeyWakey"
BUNDLE_ID="com.brndnsvr.WakeyWakey"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  elif [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  fi
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -quiet \
  -project "$ROOT_DIR/WakeyWakey.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  -allowProvisioningUpdates \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
