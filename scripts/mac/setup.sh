#!/bin/bash
# Master setup script — runs all steps in order

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "  RecordApp macOS — Environment Setup"
echo "======================================"
echo ""

bash "$SCRIPT_DIR/01_check_xcode.sh"
bash "$SCRIPT_DIR/02_install_homebrew.sh"

echo ""
echo "Setup complete. Run ./scripts/mac/build.sh to build the app."
