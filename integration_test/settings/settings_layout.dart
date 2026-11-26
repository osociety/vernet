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
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

/// Drives the settings categories on the real app: every category has to reach
/// its rows under the section headings it advertises, and on a phone-width
/// window a category has to open as a page of its own instead of drawing its
/// header under the shell's AppBar.
///
/// The widget suite covers the same rows and widths; this is the end-to-end
/// check that the real shell, scrollables and navigation carry the layout.
void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    await TestUtils.waitForWidget(
      tester,
      find.byKey(WidgetKey.resetAllSettingsButton.key),
    );
  }

  Future<void> openCategory(WidgetTester tester, WidgetKey category) async {
    await TestUtils.tapSettingsCategory(category, tester, find);
    await TestUtils.waitForWidget(tester, find.byType(SettingsCategoryPage));
  }

  Future<void> expectHeading(WidgetTester tester, String heading) async {
    final target = find.text(heading);
    await TestUtils.revealWithin(
      tester,
      target,
      within: find.byType(SettingsCategoryPage),
    );
    expect(target, findsOneWidget);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byKey(WidgetKey.settingsCategoryBackButton.key));
    await tester.pumpAndSettle();
  }

  group('settings layout', () {
    testWidgets('every category reaches its rows under section headings',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSettings(tester);
      final l10n = tester.element(find.byType(SettingsPage)).l10n;

      await openCategory(tester, WidgetKey.settingsGeneralCategory);
      await expectHeading(tester, l10n.settingsSectionAppearance);
      await expectHeading(tester, l10n.settingsSectionAbout);
      await back(tester);

      await openCategory(tester, WidgetKey.settingsNetworkCategory);
      await expectHeading(tester, l10n.settingsSectionDeviceRange);
      await expectHeading(tester, l10n.settingsSectionScanBehavior);
      await expectHeading(tester, l10n.settingsSectionDiscovery);
      await expectHeading(tester, l10n.settingsSectionDeviceTrust);
      await expectHeading(tester, l10n.trustedDevicesTitle);
      // The reset covers every category, so it lives on the index, not here.
      expect(find.byKey(WidgetKey.resetAllSettingsButton.key), findsNothing);
      await back(tester);

      await openCategory(tester, WidgetKey.settingsOnlineFeaturesCategory);
      await expectHeading(tester, l10n.settingsSectionInternetAccess);
      await back(tester);

      await openCategory(tester, WidgetKey.settingsAdvancedCategory);
      await expectHeading(tester, l10n.settingsSectionPing);
      await expectHeading(tester, l10n.settingsSectionNetworkTarget);
      await back(tester);

      expect(find.byKey(WidgetKey.resetAllSettingsButton.key), findsOneWidget);
    });

    testWidgets('a phone-width category is its own page and pops back',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSettings(tester);
      final indexRoute = ModalRoute.of(
        tester.element(find.byType(SettingsPage)),
      );

      await openCategory(tester, WidgetKey.settingsNetworkCategory);
      final l10n = tester.element(find.byType(SettingsCategoryPage)).l10n;

      // Drawn inline under the shell's AppBar, the category header repeated the
      // shell's title; as a route of its own there is exactly one.
      expect(
        ModalRoute.of(tester.element(find.byType(SettingsCategoryPage))),
        isNot(same(indexRoute)),
      );
      expect(find.text(l10n.settingsNetwork), findsOneWidget);
      expect(
        find.byKey(WidgetKey.settingsCategoryBackButton.key),
        findsOneWidget,
      );
      expect(find.byKey(WidgetKey.resetAllSettingsButton.key), findsNothing);

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsCategoryBackButton,
        tester,
        find,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsCategoryPage), findsNothing);
      expect(find.byKey(WidgetKey.settingsNetworkCategory.key), findsOneWidget);
      expect(find.byKey(WidgetKey.resetAllSettingsButton.key), findsOneWidget);
    });
  });
}
