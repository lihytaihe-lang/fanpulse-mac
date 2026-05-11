#!/bin/zsh
# Build a small zip that can be copied to another Apple Silicon Mac.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
PACKAGE_DIR="${DIST_DIR}/fanpulse-portable"
ZIP_PATH="${DIST_DIR}/fanpulse-portable.zip"

cd "$PROJECT_DIR"

swift build -c release

rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"

cp ".build/release/fanpulse" "$PACKAGE_DIR/fanpulse"

cat > "$PACKAGE_DIR/boost.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

SECONDS_ARG="${1:-10}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

osascript -e "do shell script \"cd \\\"${SCRIPT_DIR}\\\" && ./fanpulse boost ${SECONDS_ARG}\" with administrator privileges"
EOF

cat > "$PACKAGE_DIR/boost10.command" <<'EOF'
#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

osascript -e "do shell script \"cd \\\"${SCRIPT_DIR}\\\" && ./fanpulse boost 10\" with administrator privileges"

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
EOF

cat > "$PACKAGE_DIR/boost-custom.command" <<'EOF'
#!/bin/zsh
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

osascript -e "do shell script \"cd \\\"${SCRIPT_DIR}\\\" && ./fanpulse boost ${SECONDS_ARG}\" with administrator privileges"

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
EOF

cat > "$PACKAGE_DIR/restore-fans.command" <<'EOF'
#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

osascript -e "do shell script \"cd \\\"${SCRIPT_DIR}\\\" && ./fanpulse restore\" with administrator privileges"

echo
echo "Restore finished."
echo "恢复完成。"
echo
echo "Fan control has been handed back to macOS."
echo "风扇控制已经交还给 macOS。"
echo
echo "Press Return to close this window."
echo "按 Return 关闭这个窗口。"
read -r
EOF

cat > "$PACKAGE_DIR/status.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

./fanpulse status
EOF

cat > "$PACKAGE_DIR/README.txt" <<'EOF'
fanpulse-mac portable package

Short max-speed fan boosts for supported Apple Silicon / M-series Macs.

fanpulse-mac can temporarily push the fans to the maximum RPM reported by the machine,
then automatically hand fan control back to macOS.

fanpulse-mac 可以让支持的 M 系列 Mac 风扇短时间拉到机器报告的最高转速，
然后自动把风扇控制交还给 macOS。

What to copy

- Copy this whole folder, or copy fanpulse-portable.zip and unzip it on the other Mac.

How to use

1. Double-click boost10.command
2. Enter the macOS administrator password when prompted
3. Wait 10 seconds
4. The tool restores system fan control automatically

Custom duration

- Double-click boost-custom.command
- Enter a whole number from 1 to 60 seconds
- Press Return, then enter the macOS administrator password when prompted

自定义秒数

- 双击 boost-custom.command
- 输入 1 到 60 之间的整数秒数
- 按 Return，然后根据提示输入 macOS 管理员密码

Command line

- ./boost.sh
- ./boost.sh 10
- ./boost.sh 20
- ./status.sh
- ./restore-fans.command

First run on another Mac

1. Run ./status.sh
2. Run ./boost.sh 1
3. If that works, use boost10.command or ./boost.sh 10

Notes

- Designed for Apple Silicon Macs with active cooling.
- Test 1 second first on a new machine.
- If needed, use restore-fans.command to hand control back to the system.
EOF

chmod +x "$PACKAGE_DIR/fanpulse"
chmod +x "$PACKAGE_DIR/boost.sh"
chmod +x "$PACKAGE_DIR/boost10.command"
chmod +x "$PACKAGE_DIR/boost-custom.command"
chmod +x "$PACKAGE_DIR/restore-fans.command"
chmod +x "$PACKAGE_DIR/status.sh"

(
  cd "$DIST_DIR"
  /usr/bin/zip -qr "$(basename "$ZIP_PATH")" "$(basename "$PACKAGE_DIR")"
)

echo "Created ${ZIP_PATH}"
