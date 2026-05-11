# Security

fanpulse controls Mac fan behavior through AppleSMC and some operations require macOS
administrator privileges.

## Reporting a security issue

Please do not open a public issue for security-sensitive problems. Instead, contact the
maintainer privately through the repository owner's preferred contact method.

Useful details include:

- Mac model and chip.
- macOS version.
- The command or launcher used.
- What you expected to happen.
- What actually happened.

## Scope

Security-sensitive issues include:

- Privilege escalation bugs.
- Unsafe shell quoting or command execution.
- Failure to restore fan control after interruption.
- Behavior that could unexpectedly keep fans in manual mode.

General compatibility problems can be filed as normal GitHub issues.
