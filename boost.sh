#!/bin/zsh
# Generic wrapper around the Swift binary.
#
# This script exists so users do not need to remember the full boost command or manually deal
# with privilege escalation every time they want a short fan pulse.
set -euo pipefail

# Default to 10 seconds because that is the most common practical use.
SECONDS_ARG="${1:-10}"

# Always resolve relative to the script itself so the whole folder can be moved around.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Rebuild only if the expected binary does not exist.
if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

# Use the standard macOS admin prompt instead of requiring manual sudo usage.
ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse boost ${SECONDS_ARG}\" with administrator privileges"
