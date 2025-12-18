#!/bin/bash
# Build MAME for macOS as a framework
# Usage: ./scripts/build-mame-macos.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAME_DIR="$PROJECT_ROOT/mame"
BUILD_DIR="$PROJECT_ROOT/build"
FRAMEWORK_DIR="$BUILD_DIR/MAMECore.framework"

echo "=== Building MAME for macOS ==="
echo "Project root: $PROJECT_ROOT"
echo "MAME directory: $MAME_DIR"

# Check for MAME submodule
if [ ! -d "$MAME_DIR" ]; then
    echo "Error: MAME submodule not found at $MAME_DIR"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
echo "Building for architecture: $ARCH"

# Create build directory
mkdir -p "$BUILD_DIR"

cd "$MAME_DIR"

# Build MAME with Metal backend
echo "=== Compiling MAME (this will take a while) ==="
make \
    SUBTARGET=mame \
    OSD=sdl \
    USE_BGFX=1 \
    BGFX_BACKEND=metal \
    NOWERROR=1 \
    OPTIMIZE=3 \
    -j$(sysctl -n hw.ncpu)

echo "=== Creating framework structure ==="
mkdir -p "$FRAMEWORK_DIR/Headers"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Resources"

# Copy binary (placeholder - actual integration TBD)
# cp "$MAME_DIR/mame" "$FRAMEWORK_DIR/MAMECore"

# Create module map
cat > "$FRAMEWORK_DIR/Modules/module.modulemap" << 'EOF'
framework module MAMECore {
    umbrella header "MAMECore.h"
    export *
    module * { export * }
}
EOF

# Create Info.plist
cat > "$FRAMEWORK_DIR/Resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MAMECore</string>
    <key>CFBundleIdentifier</key>
    <string>com.macmame.MAMECore</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MAMECore</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.261</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF

echo "=== Build complete ==="
echo "Framework created at: $FRAMEWORK_DIR"
echo ""
echo "Note: This script creates the framework structure."
echo "Full MAME integration requires additional work in Phase 1."
