---
name: vernet-testing
description: Write and run Vernet tests across unit, widget and integration layers. Use when adding or fixing tests under test/ or integration_test/, testing the scan report feature, seeding drift data, checking phone and desktop layouts, or debugging CI failures on Windows.
---

# Vernet Testing

## Overview

Vernet has three test layers. Choose the cheapest layer that can prove the
behavior, mirror the source path, and keep platform-specific guards in mind.

| Layer | Location | Runner |
| --- | --- | --- |
| Unit (bloc, service, repository) | `test/` mirroring `lib/` | `flutter test` |
| Widget (pages, responsive layouts) | `test/pages/...` | `flutter test` |
| Integration (app flows on a device) | `integration_test/` | `flutter test integration_test -d macos` |

## Unit and widget tests

- Mirror the `lib/` path: `test/repository/scan_repository_test.dart`,
  `test/pages/host_scan_page/scan_history_page_test.dart`.
- Drift repository tests use `AppDatabase(NativeDatabase.memory())` and an
  `_InMemoryDatabaseService implements DatabaseService<AppDatabase>`; close the
  database in `tearDown`.
- Widget tests wrap pages with `wrapWithDarkThemeProvider` and pass repositories
  through the page constructor instead of `getIt` when the page supports it
  (`ScanHistoryPage`, `ScanDetailPage`).
- Do not call `pumpAndSettle` while an indeterminate `CircularProgressIndicator`
  is mounted; it never settles. Use a resolved fake, bounded `pump` calls, or
  test the bloc separately.
- Check both widths: `390x844` for phone and at least `1280x1000` for desktop.
  Set `tester.view.physicalSize` with `devicePixelRatio = 1` and reset it in
  `addTearDown`. Flutter reports `RenderFlex overflowed` automatically, so keep
  chips and status labels on `Flexible` + ellipsis.
- Assert ordering with `tester.getTopLeft(...).dy`, but re-measure after a
  reload; a stale Y from before a refresh compares against the wrong row.

## Integration tests

Everything runs through one entry point: `integration_test/app_test.dart`. Each
nested suite lives in its own file **without** the `_test.dart` suffix, exposes
`void main()`, and is imported and called from `app_test.dart`. This prevents
one app launch per file, which fails on macOS.

```dart
// integration_test/<feature>/<feature>.dart
void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ...
}
```

Setup per suite:

```dart
setUpAll(() async {
  NotificationService.skipPermissionRequests = true;
  if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
    configureDependencies(Env.test);
    await configureNetworkToolsFlutter((await getApplicationDocumentsDirectory()).path);
  }
});

setUp(() async {
  globals.testingActive = true;
  SharedPreferences.setMockInitialValues({});
  AppSettings.instance.resetForTesting();
  TestUtils.configureAndroidChannelMocks();
  await clearDatabase(); // integration_test/wifi_test/wifi_test_runner.dart
});
```

- Seed deterministic data through `getIt<ScanRepository>()` and
  `getIt<DeviceRepository>()`; pre-set ids so device rows link to scans.
- Wait for widgets with `TestUtils.waitForWidget` / `waitForAnyWidget`, not
  fixed sleeps.
- Drive the real app: `await tester.pumpWidget(const MyApp(true))`, navigate
  through home and app bars. Do not pump pages directly unless the suite is
  specifically about that page.
- For real scan flows, poll `getCurrentScanId()` and
  `ScanRepository.get(id)` until `onGoing == false`, then continue. Print and
  return early when the environment cannot scan so CI does not hang.
- An early return skips only the current run. When a production fix makes that
  flow run, everything past the guard executes for the first time, and a
  failure there is usually a latent test bug, not a regression from the fix.
  Check this before diagnosing a new CI failure.
- Runner subnets differ, so "passed on macOS" is weak evidence: the macOS
  runner is on `192.168.0.x` and a real scan finds nothing, while Linux and
  Windows sit on `10.1.0.0/24` and find devices. A test that branches on
  `deviceCount > 0` can only fail on the latter.
- Do not assert a widget type the page swaps by width. `ScanDetailPage` renders
  `_DesktopDeviceRow` at >=900px and `AdaptiveListTile` below; assert on text
  both layouts show, such as the device address or make.
- When a branch cannot be reached locally, force it once (seed devices for the
  live `scan.id`), then revert. Confirm the negative control as well: the old
  assertion must fail with the same error CI reported.
- Always clear the database in `setUp` and `tearDown`; suites share one app
  process and one database file.

The scan report suite is the reference implementation:
`integration_test/scan_report/scan_report.dart` covers empty history, desktop
table, phone cards, report navigation, in-progress and zero-device reports, and
a live scan end to end.

## Windows and test-mode guards

- `NotificationService.showNotificationWithActions` returns early when
  `globals.testingActive` is true, and on Windows unless
  `NotificationService.debugIgnorePlatformCheck` is true. Unit tests that
  verify the plugin call must set the flag in `setUp` and reset it in
  `tearDown`.
- Integration suites set `globals.testingActive = true` and
  `NotificationService.skipPermissionRequests = true`; never rely on real
  notification delivery.
- Mock `network_info_plus`, `permission_handler`, `package_info_plus` and local
  notifications through `TestUtils.configureAndroidChannelMocks()`.

## Commands

```bash
dart format <files you touched>        # never format the whole repo
dart analyze                           # or Dart MCP analyze_files
flutter test test/pages/<feature>      # focused unit/widget tests
flutter test                           # full unit suite
flutter test integration_test/scan_report/scan_report.dart -d macos
flutter test integration_test/app_test.dart -d macos  # all suites
```

Use the Dart MCP `analyze_files` tool for fast static checks and keep its output
clean before reporting done. GitHub MCP is available for PR and CI log
inspection, and browser-use for verifying UI behavior when a desktop device is
available. Do not pipe long `flutter test` runs through `tail` when you need the
exit code; it masks failures.

On macOS, keep the `vernet.app` window frontmost while a device suite runs. An
occluded window starves frames, and the live binding blocks every `pump()` on a
real frame, so the suite crawls to roughly one test per five minutes at ~0% CPU
and looks like a hang. The `expanded` reporter also repeats each test name at
start and completion, which reads as a loop but is not one.

## Definition of done

- [ ] Behavior is tested at the cheapest valid layer.
- [ ] Test files mirror `lib/` and unit/widget tests pass.
- [ ] New integration suite is imported into `integration_test/app_test.dart`.
- [ ] Phone (390px) and desktop (900px+) layouts are covered where UI changed.
- [ ] Tests seed and clear drift data through repositories.
- [ ] Windows-safe notification flags are set in notification tests.
- [ ] `dart analyze` and `flutter test` are clean.
