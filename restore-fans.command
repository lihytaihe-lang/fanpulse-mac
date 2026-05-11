#!/bin/zsh
# Finder-friendly restore launcher.
#
# This mirrors the boost launcher: double-click, authenticate, restore, read the result.
set -euo pipefail

# Resolve relative to the script so the package remains portable.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Rebuild on demand if the binary is missing in a copied folder.
if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

# Use the standard macOS administrator password dialog.
ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse restore\" with administrator privileges"

# Keep the Terminal window open long enough for the user to read the result.
echo
echo "fanpulse restore finished."
echo "Press Enter to close this window."
read -r
