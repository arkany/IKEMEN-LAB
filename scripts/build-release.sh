#!/bin/bash

# Configuration
APP_NAME="IKEMEN Lab"
SCHEME="IKEMEN Lab"
VERSION="v0.6.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"

echo "🚀 Starting release build for ${APP_NAME} ${VERSION}..."

# 1. Clean and Build
echo "📦 Building project..."
xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    -quiet

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found at $APP_PATH"
    exit 1
fi

echo "✅ Build successful"

# 2. Create DMG
echo "💿 Creating DMG..."

# Remove existing DMG if it exists
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Create temporary folder for DMG content
DMG_SRC="dmg_source"
mkdir -p "$DMG_SRC"
cp -r "$APP_PATH" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME ${VERSION}" \
    -srcfolder "$DMG_SRC" \
    -ov -format UDZO \
    "$DMG_NAME"

# Cleanup
rm -rf "$DMG_SRC"

echo "🎉 Release created: $DMG_NAME"
