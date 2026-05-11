#!/bin/zsh
# Finder-friendly launcher for the most common use case: a 10-second fan pulse.
#
# `.command` files open in Terminal when double-clicked, which makes this a very convenient
# entry point for non-terminal users.
set -euo pipefail

# Resolve relative to the script so the folder stays portable.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Rebuild on demand if the binary is missing in a copied folder.
if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

# Use the standard macOS administrator password dialog.
ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse boost 10\" with administrator privileges"

# Keep the Terminal window open long enough for the user to read the result.
echo
echo "Done. The fans were boosted for 10 seconds."
echo "完成。风扇已经加速运行了 10 秒。"
echo
echo "Fan control has been handed back to macOS."
echo "风扇控制已经交还给 macOS。"
echo
echo "Press Return to close this window."
echo "按 Return 关闭这个窗口。"
read -r
