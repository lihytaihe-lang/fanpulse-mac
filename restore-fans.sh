#!/bin/zsh
# Recovery wrapper for restoring control back to the system.
#
# This is the intended fallback path if a boost run is interrupted or the user simply wants
# to force a restore from the saved snapshot.
set -euo pipefail

# Always resolve relative to the script location.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Rebuild only when necessary.
if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

# Use the macOS-native privilege prompt for consistency with the boost path.
ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse restore\" with administrator privileges"
