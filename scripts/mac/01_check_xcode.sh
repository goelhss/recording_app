#!/bin/bash
# Check for Swift / Xcode Command Line Tools and prompt to install if missing.
# Full Xcode IDE is NOT required — CLT provides the Swift compiler and macOS SDK.

echo "[1/2] Checking for Swift toolchain..."

if command -v swift &>/dev/null; then
    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    echo "  OK: $SWIFT_VERSION"
else
    echo "  Swift not found. Triggering Xcode Command Line Tools installation..."
    echo ""
    echo "  A dialog will appear asking you to install the Command Line Tools."
    echo "  Click 'Install' and wait for it to finish, then re-run this script."
    echo ""
    xcode-select --install 2>/dev/null || true
    echo "  After installation completes, re-run: bash scripts/mac/setup.sh"
    exit 1
fi

# Verify the macOS SDK is accessible
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")
if [ -z "$SDK_PATH" ]; then
    echo "  ERROR: macOS SDK not found. Try: sudo xcode-select --reset"
    exit 1
fi
echo "  SDK: $SDK_PATH"
