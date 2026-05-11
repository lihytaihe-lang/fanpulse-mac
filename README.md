# fanpulse-mac

Short max-speed fan boosts for supported Apple Silicon Macs.

fanpulse-mac is a small macOS command-line tool that can temporarily push the fans on
supported M-series Macs to the maximum RPM reported by AppleSMC, then automatically hand
fan control back to macOS.

中文说明：fanpulse-mac 是一个 macOS 小工具，可以让支持的 M 系列 Mac 风扇短时间拉到机器最高转速进行散热，是比较激进的风扇策略，时间结束后自动把风扇控制交还给系统。

It is intentionally not a full fan-control app. The current release is a CLI plus simple
double-click launchers. A GUI may come later, but the first public version stays small and
easy to audit.

## What it does

- Reads the fans exposed by AppleSMC.
- Saves the current fan state before making changes.
- Temporarily switches fans into manual mode.
- Sets fan targets to the maximum RPM reported by the machine.
- Waits for the requested number of seconds.
- Restores fan control back to macOS.

中文功能：

- 读取 AppleSMC 暴露出来的风扇信息。
- 修改前保存当前风扇状态。
- 临时切换到手动风扇模式。
- 把风扇目标转速设置为机器报告的最高 RPM。
- 等待指定秒数。
- 自动恢复，让 macOS 重新接管风扇控制。
- M芯片开始，已经不支持设置风扇转速，它只有三档，最低、最高和系统控制。

## Safety note

fanpulse uses AppleSMC, a private macOS interface, and boost/restore operations require
administrator privileges. It has been tested on Apple Silicon Macs with active cooling, but
different machines may expose different SMC behavior.

On a new Mac, test with 1 second first.

中文提示：这个工具会访问 AppleSMC，并且需要管理员权限。它面向带风扇的 M 系列 Mac。第一次在新机器上使用时，建议先测试 1 秒。

## Compatibility

Verified on:

- Apple M4 Pro MacBook Pro
- Apple Silicon Mac mini with active cooling

Expected target:

- Apple Silicon / M-series Macs with fans
- macOS 12 or newer

Fanless MacBook Air models are not expected to do anything useful because they do not have
fans to control.

## Build

```bash
swift build
```

## Quick start

Default 10-second boost:

```bash
./boost.sh
```

Choose a custom duration in Terminal:

```bash
./boost.sh 20
```

Double-click in Finder:

```text
boost10.command
```

Double-click and choose a custom duration:

```text
boost-custom.command
```

中文快速使用：

- 双击 `boost10.command`：风扇加速 10 秒
- 双击 `boost-custom.command`：自己输入 1 到 60 秒
- 命令行运行 `./boost.sh 20`：风扇加速 20 秒
- 如果第一次在另一台 Mac 上使用，建议先运行 1 秒测试

## Commands

Check current fan status:

```bash
.build/debug/fanpulse status
```

Run a 10-second boost:

```bash
.build/debug/fanpulse boost 10
```

Restore fan control from the saved snapshot:

```bash
.build/debug/fanpulse restore
```

Probe known SMC keys for debugging:

```bash
.build/debug/fanpulse probe
```

## First test on another Mac

If you built from source:

```bash
swift build
.build/debug/fanpulse status
osascript -e 'do shell script "'$(pwd)'/.build/debug/fanpulse boost 1" with administrator privileges'
```

If you downloaded the portable zip:

1. Unzip `fanpulse-portable.zip`.
2. Run `./status.sh`.
3. Run `./boost.sh 1`.
4. If that works, use `boost10.command` or `boost-custom.command`.

## Portable package

Create a release zip:

```bash
./scripts/package-portable.sh
```

The generated file will be:

```text
dist/fanpulse-portable.zip
```

Upload that zip to GitHub Releases instead of committing built binaries into the source
repository.

## Development

```bash
swift test
zsh -n boost.sh
zsh -n boost10.command
zsh -n boost-custom.command
zsh -n boost20.sh
zsh -n restore-fans.sh
zsh -n restore-fans.command
```

## License

MIT
