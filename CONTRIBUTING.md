# Contributing to Vernet

Thank you for helping improve Vernet, a cross-platform network diagnostics
app built with Flutter. This document covers what you need to know before
opening an issue or a pull request.

## Reporting issues

- Bugs: use the [bug report template](https://github.com/osociety/vernet/issues/new?template=bug_report.md).
- Feature ideas: use the [feature request template](https://github.com/osociety/vernet/issues/new?template=feature_request.md).
- Questions and discussion: open a thread on [GitHub Discussions](https://github.com/osociety/vernet/discussions).

Please include your app version, platform (Android, iOS, macOS, Linux, or
Windows), and the network context (home Wi-Fi, hotspot, VPN, and so on) where
relevant.

## Development setup

1. Install the Flutter SDK (stable channel) plus the tooling for the platform
   you want to build for (Android SDK, Xcode, GTK, CocoaPods, or Visual Studio).
2. `flutter pub get`
3. Generated code (Drift tables, freezed models) is produced by build_runner:
   `dart run build_runner build --delete-conflicting-outputs`
   (`dart run build_runner watch` during development).

Before opening a PR, run:

```
dart format .
flutter analyze
flutter test
```

CI runs unit tests, analysis, and coverage on every PR. Integration tests run
on main after merge, so you do not need an emulator or device to contribute.

## Codebase layout

```
lib/
  pages/      UI screens for each tool
  widgets/    Reusable components
  services/   Networking and diagnostics logic
  models/     Data structures
  utils/      Helper functions
  providers/  State management
  routing/    Navigation configuration
```

UI must never perform network operations directly — it goes through the
service layer, which returns structured models. See [ARCHITECTURE.md](ARCHITECTURE.md)
for the system design and [AGENTS.md](AGENTS.md) for conventions that coding
agents follow.

## Pull requests

1. Branch from `main` with one focused change per PR.
2. Use conventional commit messages (`fix:`, `feat:`, `docs:`, `chore:`).
3. Reference the issue the PR closes (`Closes #123`).
4. Add or update unit/widget tests under `test/` for changed behavior.
5. Keep version bumps and changelog entries out of feature PRs — releases are
   prepared separately by the maintainer, and a version change merged to main
   triggers the release pipeline.
6. All PRs target `main` and are reviewed and merged by the maintainer.

## Licensing

By contributing, you agree that your contributions are licensed under the
[Apache License 2.0](LICENSE).
