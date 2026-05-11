# fanpulse-mac

Short max-speed fan boosts for supported Apple Silicon Macs.

fanpulse-mac is a small macOS command-line tool that temporarily asks supported M-series
Macs to enter the maximum fan/cooling state reported through AppleSMC, then automatically
hands fan control back to macOS.

中文说明：fanpulse-mac 是一个 macOS 小工具，可以让支持的 M 系列 Mac 短时间进入机器报告的最高风扇/散热状态。这是比较激进的临时散热策略，时间结束后会自动把风扇控制交还给系统。

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

## Apple Silicon fan behavior notes

Part of the reason this project is open source is to share the hardware behavior we found
while validating AppleSMC fan keys on real Apple Silicon Macs.

On the tested M-series Macs, fan control does not behave like a smooth, arbitrary RPM
slider. The practical states exposed through the keys we tested are closer to:

- System-managed control, where macOS owns fan decisions.
- A forced/manual high-cooling state, where fanpulse asks each fan to target the
  machine-reported maximum RPM.
- Minimum/idle values reported by SMC, which are useful for status/probing but are not
  treated as a custom fan curve.

Because of that, fanpulse deliberately offers short max-speed pulses and explicit restore.
It does not try to provide persistent RPM tuning, fan curves, or background thermal policy.

中文记录：

这个项目开源的一部分意义，是把我们在真实 Apple Silicon 机器上验证 AppleSMC 风扇 key 时摸到的行为分享清楚。

在已测试的 M 系列 Mac 上，风扇控制并不像很多旧工具那样是一个可以任意指定 RPM 的连续滑杆。我们观察到实际可用的状态更接近：

- 系统自动控制，由 macOS 接管风扇决策。
- 手动/强制高散热，让风扇目标指向机器报告的最高 RPM。
- SMC 报告的最低/空闲值，可以用于 `status` 和 `probe` 观察，但 fanpulse 不把它当作自定义风扇曲线来使用。

所以 fanpulse 只做短时间最高转速脉冲和明确恢复；它不做长期常驻的转速曲线、后台热管理，也不假装能精细调 RPM。

## Safety note

fanpulse uses AppleSMC, a private macOS interface, and boost/restore operations require
administrator privileges. It has been tested on Apple Silicon Macs with active cooling, but
different machines may expose different SMC behavior.

On a new Mac, test with 1 second first.

中文提示：这个工具会访问 AppleSMC，并且需要管理员权限。它面向带风扇的 M 系列 Mac。第一次在新机器上使用时，建议先测试 1 秒。

## Compatibility

Verified on:

- 16-inch MacBook Pro with M4 Pro
- Mac mini with M4 Pro

中文已验证机型：

- 16 英寸 MacBook Pro（M4 Pro）
- Mac mini（M4 Pro）

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
