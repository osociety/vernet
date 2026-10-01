---
name: flutter-test-repair
description: "Fix Flutter or Dart unit, widget, and integration-test failures, including CI failures, emulator/device setup, plugin behavior, permissions, and platform-specific test issues."
argument-hint: "Failing test path, command, output, platform, or CI run URL"
---

# Flutter Test Repair

Use this when a Vernet test fails locally or in CI, or when configuring an existing unit, widget, or integration-test workflow.

## Procedure

1. Identify the exact failing test, command, platform, and first project-owned stack frame. For CI failures, inspect the job log and workflow before assuming the test itself is defective.
2. Classify the test as unit, widget, or integration. Read the nearest test and implementation; for app structure or ownership questions, use the repository graph when present and consult `ARCHITECTURE.md` for structural changes.
3. Reproduce with the narrowest exact command. Check the available Flutter devices before running device-dependent tests. For plugin, notification, network, or permission failures, separate unsupported test-environment behavior from a production defect and use deterministic fakes where appropriate.
4. Make one focused change and add or update a regression assertion for the failure. Preserve the existing test architecture and avoid weakening assertions, adding timing sleeps, or depending on live DNS/network state.
5. Immediately rerun the exact failing test. Then run `flutter analyze` for affected Dart changes. Use the repository's established integration-test command and an available device; do not claim device or platform coverage that was not run.
6. If the failure is environmental, report the concrete blocker and the strongest test that did pass; do not mask it with broad catches or unrelated code changes.

## Vernet-specific checks

- Keep networking in services and UI tests focused on visible behavior.
- Guard native plugin calls in tests where the platform implementation is unavailable.
- Treat database lifecycle and cleanup as concurrency concerns; avoid parallel tests that share the same SQLite database.
- After Dart/Flutter code changes, hot reload or hot restart an attached app when one is available.
