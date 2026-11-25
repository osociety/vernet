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
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

/// Drives the trust registry on the real app: adding a device by MAC, filtering
/// the list, revoking trust and forgetting the row all have to reach the drift
/// database behind the settings row.
///
/// The row this suite creates is forgotten again at the end, so a device with a
/// real registry keeps what it had before the run.
void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testMac = '00-1A-2B-3C-4D-5E';
  const testName = 'Vernet trust test';

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

  /// Scrolls the settings category list itself.
  ///
  /// `TestUtils.scrollUntilVisibleByWidgetKey` falls back to the first
  /// `Scrollable` in the tree when the target is not built yet, and on a
  /// desktop window that first one is the sidebar, not this list.
  Future<void> revealInSettings(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsCategoryPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNetworkCategory(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(null));
    await tester.pumpAndSettle();
    await TestUtils.tapSettingsButton(tester, find);
    await TestUtils.tapSettingsCategory(
      WidgetKey.settingsNetworkCategory,
      tester,
      find,
    );
    await TestUtils.waitForWidget(
      tester,
      find.byType(SettingsCategoryPage),
    );
  }

  Future<void> openTrustedDevices(WidgetTester tester) async {
    await openNetworkCategory(tester);
    final tile = find.byKey(WidgetKey.trustedDevicesTile.key);
    await revealInSettings(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await TestUtils.waitForWidget(
      tester,
      find.byKey(WidgetKey.trustedDevicesAddManuallyButton.key),
    );
  }

  Finder rowMenu() => find.descendant(
        of: find.ancestor(
          of: find.text(testName),
          matching: find.byType(AdaptiveListTile),
        ),
        matching: find.byIcon(Icons.adaptive.more),
      );

  testWidgets('adds, filters, revokes and forgets a device through the page',
      (tester) async {
    await openTrustedDevices(tester);
    final l10n = tester.element(find.byType(TrustedDevicesPage)).l10n;

    await tester.tap(
      find.byKey(WidgetKey.trustedDevicesAddManuallyButton.key),
    );
    await tester.pumpAndSettle();
    await TestUtils.enterTextByKey(
      WidgetKey.trustedDevicesMacField,
      testMac,
      tester,
      find,
    );
    await TestUtils.enterTextByKey(
      WidgetKey.trustedDevicesNameField,
      testName,
      tester,
      find,
    );
    await TestUtils.hideKeyboard(tester);
    await tester.tap(find.byKey(WidgetKey.trustedDevicesAddButton.key));
    await tester.pumpAndSettle();

    expect(find.text(l10n.trustedDevicesAdded), findsOneWidget);
    await TestUtils.waitForWidget(tester, find.text(testName));

    await tester.tap(find.byKey(WidgetKey.trustedDevicesFilterUntrusted.key));
    await tester.pumpAndSettle();
    expect(find.text(testName), findsNothing);

    await tester.tap(find.byKey(WidgetKey.trustedDevicesFilterTrusted.key));
    await tester.pumpAndSettle();
    await TestUtils.waitForWidget(tester, find.text(testName));

    await tester.tap(rowMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.trustedDevicesUntrustAction));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.deviceTrustMarkedUntrusted(testName)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(WidgetKey.trustedDevicesFilterUntrusted.key));
    await tester.pumpAndSettle();
    await TestUtils.waitForWidget(tester, find.text(testName));

    await tester.tap(rowMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.trustedDevicesForget));
    await tester.pumpAndSettle();
    expect(find.text(l10n.trustedDevicesForgetConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.trustedDevicesForget).last);
    await tester.pumpAndSettle();

    expect(find.text(testName), findsNothing);
    expect(find.text(l10n.trustedDevicesForgotten), findsOneWidget);
  });

  testWidgets('network settings expose the trust registry and its alerts',
      (tester) async {
    await openNetworkCategory(tester);
    final l10n = tester.element(find.byType(SettingsCategoryPage)).l10n;

    final tile = find.byKey(WidgetKey.trustedDevicesTile.key);
    await revealInSettings(tester, tile);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(l10n.trustedDevicesTitle),
      ),
      findsOneWidget,
    );

    final autoTrust = find.byKey(WidgetKey.autoTrustNewDevicesSwitch.key);
    await revealInSettings(tester, autoTrust);
    expect(
      tester.widget<SwitchListTile>(autoTrust).value,
      isFalse,
    );

    final notify = find.byKey(WidgetKey.notifyUntrustedDevicesSwitch.key);
    await revealInSettings(tester, notify);
    expect(tester.widget<SwitchListTile>(notify).value, isTrue);

    await tester.tap(notify);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.notifyUntrustedDevices, isFalse);
    await AppSettings.instance.load();
    expect(AppSettings.instance.notifyUntrustedDevices, isFalse);
  });
}
