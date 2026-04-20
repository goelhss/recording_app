#!/bin/bash
# One-time setup for Android builds

set -e

echo "=============================="
echo "  RecordApp Android — Setup"
echo "=============================="

# Java 17+
if ! command -v java &>/dev/null; then
    echo "ERROR: Java not found. Install with: brew install openjdk@17"
    echo "Then add to ~/.zshrc:  export PATH=\"/opt/homebrew/opt/openjdk@17/bin:\$PATH\""
    exit 1
fi
echo "✓ Java: $(java -version 2>&1 | head -1)"

# adb (Android platform tools)
if ! command -v adb &>/dev/null; then
    echo ""
    echo "adb not found. Install Android platform tools:"
    echo "  brew install android-platform-tools"
    echo ""
    echo "Also install Android Studio for the full SDK:"
    echo "  https://developer.android.com/studio"
    echo ""
    echo "After installing, add to ~/.zshrc:"
    echo '  export ANDROID_HOME=$HOME/Library/Android/sdk'
    echo '  export PATH=$PATH:$ANDROID_HOME/platform-tools'
    exit 1
fi
echo "✓ adb: $(adb version | head -1)"

# Gradle wrapper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../RecordApp-Android"
cd "$PROJECT_DIR"

if [ ! -f "gradlew" ]; then
    echo ""
    echo "Generating Gradle wrapper..."
    if command -v gradle &>/dev/null; then
        gradle wrapper --gradle-version 8.6
    else
        echo "ERROR: gradle not found. Install with: brew install gradle"
        exit 1
    fi
    chmod +x gradlew
fi

echo ""
echo "✓ Setup complete."
echo "Run: bash scripts/android/build.sh"
