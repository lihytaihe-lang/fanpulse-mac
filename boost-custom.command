#!/bin/zsh
# Finder-friendly launcher for a custom-duration fan pulse.
#
# This keeps the project as a small CLI tool while still giving non-terminal users an easy
# way to choose how long the boost should run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Fan Boost / 风扇加速"
echo
echo "How long should the fans run faster?"
echo "你想让风扇加速运行几秒？"
echo
echo "Type a number from 1 to 60 seconds, then press Return."
echo "请输入 1 到 60 之间的秒数，然后按 Return。"
printf "Seconds / 秒数 (default 默认 10): "
read -r SECONDS_ARG

if [[ -z "${SECONDS_ARG}" ]]; then
  SECONDS_ARG="10"
fi

if ! [[ "${SECONDS_ARG}" =~ '^[0-9]+$' ]] || (( SECONDS_ARG < 1 || SECONDS_ARG > 60 )); then
  echo
  echo "That does not look like a valid number of seconds."
  echo "这个秒数看起来不太对。"
  echo
  echo "Please run this again and enter a whole number from 1 to 60."
  echo "请重新打开，并输入 1 到 60 之间的整数。"
  echo
  echo "Press Return to close this window."
  echo "按 Return 关闭这个窗口。"
  read -r
  exit 1
fi

if [[ ! -x .build/debug/fanpulse ]]; then
  swift build
fi

ESCAPED_DIR="${SCRIPT_DIR//\"/\\\"}"
osascript -e "do shell script \"cd \\\"${ESCAPED_DIR}\\\" && .build/debug/fanpulse boost ${SECONDS_ARG}\" with administrator privileges"

echo
echo "Done. The fans were boosted for ${SECONDS_ARG} seconds."
echo "完成。风扇已经加速运行了 ${SECONDS_ARG} 秒。"
echo
echo "Fan control has been handed back to macOS."
echo "风扇控制已经交还给 macOS。"
echo
echo "Press Return to close this window."
echo "按 Return 关闭这个窗口。"
read -r
