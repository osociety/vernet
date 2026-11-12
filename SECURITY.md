# Security Policy

## Supported versions

Security fixes are made against the latest released version. Older releases
do not receive patches — please upgrade before reporting.

| Version | Supported |
|---------|-----------|
| 1.6.x   | Yes       |
| < 1.6.0 | No        |

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting: open the repository's
**Security** tab and choose **Report a vulnerability**. This keeps your report
private until a fix is released.

Please include:

- The affected app version and platform (Android, iOS, macOS, Linux, Windows).
- Steps to reproduce, or a proof of concept where feasible.
- Your assessment of the impact.

This is a solo-maintained project, so triage and fixes happen in best-effort
fashion — expect an initial response within a few days. Reports will be
handled as coordinated disclosure, and you will be credited in the release
notes if you wish.

## Scope

- **In scope:** the Vernet application code, its bundled assets, and the
  build/release configuration in this repository.
- **Out of scope:** issues in third-party services Vernet talks to (please
  report those upstream), and findings that require a device you do not own.

Vernet is a network diagnostics tool. It surfaces information about networks
you operate and does not replace a professional security audit; its findings
are informational.

## Attribution

Thanks to everyone who reports issues responsibly.
