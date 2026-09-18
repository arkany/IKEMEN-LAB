#!/bin/bash

# IKEMEN Lab — Release Build Script
# Signs with Developer ID and notarizes for Gatekeeper approval.
#
# Prerequisites:
#   - Copy .env.example to .env and fill in TEAM_ID + NOTARY_PROFILE
#   - "Developer ID Application" certificate in Keychain
#   - App-specific password stored:
#       xcrun notarytool store-credentials "<NOTARY_PROFILE>" \
#           --apple-id "<your-apple-id>" --team-id "<TEAM_ID>"
#   - Xcode command line tools installed
#
# Usage:
#   ./scripts/build-release.sh
#   SKIP_NOTARIZE=1 ./scripts/build-release.sh   # Skip notarization (for testing)

set -euo pipefail

# Load .env if present (values can also be set via environment variables)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Validate required configuration
if [ -z "${TEAM_ID:-}" ]; then
    echo "❌ TEAM_ID is not set. Copy .env.example to .env and fill in your Apple Developer Team ID."
    exit 1
fi
if [ -z "${NOTARY_PROFILE:-}" ] && [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
    echo "❌ NOTARY_PROFILE is not set. Set it in .env or pass SKIP_NOTARIZE=1 to skip notarization."
    exit 1
fi

# Configuration
APP_NAME="IKEMEN Lab"
SCHEME="IKEMEN Lab"
# Version comes from MARKETING_VERSION in the Xcode project so the DMG name
# can never drift from the app's CFBundleShortVersionString (see issue #37).
MARKETING_VERSION=$(xcodebuild -showBuildSettings \
    -scheme "$SCHEME" \
    -configuration Release 2>/dev/null \
    | awk -F' = ' '/^ *MARKETING_VERSION = / { print $2; exit }')
if [ -z "$MARKETING_VERSION" ]; then
    echo "❌ Could not read MARKETING_VERSION from the Xcode project."
    exit 1
fi
VERSION="v${MARKETING_VERSION}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
SIGNING_IDENTITY="Developer ID Application"

echo "🚀 Starting release build for ${APP_NAME} ${VERSION}..."

# 1. Archive for distribution
# Note: Do NOT pass CODE_SIGN_IDENTITY as a global xcodebuild parameter — it
# overrides all targets (including the Browser Extension and SPM packages) which
# use Automatic signing. Per-target signing is configured in the Xcode project:
#   - Main app (Release): Developer ID Application, Manual
#   - Browser Extension:  Apple Development, Automatic
echo "📦 Archiving project..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -quiet

echo "✅ Archive successful"

# 2. Export from archive
echo "📤 Exporting app from archive..."

cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/Export" \
    -quiet

APP_PATH="$BUILD_DIR/Export/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Exported app not found at $APP_PATH"
    exit 1
fi

echo "✅ Export successful"

# Guard against shipping a stale build under a new version name
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
if [ "$BUILT_VERSION" != "$MARKETING_VERSION" ]; then
    echo "❌ Built app reports version $BUILT_VERSION, expected $MARKETING_VERSION"
    exit 1
fi
echo "✅ App version: $BUILT_VERSION"

# 3. Verify code signature
echo "🔏 Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ Signature valid"

# 4. Create DMG
echo "💿 Creating DMG..."

if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

DMG_SRC="dmg_source"
rm -rf "$DMG_SRC"
mkdir -p "$DMG_SRC"
cp -r "$APP_PATH" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"

hdiutil create -volname "$APP_NAME ${VERSION}" \
    -srcfolder "$DMG_SRC" \
    -ov -format UDZO \
    "$DMG_NAME"

rm -rf "$DMG_SRC"
echo "✅ DMG created: $DMG_NAME"

# 5. Sign the DMG
echo "🔏 Signing DMG..."
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_NAME"
echo "✅ DMG signed"

# 6. Notarize
if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "⏭️  Skipping notarization (SKIP_NOTARIZE=1)"
else
    echo "📨 Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$DMG_NAME" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "✅ Notarization approved"

    # 7. Staple the ticket to the DMG
    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$DMG_NAME"
    echo "✅ Ticket stapled"
fi

echo ""
echo "🎉 Release complete: $DMG_NAME"
echo ""
echo "Verify with:"
echo "  spctl --assess --type open --context context:primary-signature '$DMG_NAME'"
