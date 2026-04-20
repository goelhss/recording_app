#!/bin/bash
# Launch RecordApp.app

echo "Kill the exiting RecordApp first"
pkill -x RecordApp 2>/dev/null && echo "RecordApp stopped." || echo "RecordApp was not running."


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$SCRIPT_DIR/../../build/mac/RecordApp.app"

if [ ! -d "$APP" ]; then
    echo "App not built yet. Run: bash scripts/mac/build.sh"
    exit 1
fi

echo "Launching RecordApp..."
open "$APP"
