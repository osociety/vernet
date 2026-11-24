import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/settings_category_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

/// Drives the network-category rows on the real app: each control has to write
/// through [AppSettings] to storage, and the reset row has to put the
/// recommended values back and show them.
///
/// The widget suite covers the same rows at phone and desktop widths; this is
/// the end-to-end check that the dropdowns and the switch really reach the
/// settings the scan reads.
void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final appSettings = AppSettings.instance;

  setUpAll(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(null));
    await tester.pumpAndSettle();
    await TestUtils.tapSettingsButton(tester, find);
  }

  Future<void> openNetworkCategory(WidgetTester tester) async {
    await TestUtils.tapSettingsCategory(
      WidgetKey.settingsNetworkCategory,
      tester,
      find,
    );
    await TestUtils.waitForWidget(
      tester,
      find.byKey(WidgetKey.scanTimeoutTile.key),
    );
  }

  /// Opens the dropdown on the row behind [row] and picks the option whose
  /// label is [label].
  Future<void> choose<T>(
    WidgetTester tester,
    WidgetKey row,
    String label,
  ) async {
    await TestUtils.scrollUntilVisibleByWidgetKey(row, tester, find, 200.0);
    await tester.pumpAndSettle();
    final dropdown = find.descendant(
      of: find.byKey(row.key),
      matching: find.byType(DropdownButton<T>),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The closed button keeps its items mounted, so the menu copy of the label
    // is the last one in the tree.
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<T> shownValue<T>(WidgetTester tester, WidgetKey row) async {
    await TestUtils.scrollUntilVisibleByWidgetKey(row, tester, find, 200.0);
    await tester.pumpAndSettle();
    return tester
        .widget<DropdownButton<T>>(
          find.descendant(
            of: find.byKey(row.key),
            matching: find.byType(DropdownButton<T>),
          ),
        )
        .value as T;
  }

  Future<void> toggleMdns(WidgetTester tester) async {
    await TestUtils.scrollUntilVisibleByWidgetKey(
      WidgetKey.mdnsDiscoveryTile,
      tester,
      find,
      200.0,
    );
    await TestUtils.tapByWidgetKey(
      WidgetKey.mdnsDiscoveryTile,
      tester,
      find,
    );
  }

  bool shownMdns(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(WidgetKey.mdnsDiscoveryTile.key))
      .value;

  group('scan behavior settings', () {
    testWidgets('each network-category control writes through to settings',
        (tester) async {
      await openSettings(tester);
      await openNetworkCategory(tester);
      final l10n = tester.element(find.byType(SettingsCategoryPage)).l10n;

      await choose<int>(tester, WidgetKey.scanTimeoutTile, '5s');
      expect(appSettings.scanTimeout, 5);
      expect(await shownValue<int>(tester, WidgetKey.scanTimeoutTile), 5);

      await choose<int>(tester, WidgetKey.scanConcurrencyTile, '64');
      expect(appSettings.scanConcurrency, 64);
      expect(
        await shownValue<int>(tester, WidgetKey.scanConcurrencyTile),
        64,
      );

      await choose<ScanPingMethod>(
        tester,
        WidgetKey.pingMethodTile,
        l10n.pingMethodIcmp,
      );
      expect(appSettings.pingMethod, ScanPingMethod.icmp);

      await toggleMdns(tester);
      expect(appSettings.mdnsEnabled, isFalse);
      expect(shownMdns(tester), isFalse);

      // The setters persist as they go; a reload reads the saved values back
      // and would restore the defaults if any write had been skipped.
      await appSettings.load();
      expect(appSettings.scanTimeout, 5);
      expect(appSettings.scanConcurrency, 64);
      expect(appSettings.pingMethod, ScanPingMethod.icmp);
      expect(appSettings.mdnsEnabled, isFalse);
    });

    testWidgets('reset row restores the recommended values in settings and UI',
        (tester) async {
      await appSettings.setScanTimeout(10);
      await appSettings.setScanConcurrency(16);
      await appSettings.setPingMethod(ScanPingMethod.icmp);
      await appSettings.setMdnsEnabled(false);

      await openSettings(tester);
      await openNetworkCategory(tester);

      expect(await shownValue<int>(tester, WidgetKey.scanTimeoutTile), 10);
      expect(await shownValue<int>(tester, WidgetKey.scanConcurrencyTile), 16);
      expect(
        await shownValue<ScanPingMethod>(tester, WidgetKey.pingMethodTile),
        ScanPingMethod.icmp,
      );

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.resetScanDefaultsButton,
        tester,
        find,
        200.0,
      );
      await TestUtils.tapByWidgetKey(
        WidgetKey.resetScanDefaultsButton,
        tester,
        find,
      );

      expect(appSettings.scanTimeout, 2);
      expect(
        appSettings.scanConcurrency,
        AppSettings.recommendedScanConcurrency,
      );
      expect(appSettings.pingMethod, ScanPingMethod.tcpFallback);
      expect(appSettings.mdnsEnabled, isTrue);
      // The mDNS row sits directly above the reset row, so it is still built
      // and shows the rebuilt value without scrolling back up.
      expect(shownMdns(tester), isTrue);

      // Reopening the category checks the rows above the fold against what was
      // persisted, through a fresh build of the page.
      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsCategoryBackButton,
        tester,
        find,
      );
      await openNetworkCategory(tester);
      expect(await shownValue<int>(tester, WidgetKey.scanTimeoutTile), 2);
      expect(
        await shownValue<int>(tester, WidgetKey.scanConcurrencyTile),
        AppSettings.recommendedScanConcurrency,
      );

      await appSettings.load();
      expect(appSettings.scanTimeout, 2);
      expect(
        appSettings.scanConcurrency,
        AppSettings.recommendedScanConcurrency,
      );
      expect(appSettings.pingMethod, ScanPingMethod.tcpFallback);
      expect(appSettings.mdnsEnabled, isTrue);
    });
  });
}
