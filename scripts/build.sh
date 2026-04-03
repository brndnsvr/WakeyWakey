#!/usr/bin/env bash
set -euo pipefail

xcodebuild \
  -project WakeyWakey.xcodeproj \
  -scheme WakeyWakey \
  -configuration Release \
  -derivedDataPath build \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  -allowProvisioningUpdates

xcodebuild \
  -project WakeyWakey.xcodeproj \
  -scheme wakey \
  -configuration Release \
  -derivedDataPath build \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  -allowProvisioningUpdates
