# Contributing

Thanks for helping improve fanpulse.

This project is intentionally small: a Swift command-line tool plus a few macOS-friendly
launcher scripts. For now, please keep contributions focused on that shape. A GUI may come
later, but it is not part of the current release plan.

## Good first areas

- Improve compatibility notes for specific Mac models.
- Improve user-facing wording in the launcher scripts.
- Add tests for parsing, status formatting, or snapshot behavior.
- Improve packaging and release automation.
- Add safer diagnostics that help users report what their Mac exposes.

## Before opening a pull request

```bash
swift test
zsh -n boost.sh
zsh -n boost10.command
zsh -n boost-custom.command
zsh -n boost20.sh
zsh -n restore-fans.sh
zsh -n restore-fans.command
```

If your change touches hardware behavior, please include:

- Mac model and chip.
- macOS version.
- Output from `fanpulse status` when safe to share.
- What command you ran and what happened.

## Hardware safety

fanpulse talks to AppleSMC, a private macOS interface. Please avoid changes that turn this
tool into a long-running fan controller or replace macOS thermal management. The intended
use case is short manual fan boosts, followed by restoring control back to macOS.
