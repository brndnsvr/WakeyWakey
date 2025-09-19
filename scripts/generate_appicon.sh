#!/usr/bin/env bash
set -euo pipefail

SRC="Icon_WakeyWakey.icon/Assets/image.png"
DST="WakeyWakey/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "Source icon not found: $SRC" >&2
  exit 1
fi

# Generate macOS icon sizes
sips -z 16 16     "$SRC" --out "$DST/icon_16.png" >/dev/null
sips -z 32 32     "$SRC" --out "$DST/icon_16@2x.png" >/dev/null
sips -z 32 32     "$SRC" --out "$DST/icon_32.png" >/dev/null
sips -z 64 64     "$SRC" --out "$DST/icon_32@2x.png" >/dev/null
sips -z 128 128   "$SRC" --out "$DST/icon_128.png" >/dev/null
sips -z 256 256   "$SRC" --out "$DST/icon_128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$DST/icon_256.png" >/dev/null
sips -z 512 512   "$SRC" --out "$DST/icon_256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$DST/icon_512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$DST/icon_512@2x.png" >/dev/null

echo "Generated app icon images in $DST"
