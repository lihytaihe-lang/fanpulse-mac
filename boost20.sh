#!/bin/zsh
# Convenience wrapper for a fixed 20-second boost window.
#
# This exists alongside `boost.sh` because some use cases want a single-purpose launcher with
# no arguments and no ambiguity.
set -euo pipefail

# Always work relative to the script location so the project folder can be moved.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Rebuild if the binary is missing in this copy of the folder.
if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

# Ask macOS for administrator privileges using the standard GUI prompt.
ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse boost 20\" with administrator privileges"
