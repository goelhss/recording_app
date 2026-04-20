#!/bin/bash
# Build RecordApp.app from source using swift build, then package as a .app bundle.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../RecordApp-macOS"
OUTPUT_DIR="$SCRIPT_DIR/../../build/mac"

echo "=============================="
echo "  RecordApp macOS — Build"
echo "=============================="

# Verify swift is available
if ! command -v swift &>/dev/null; then
    echo "ERROR: Swift not found. Run scripts/mac/setup.sh first."
    exit 1
fi

cd "$PROJECT_DIR"

echo ""
echo "Resolving Swift packages (may download WhisperKit ~150 MB on first run)..."
swift package resolve 2>&1

echo ""
echo "Building release binary..."
swift build -c release 2>&1

BINARY="$PROJECT_DIR/.build/release/RecordApp"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Build succeeded but binary not found at $BINARY"
    exit 1
fi

echo ""
echo "Packaging RecordApp.app bundle..."
APP_BUNDLE="$OUTPUT_DIR/RecordApp.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/RecordApp"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

echo ""
echo "Signing with ad-hoc signature (microphone entitlements)..."
codesign \
    --sign - \
    --entitlements "$PROJECT_DIR/RecordApp.entitlements" \
    --force \
    --deep \
    "$APP_BUNDLE"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "Run with:  bash scripts/mac/run.sh"
echo "Or double-click: $APP_BUNDLE"
