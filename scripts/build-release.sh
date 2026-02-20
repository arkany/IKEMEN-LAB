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
VERSION="v1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
SIGNING_IDENTITY="Developer ID Application"

echo "🚀 Starting release build for ${APP_NAME} ${VERSION}..."

# 1. Archive for distribution
echo "📦 Archiving project..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
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
