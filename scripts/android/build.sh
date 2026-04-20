#!/bin/bash
# Build RecordApp APK

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../RecordApp-Android"

echo "=============================="
echo "  RecordApp Android — Build"
echo "=============================="

cd "$PROJECT_DIR"

if [ ! -f "gradlew" ]; then
    echo "Gradle wrapper not found. Run: bash scripts/android/setup.sh"
    exit 1
fi

chmod +x gradlew
echo "Building debug APK..."
./gradlew assembleDebug 2>&1

APK="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK" ]; then
    echo ""
    echo "Build complete: $APK"
    echo "Install with:  bash scripts/android/install.sh"
else
    echo "ERROR: Build failed — APK not found"
    exit 1
fi
