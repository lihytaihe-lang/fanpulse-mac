# Release and Promotion Checklist

This document is a practical checklist for preparing `fanpulse-mac` for broader public promotion.

fanpulse should be promoted as a small Apple Silicon cooling-pulse utility, not as a general fan-control replacement.

## Core positioning

Short version:

> fanpulse-mac is a tiny open-source CLI that gives supported Apple Silicon Macs a short max-speed cooling pulse, then automatically hands fan control back to macOS.

Longer version:

> I built fanpulse-mac because Apple Silicon fan scheduling can feel conservative during heavy workloads. Instead of making a full fan-control app or a persistent fan-curve daemon, fanpulse only does one thing: short max-speed cooling pulses with explicit automatic restore.

Chinese version:

> fanpulse-mac 是一个开源的小型 Apple Silicon Mac 散热脉冲工具：不做长期风扇曲线，不做后台常驻，只在需要的时候短时间拉高风扇，然后自动把控制权交还给 macOS。

## What to finish before broad promotion

### 1. Create a GitHub Release

Create a first public release:

- Tag: `v0.1.0`
- Release title: `v0.1.0 - First public release`
- Asset: `fanpulse-portable.zip`

Build the portable package locally:

```bash
./scripts/package-portable.sh
```

Then upload:

```text
dist/fanpulse-portable.zip
```

Do not commit built binaries into the repository.

### 2. Add a screenshot or short GIF

Recommended assets:

- Terminal screenshot showing `fanpulse status`.
- Terminal screenshot showing `fanpulse boost 10`.
- Optional short GIF showing double-click launcher behavior.

Keep screenshots simple and trustworthy. Avoid over-designed marketing images for the first release.

### 3. Expand compatibility reports

Current verified models:

| Model | Chip | Fan count | Status | Boost | Restore |
| --- | --- | ---: | --- | --- | --- |
| 16-inch MacBook Pro | M4 Pro | 2 | Verified | Verified | Verified |
| Mac mini | M4 Pro | 1 | Verified | Verified | Verified |

Ask testers to report:

- Mac model
- Chip
- macOS version
- Number of fans detected
- Whether `status` works
- Whether `boost 1` works
- Whether `restore` works
- Any warnings, strange RPM values, or failed SMC keys

Suggested issue title:

```text
Compatibility report: <Model> / <Chip> / <macOS version>
```

### 4. Keep risk boundaries visible

Always mention:

- It uses AppleSMC, a private macOS interface.
- Boost/restore operations require administrator privileges.
- Different machines may expose different SMC behavior.
- First test on a new machine should be `boost 1`.
- Fanless MacBook Air models are not expected to benefit.

Do not claim universal support for all M-series Macs until compatibility evidence exists.

## How to describe the project

### Good wording

Use these phrases:

- Short max-speed cooling pulse
- Automatic restore to macOS fan control
- Apple Silicon / M-series Macs with fans
- Open-source and easy to audit
- Small CLI, no background daemon
- Useful before or during heavy workloads

### Avoid this wording

Avoid saying:

- Universal Mac fan control
- Precise RPM tuning for all Apple Silicon Macs
- Better than macOS thermal management
- Replaces full fan-control apps
- Safe on every M-series Mac
- Guaranteed to reduce temperature or improve performance

## Suggested launch post

### English

```text
I open-sourced fanpulse-mac: a tiny Apple Silicon Mac cooling-pulse CLI.

It does not try to be a full fan-control app. It only does one thing: ask supported M-series Macs for a short max-speed fan/cooling burst, then automatically restore fan control back to macOS.

Why I built it:
- Apple Silicon fan scheduling can feel conservative during heavy workloads
- Sometimes I just want a short pre-cooling / cooling burst
- I did not want a background daemon or persistent fan curve
- I wanted the AppleSMC behavior to be visible and auditable

Tested so far on:
- 16-inch MacBook Pro M4 Pro
- Mac mini M4 Pro

Because it uses AppleSMC private interfaces, please test with `boost 1` first on any new machine.

Repo: https://github.com/lihytaihe-lang/fanpulse-mac
```

### Chinese

```text
我开源了一个小工具 fanpulse-mac，用来给带风扇的 Apple Silicon Mac 做短时间散热脉冲。

它不是完整风扇控制 App，也不做长期风扇曲线和后台常驻。它只做一件事：在你需要的时候短时间拉高风扇，然后自动把控制权交还给 macOS。

我做它的原因：
- Apple Silicon 的风扇调度有时候比较保守
- 本地 LLM、编译、视频导出等高负载场景下，偶尔想主动提前散热
- 不想长期跑一个风扇曲线或后台守护进程
- 想把 AppleSMC 风扇行为的实机验证记录开源出来

目前验证过：
- 16-inch MacBook Pro M4 Pro
- Mac mini M4 Pro

因为它使用 AppleSMC 私有接口，新机器建议先 `boost 1` 测试。

Repo: https://github.com/lihytaihe-lang/fanpulse-mac
```

## Platform notes

### GitHub

Recommended before pinning or sharing widely:

- Add repository topics:
  - `macos`
  - `apple-silicon`
  - `smc`
  - `fan-control`
  - `swift`
  - `cli`
- Create `v0.1.0` release.
- Add a screenshot or GIF to the README.
- Open an issue template for compatibility reports.

### X / Twitter

Keep it short and technical. Lead with the difference from full fan-control tools:

```text
I open-sourced fanpulse-mac.

It is not a full fan-control app. It is a tiny Apple Silicon CLI for short max-speed cooling pulses, then automatic restore back to macOS.

Built for heavy workloads like local LLMs, builds, exports, and summer desktop use.

Repo: https://github.com/lihytaihe-lang/fanpulse-mac
```

### Reddit / Hacker News / V2EX

Use a transparent technical tone.

Recommended title:

```text
I made a small Apple Silicon Mac cooling-pulse CLI that restores control back to macOS
```

Avoid sounding like a performance miracle. Emphasize the scope and risk boundary.

## Future improvements

Good next steps after the first release:

- Add issue templates for compatibility reports and bug reports.
- Add a README screenshot/GIF.
- Add a small `--json` output mode for status/probe.
- Add more tested Apple Silicon models.
- Add a safer dry-run mode that prints detected fans and intended operations.
- Consider a minimal GUI only after the CLI behavior is stable across more machines.

## Release note draft

```markdown
## v0.1.0 - First public release

First public release of fanpulse-mac.

fanpulse-mac is a small macOS CLI for supported Apple Silicon Macs with fans. It provides short max-speed cooling pulses and automatically restores fan control back to macOS.

### Included

- `fanpulse status`
- `fanpulse boost <seconds>`
- `fanpulse restore`
- `fanpulse probe`
- Shell launchers for 10-second and custom-duration boosts
- Portable package script

### Verified on

- 16-inch MacBook Pro M4 Pro
- Mac mini M4 Pro

### Safety notes

This tool uses AppleSMC private interfaces and requires administrator privileges for boost/restore operations. On any new machine, test with `boost 1` first.
```
