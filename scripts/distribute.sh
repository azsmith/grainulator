#!/bin/bash
#
# distribute.sh — Build, sign, notarize, and package Grainulator for distribution
#
# Prerequisites:
#   1. Apple Developer ID Application certificate installed in Keychain
#   2. App-specific password created at appleid.apple.com
#   3. Store credentials once:
#      xcrun notarytool store-credentials "grainulator-notary" \
#        --apple-id YOUR@EMAIL \
#        --team-id TEAMID \
#        --password APP_SPECIFIC_PASSWORD
#   4. brew install create-dmg  (for DMG packaging)
#
# Usage:
#   ./scripts/distribute.sh                          # Interactive — prompts for identity
#   ./scripts/distribute.sh --identity "Developer ID Application: Name (TEAMID)"
#   ./scripts/distribute.sh --identity "..." --skip-notarize   # Sign only, skip notarization
#   ./scripts/distribute.sh --identity "..." --universal        # Universal binary (arm64 + x86_64)
#
# Environment variables (alternative to flags):
#   SIGNING_IDENTITY   — Developer ID Application identity string
#   NOTARY_PROFILE     — notarytool keychain profile name (default: grainulator-notary)
#

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Grainulator"
BUNDLE_ID="com.grainulator.app"
ENTITLEMENTS="$PROJECT_DIR/Resources/Grainulator.entitlements"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
ICON_FILE="$PROJECT_DIR/Resources/Assets/AppIcon.icns"

# Defaults
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-grainulator-notary}"
SKIP_NOTARIZE=false
UNIVERSAL=false
VERSION=""

# ─── Parse arguments ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --universal)
            UNIVERSAL=true
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            head -20 "$0" | tail -18
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── Preflight checks ────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       Grainulator Distribution Build                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

# Extract version from Info.plist if not overridden
if [ -z "$VERSION" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0")
fi
echo "  Version:    $VERSION"

# Prompt for signing identity if not provided
if [ -z "$SIGNING_IDENTITY" ]; then
    echo ""
    echo "Available Developer ID Application identities:"
    echo ""
    security find-identity -v -p codesigning | grep "Developer ID Application" || {
        echo "  (none found)"
        echo ""
        echo "ERROR: No Developer ID Application certificate found in Keychain."
        echo "  1. Enroll at developer.apple.com"
        echo "  2. Create a Developer ID Application certificate in Xcode → Settings → Accounts"
        echo "  3. Or download from developer.apple.com/account/resources/certificates"
        exit 1
    }
    echo ""
    read -rp "Paste signing identity (or hash): " SIGNING_IDENTITY
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo "ERROR: Signing identity required for distribution builds."
        exit 1
    fi
fi

echo "  Identity:   $SIGNING_IDENTITY"
echo "  Notarize:   $([ "$SKIP_NOTARIZE" = true ] && echo "skipped" || echo "yes ($NOTARY_PROFILE)")"
echo "  Universal:  $([ "$UNIVERSAL" = true ] && echo "yes (arm64 + x86_64)" || echo "no (native arch only)")"
echo ""

# Check for create-dmg
if ! command -v create-dmg &>/dev/null; then
    echo "WARNING: create-dmg not found. Install with: brew install create-dmg"
    echo "  DMG creation will be skipped. You'll get the signed .app only."
    CREATE_DMG=false
else
    CREATE_DMG=true
fi

# ─── Step 1: Build ────────────────────────────────────────────────────────────

DIST_DIR="$PROJECT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "━━━ Step 1/6: Building ($( [ "$UNIVERSAL" = true ] && echo "universal" || echo "native" ) release) ━━━"
echo ""

if [ "$UNIVERSAL" = true ]; then
    # Build for both architectures
    echo "  Building arm64..."
    swift build -c release --arch arm64 2>&1 | tail -3
    echo "  Building x86_64..."
    swift build -c release --arch x86_64 2>&1 | tail -3

    ARM_BINARY=".build/arm64-apple-macosx/release/$APP_NAME"
    X86_BINARY=".build/x86_64-apple-macosx/release/$APP_NAME"

    if [ ! -f "$ARM_BINARY" ] || [ ! -f "$X86_BINARY" ]; then
        echo "ERROR: One or both architecture builds failed."
        [ ! -f "$ARM_BINARY" ] && echo "  Missing: $ARM_BINARY"
        [ ! -f "$X86_BINARY" ] && echo "  Missing: $X86_BINARY"
        exit 1
    fi

    # Create universal binary
    echo "  Creating universal binary..."
    UNIVERSAL_BINARY="$DIST_DIR/$APP_NAME"
    lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$UNIVERSAL_BINARY"
    echo "  Universal binary: $(du -h "$UNIVERSAL_BINARY" | cut -f1)"
    BINARY="$UNIVERSAL_BINARY"
else
    swift build -c release 2>&1 | tail -3
    ARCH=$(uname -m)
    BINARY=".build/${ARCH}-apple-macosx/release/$APP_NAME"
    if [ ! -f "$BINARY" ]; then
        echo "ERROR: Binary not found at $BINARY"
        exit 1
    fi
    echo "  Binary: $(du -h "$BINARY" | cut -f1)"
fi

echo ""

# ─── Step 2: Assemble .app bundle ────────────────────────────────────────────

echo "━━━ Step 2/6: Assembling app bundle ━━━"
echo ""

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
if [ "$UNIVERSAL" = true ]; then
    cp "$DIST_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
else
    cp "$BINARY" "$MACOS_DIR/$APP_NAME"
fi

# Info.plist — update version if overridden
cp "$INFO_PLIST" "$CONTENTS/Info.plist"
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
fi

# App icon
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
fi

# PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Build and bundle the MCP server binary
echo "  Building MCP server (grainulator-mcp)..."
MCP_DIR="$PROJECT_DIR/MCP"
if [ -f "$MCP_DIR/Package.swift" ]; then
    if [ "$UNIVERSAL" = true ]; then
        (cd "$MCP_DIR" && swift build -c release --arch arm64 2>&1 | tail -1)
        (cd "$MCP_DIR" && swift build -c release --arch x86_64 2>&1 | tail -1)
        MCP_ARM="$MCP_DIR/.build/arm64-apple-macosx/release/GrainulatorMCP"
        MCP_X86="$MCP_DIR/.build/x86_64-apple-macosx/release/GrainulatorMCP"
        if [ -f "$MCP_ARM" ] && [ -f "$MCP_X86" ]; then
            lipo -create "$MCP_ARM" "$MCP_X86" -output "$RESOURCES_DIR/grainulator-mcp"
            echo "  Bundled MCP server (universal)"
        else
            echo "  WARNING: MCP server universal build failed, skipping"
        fi
    else
        (cd "$MCP_DIR" && swift build -c release 2>&1 | tail -1)
        MCP_ARCH=$(uname -m)
        MCP_BINARY="$MCP_DIR/.build/${MCP_ARCH}-apple-macosx/release/GrainulatorMCP"
        if [ -f "$MCP_BINARY" ]; then
            cp "$MCP_BINARY" "$RESOURCES_DIR/grainulator-mcp"
            echo "  Bundled MCP server ($(du -h "$RESOURCES_DIR/grainulator-mcp" | cut -f1))"
        else
            echo "  WARNING: MCP server build failed, skipping"
        fi
    fi
else
    echo "  WARNING: MCP/Package.swift not found, skipping MCP server"
fi

# Copy bundled resources (samples, presets, soundfonts if present)
for DIR in Samples Presets; do
    if [ -d "Resources/$DIR" ]; then
        # Only copy if there are real files (not just .gitkeep)
        FILE_COUNT=$(find "Resources/$DIR" -type f ! -name '.gitkeep' | wc -l | tr -d ' ')
        if [ "$FILE_COUNT" -gt 0 ]; then
            cp -R "Resources/$DIR" "$RESOURCES_DIR/"
            echo "  Bundled Resources/$DIR ($FILE_COUNT files)"
        fi
    fi
done

# Copy documentation PDFs
for PDF in Quick-Start-Guide.pdf User-Manual.pdf; do
    if [ -f "docs/$PDF" ]; then
        cp "docs/$PDF" "$RESOURCES_DIR/"
        echo "  Bundled docs/$PDF"
    fi
done

echo "  Bundle: $APP_BUNDLE"
echo ""

# ─── Step 3: Code signing ────────────────────────────────────────────────────

echo "━━━ Step 3/6: Code signing (Developer ID) ━━━"
echo ""

# Sign nested executables first (inner-to-outer)
if [ -f "$RESOURCES_DIR/grainulator-mcp" ]; then
    codesign --force --options runtime \
        --sign "$SIGNING_IDENTITY" \
        --timestamp \
        "$RESOURCES_DIR/grainulator-mcp"
    echo "  Signed grainulator-mcp helper"
fi

# Sign the main binary with hardened runtime + entitlements
codesign --deep --force --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" \
    --timestamp \
    "$APP_BUNDLE"

echo "  Signed with Developer ID"

# Verify
echo ""
echo "  Verification:"
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "^(Identifier|Authority|TeamIdentifier|Timestamp|Signature)" | sed 's/^/    /'
echo ""

# Check the signature is valid
codesign --verify --strict --deep "$APP_BUNDLE" 2>&1 && echo "  Signature: VALID" || {
    echo "  ERROR: Signature verification failed!"
    exit 1
}
echo ""

# ─── Step 4: Notarization ────────────────────────────────────────────────────

if [ "$SKIP_NOTARIZE" = true ]; then
    echo "━━━ Step 4/6: Notarization (SKIPPED) ━━━"
    echo ""
else
    echo "━━━ Step 4/6: Notarization ━━━"
    echo ""

    # Create zip for notarization
    NOTARIZE_ZIP="$DIST_DIR/$APP_NAME-notarize.zip"
    echo "  Creating zip for submission..."
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

    # Submit
    echo "  Submitting to Apple (this may take a few minutes)..."
    echo ""
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1 | tee "$DIST_DIR/notarization-log.txt"

    # Check result
    if grep -q "status: Accepted" "$DIST_DIR/notarization-log.txt"; then
        echo ""
        echo "  Notarization: ACCEPTED"
    else
        echo ""
        echo "  ERROR: Notarization failed. Check $DIST_DIR/notarization-log.txt"
        echo "  You can retrieve the full log with:"
        echo "    xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE"
        exit 1
    fi

    # Clean up zip
    rm -f "$NOTARIZE_ZIP"

    # ─── Step 5: Staple ──────────────────────────────────────────────────

    echo ""
    echo "━━━ Step 5/6: Stapling notarization ticket ━━━"
    echo ""

    xcrun stapler staple "$APP_BUNDLE"
    echo "  Stapled."
    echo ""
fi

# ─── Step 6: Create DMG ──────────────────────────────────────────────────────

if [ "$CREATE_DMG" = true ]; then
    echo "━━━ Step 6/6: Creating DMG ━━━"
    echo ""

    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
    DMG_PATH="$DIST_DIR/$DMG_NAME"

    # Remove existing DMG if present
    rm -f "$DMG_PATH"

    create-dmg \
        --volname "$APP_NAME $VERSION" \
        --volicon "$ICON_FILE" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_BUNDLE"

    echo ""

    # Sign the DMG
    echo "  Signing DMG..."
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

    # Notarize the DMG if we're doing notarization
    if [ "$SKIP_NOTARIZE" = false ]; then
        echo "  Notarizing DMG..."
        xcrun notarytool submit "$DMG_PATH" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait 2>&1 | tee "$DIST_DIR/dmg-notarization-log.txt"

        if grep -q "status: Accepted" "$DIST_DIR/dmg-notarization-log.txt"; then
            echo "  DMG notarization: ACCEPTED"
            xcrun stapler staple "$DMG_PATH"
            echo "  DMG stapled."
        else
            echo "  WARNING: DMG notarization failed. The .app inside is still notarized."
        fi
    fi

    echo ""
    echo "  DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
else
    echo "━━━ Step 6/6: Creating DMG (SKIPPED — install create-dmg) ━━━"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                  Build Complete                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  App:      $APP_BUNDLE"
[ "$CREATE_DMG" = true ] && echo "  DMG:      $DMG_PATH"
echo "  Version:  $VERSION"
echo ""
echo "  Test on a clean Mac (or fresh user account) before releasing."
echo ""
if [ "$SKIP_NOTARIZE" = true ]; then
    echo "  ⚠  Notarization was skipped. Users will see Gatekeeper warnings."
    echo "     Re-run without --skip-notarize for a distributable build."
    echo ""
fi
