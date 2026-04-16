#!/usr/bin/env bash
set -euo pipefail

# WakeyWakey Release Script
# Creates a release DMG and optionally publishes to GitHub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

APP_NAME="WakeyWakey"
APP_PATH="build/Build/Products/Release/${APP_NAME}.app"
CLI_PATH="build/Build/Products/Release/wakey"
DIST_DIR="dist"
ICON_PATH="Icon_WakeyWakey.icon/Assets/image.png"

# Parse arguments
VERSION="${1:-}"
SKIP_BUILD="${SKIP_BUILD:-false}"
PUBLISH="${PUBLISH:-false}"

usage() {
    echo "Usage: $0 <version> [--publish]"
    echo ""
    echo "Arguments:"
    echo "  version     Version number (e.g., 1.0.0)"
    echo "  --publish   Also create GitHub release and push tag"
    echo ""
    echo "Environment variables:"
    echo "  SKIP_BUILD=true   Skip the build step (use existing build)"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.0              # Build and create DMG only"
    echo "  $0 1.0.0 --publish    # Build, create DMG, and publish to GitHub"
    echo "  SKIP_BUILD=true $0 1.0.0  # Create DMG from existing build"
    exit 1
}

# Check arguments
if [[ -z "$VERSION" ]]; then
    usage
fi

if [[ "${2:-}" == "--publish" ]]; then
    PUBLISH="true"
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "==> Release: ${APP_NAME} v${VERSION}"
echo ""

# Step 1: Build
if [[ "$SKIP_BUILD" != "true" ]]; then
    echo "==> Building release..."
    ./scripts/build.sh
else
    echo "==> Skipping build (SKIP_BUILD=true)"
fi

# Verify app exists
if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Run without SKIP_BUILD or run ./scripts/build_release.sh first"
    exit 1
fi

# Step 2: Embed wakey CLI in app bundle
if [[ -f "$CLI_PATH" ]]; then
    echo "==> Embedding wakey CLI in app bundle..."
    cp "$CLI_PATH" "$APP_PATH/Contents/MacOS/wakey"
    # Re-sign the app bundle after modification
    codesign --force --deep --sign "Developer ID Application: Brandon Seaver (CMFBMNG959)" \
        --timestamp -o runtime "$APP_PATH"
    echo "==> App bundle re-signed with embedded CLI"
else
    echo "WARNING: wakey CLI binary not found at $CLI_PATH"
    echo "  Run build.sh to build both targets before releasing"
    exit 1
fi

# Step 3: Create dist directory
mkdir -p "$DIST_DIR"

# Step 3a: Notarize the .app directly (so the stapled ticket lives on the .app,
# not just the DMG — means installed copies work offline after reboot)
APP_ZIP="${DIST_DIR}/${APP_NAME}-${VERSION}-app.zip"
echo ""
echo "==> Notarizing .app bundle (this may take a few minutes)..."
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" \
    --keychain-profile "WakeyWakey-Notarize" \
    --wait
rm -f "$APP_ZIP"

echo "==> Stapling notarization ticket to .app..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# Remove old DMG if exists
if [[ -f "$DMG_PATH" ]]; then
    echo "==> Removing existing DMG..."
    rm -f "$DMG_PATH"
fi

# Step 4: Create DMG (now containing the stapled .app)
echo "==> Creating DMG..."
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$ICON_PATH" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "${APP_NAME}.app" \
    "$DMG_PATH" \
    "$APP_PATH"

echo ""
echo "==> DMG created: $DMG_PATH"
ls -lh "$DMG_PATH"

# Step 5: Notarize the DMG
echo ""
echo "==> Notarizing DMG (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "WakeyWakey-Notarize" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "==> Notarization complete!"

# Step 6: Publish to GitHub (optional)
if [[ "$PUBLISH" == "true" ]]; then
    echo ""
    echo "==> Publishing to GitHub..."

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "ERROR: You have uncommitted changes. Commit or stash them first."
        exit 1
    fi

    TAG="v${VERSION}"

    # Check if tag already exists
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        echo "ERROR: Tag $TAG already exists"
        exit 1
    fi

    # Create and push tag
    echo "==> Creating tag $TAG..."
    git tag -a "$TAG" -m "Release ${VERSION}"
    git push origin "$TAG"

    # Create GitHub release
    echo "==> Creating GitHub release..."
    gh release create "$TAG" \
        --title "${APP_NAME} ${VERSION}" \
        --generate-notes \
        "$DMG_PATH"

    echo ""
    echo "==> GitHub release created!"
    gh release view "$TAG" --web || true
else
    echo ""
    echo "==> To publish to GitHub, run:"
    echo "    $0 $VERSION --publish"
    echo ""
    echo "Or manually:"
    echo "    git tag -a v${VERSION} -m 'Release ${VERSION}'"
    echo "    git push origin v${VERSION}"
    echo "    gh release create v${VERSION} --title '${APP_NAME} ${VERSION}' --generate-notes $DMG_PATH"
fi

echo ""
echo "==> Done!"
