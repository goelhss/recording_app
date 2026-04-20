#!/bin/bash
# Install Homebrew if not present. No additional brew packages are needed for Phase 1.

echo "[2/2] Checking for Homebrew..."

if command -v brew &>/dev/null; then
    echo "  OK: $(brew --version | head -1)"
else
    echo "  Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo "  Homebrew installed at /opt/homebrew"
    else
        eval "$(/usr/local/bin/brew shellenv)"
        echo "  Homebrew installed at /usr/local"
    fi
fi
