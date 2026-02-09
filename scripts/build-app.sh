#!/bin/bash
#
# build-app.sh — Build Grainulator.app bundle
#
# Usage:
#   ./scripts/build-app.sh              # Debug build
#   ./scripts/build-app.sh release      # Release build
#   ./scripts/build-app.sh install      # Release build + copy to /Applications
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Grainulator"
BUNDLE_ID="com.grainulator.app"

# Parse arguments
BUILD_CONFIG="${1:-debug}"
case "$BUILD_CONFIG" in
    release|install)
        SWIFT_FLAGS="-c release"
        CONFIG="release"
        ;;
    debug)
        SWIFT_FLAGS="-c debug"
        CONFIG="debug"
        ;;
    *)
        echo "Usage: $0 [debug|release|install]"
        exit 1
        ;;
esac

echo "=== Building $APP_NAME ($CONFIG) ==="

cd "$PROJECT_DIR"

# 1. Build with SwiftPM
echo "  [1/4] Compiling..."
swift build $SWIFT_FLAGS 2>&1 | tail -5

# 2. Locate the built binary
ARCH=$(uname -m)
BUILD_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "  [2/4] Binary: $BINARY ($(du -h "$BINARY" | cut -f1))"

# 3. Assemble .app bundle
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy entitlements (for reference; codesign uses it separately)
cp "Resources/Grainulator.entitlements" "$CONTENTS/Resources/"

# Copy app icon if it exists
if [ -d "Resources/Assets/AppIcon.icns" ] || [ -f "Resources/Assets/AppIcon.icns" ]; then
    cp "Resources/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "  [3/4] Bundle assembled: $APP_BUNDLE"

# 4. Ad-hoc codesign with entitlements
echo "  [4/4] Signing..."
codesign --force --sign - \
    --entitlements "Resources/Grainulator.entitlements" \
    --options runtime \
    "$APP_BUNDLE" 2>&1 || {
    echo "  WARNING: codesign failed, trying without --options runtime..."
    codesign --force --sign - \
        --entitlements "Resources/Grainulator.entitlements" \
        "$APP_BUNDLE" 2>&1
}

echo ""
echo "=== Build complete ==="
echo "  $APP_BUNDLE"
echo ""

# Verify
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "^(Identifier|Format|CDHash|Signature)" || true

# Install to /Applications if requested
if [ "$BUILD_CONFIG" = "install" ]; then
    echo ""
    echo "=== Installing to /Applications ==="
    DEST="/Applications/$APP_NAME.app"

    # Remove old version if present
    if [ -d "$DEST" ]; then
        echo "  Removing existing $DEST..."
        rm -rf "$DEST"
    fi

    cp -R "$APP_BUNDLE" "$DEST"
    echo "  Installed: $DEST"
    echo ""
    echo "  Launch with:  open /Applications/$APP_NAME.app"
fi
