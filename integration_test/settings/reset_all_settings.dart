import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/dark_theme_preference.dart';
import 'package:vernet/helper/locale_preference.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/settings_category_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

/// Drives the reset row on the settings index against the real app: cancelling
/// the confirmation has to leave every value alone, and confirming has to put
/// the defaults back in storage, in the theme and language providers that
/// render them, and in the page the user is looking at.
///
/// The widget suite covers the same reset; this is the end-to-end check that a
/// reset reaches SharedPreferences and both providers rather than only the
/// widget tree.
void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();

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

  Future<void> setDarkTheme(WidgetTester tester) async {
    final tile = find.byKey(WidgetKey.changeThemeTile.key);
    await TestUtils.revealWithin(
      tester,
      tile,
      within: find.byType(SettingsCategoryPage),
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKey.darkThemeRadioButton.key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }

  Future<void> setGerman(WidgetTester tester) async {
    final dropdown = find.byType(DropdownButton<Locale?>);
    await TestUtils.revealWithin(
      tester,
      dropdown,
      within: find.byType(SettingsCategoryPage),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The closed button keeps its items mounted, so the menu copy is last.
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapReset(WidgetTester tester) async {
    final resetRow = find.byKey(WidgetKey.resetAllSettingsButton.key);
    await TestUtils.revealWithin(
      tester,
      resetRow,
      within: find.byType(SettingsPage),
    );
    await tester.tap(resetRow);
    await tester.pumpAndSettle();
  }

  group('reset all settings', () {
    testWidgets(
        'cancel keeps every value, confirm restores storage, theme and '
        'language', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AppSettings.instance.setFirstSubnet(20);
      await AppSettings.instance.setSocketTimeout(250);
      await AppSettings.instance.setScanTimeout(10);
      await AppSettings.instance.setCustomSubnet('10.0.0.1');
      await AppSettings.instance.setMdnsEnabled(false);
      await AppSettings.instance.setAutoTrustNewDevices(true);

      await openSettings(tester);
      await openCategory(tester, WidgetKey.settingsGeneralCategory);
      await setDarkTheme(tester);
      await setGerman(tester);

      // The app itself has to be in German now, not just the provider field.
      final de = tester.element(find.byType(SettingsCategoryPage)).l10n;
      expect(find.text(de.settingsGeneral), findsOneWidget);
      await tester.tap(
        find.byKey(WidgetKey.settingsCategoryBackButton.key),
      );
      await tester.pumpAndSettle();

      await tapReset(tester);
      expect(find.text(de.resetAllSettingsConfirmTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, de.commonCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(AppSettings.instance.firstSubnet, 20);
      expect(AppSettings.instance.socketTimeout, 250);
      expect(AppSettings.instance.customSubnet, '10.0.0.1');
      expect(await DarkThemePreference().getTheme(), ThemePreference.dark);
      expect(await LocalePreference().getLocale(), const Locale('de'));

      await tapReset(tester);
      await tester.tap(find.widgetWithText(TextButton, de.resetAllSettings));
      await tester.pumpAndSettle();

      expect(AppSettings.instance.firstSubnet, 1);
      expect(AppSettings.instance.lastSubnet, 254);
      expect(AppSettings.instance.socketTimeout, 500);
      expect(AppSettings.instance.scanTimeout, 2);
      expect(AppSettings.instance.customSubnet, isEmpty);
      expect(AppSettings.instance.mdnsEnabled, isTrue);
      expect(AppSettings.instance.autoTrustNewDevices, isFalse);
      expect(AppSettings.instance.notifyUntrustedDevices, isTrue);
      expect(await DarkThemePreference().getTheme(), ThemePreference.system);
      expect(await LocalePreference().getLocale(), isNull);

      // Every surface that renders the reset values has to be back in English,
      // with the system theme and the language row on the system default.
      expect(find.text(en.resetAllSettings), findsOneWidget);
      await openCategory(tester, WidgetKey.settingsGeneralCategory);
      expect(
        find.descendant(
          of: find.byKey(WidgetKey.changeThemeTile.key),
          matching: find.text(en.themeSystem),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButton<Locale?>>(
              find.byType(DropdownButton<Locale?>),
            )
            .value,
        isNull,
      );
    });
  });
}
