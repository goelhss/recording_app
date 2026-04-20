#!/bin/bash
# Install RecordApp APK to connected Android device

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$SCRIPT_DIR/../../RecordApp-Android/app/build/outputs/apk/debug/app-debug.apk"

echo "=============================="
echo "  RecordApp Android — Install"
echo "=============================="

if [ ! -f "$APK" ]; then
    echo "APK not found. Run: bash scripts/android/build.sh"
    exit 1
fi

echo "Checking for connected device..."
if ! adb devices | grep -q "device$"; then
    echo "ERROR: No Android device detected."
    echo ""
    echo "To connect your phone:"
    echo "  1. Settings → About Phone → tap Build Number 7 times (enables Developer Options)"
    echo "  2. Settings → Developer Options → enable USB Debugging"
    echo "  3. Plug in phone via USB and tap 'Allow' on the phone"
    exit 1
fi

echo "Installing RecordApp..."
adb install -r "$APK"

echo ""
echo "Installed. Launching..."
adb shell am start -n com.recordapp/.MainActivity
