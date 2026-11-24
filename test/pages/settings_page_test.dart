import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/donate_page.dart';
import 'package:vernet/pages/onboarding/whats_new_page.dart';
import 'package:vernet/pages/settings_category_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/pages/updates_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage', () {
    test('SettingsPage widget can be instantiated', () {
      const page = SettingsPage();
      expect(page, isA<SettingsPage>());
    });

    test('SettingsPage is a StatefulWidget', () {
      const page = SettingsPage();
      expect(page, isA<StatefulWidget>());
    });

    Future<void> pumpAtWidth(
      WidgetTester tester,
      Size size, {
      Locale? locale,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The language row put an unsized DropdownButton in ListTile.trailing, whose
    // intrinsic width plus content padding filled a phone-width tile (#675).
    testWidgets('lays out the language row at phone width', (tester) async {
      const phone = Size(390, 844);
      await pumpAtWidth(tester, phone);
      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<Locale?>), findsOneWidget);
      expect(
        tester.getRect(find.byType(DropdownButton<Locale?>)).right,
        lessThanOrEqualTo(phone.width),
      );
    });

    testWidgets('lays out at phone width in German, where names are longer',
        (tester) async {
      await pumpAtWidth(tester, const Size(390, 844),
          locale: const Locale('de'));
      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('opens a category and edits a feature setting', (tester) async {
      await pumpAtWidth(tester, const Size(800, 900));

      expect(find.text(l10nEn().settingsGeneral), findsOneWidget);
      expect(find.text(l10nEn().settingsNetwork), findsOneWidget);
      expect(find.text(l10nEn().settingsFeatures), findsOneWidget);
      expect(find.text(l10nEn().settingsAdvanced), findsOneWidget);
      expect(find.text(l10nEn().settingsGeneralDesc), findsOneWidget);
      expect(find.text(l10nEn().settingsNetworkDesc), findsOneWidget);
      expect(find.text(l10nEn().settingsFeaturesDesc), findsOneWidget);
      expect(find.text(l10nEn().settingsAdvancedDesc), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      expect(find.byIcon(Icons.router_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      expect(find.byKey(WidgetKey.pingCountTile.key), findsNothing);
      expect(find.byKey(WidgetKey.customSubnetTile.key), findsNothing);

      final settingsRoute = ModalRoute.of(
        tester.element(find.byType(SettingsPage)),
      );
      await tester.tap(find.byKey(WidgetKey.settingsAdvancedCategory.key));
      await tester.pumpAndSettle();

      expect(find.text(l10nEn().settingsAdvanced), findsOneWidget);
      expect(find.byKey(WidgetKey.pingCountTile.key), findsOneWidget);
      expect(find.byKey(WidgetKey.customSubnetTile.key), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(SettingsCategoryPage))),
        same(settingsRoute),
      );

      await tester.tap(find.byKey(WidgetKey.pingCountTile.key));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(WidgetKey.settingsTextField.key),
        '7',
      );
      await tester.tap(find.byKey(WidgetKey.settingsSubmitButton.key));
      await tester.pumpAndSettle();

      expect(AppSettings.instance.pingCount, 7);
      expect(find.text('7'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(
        find.byKey(WidgetKey.settingsGeneralCategory.key),
        findsOneWidget,
      );
      expect(find.byType(SettingsCategoryPage), findsNothing);
    });

    testWidgets('network category edits scan behavior immediately',
        (tester) async {
      await pumpAtWidth(tester, const Size(800, 900));

      await tester.tap(find.byKey(WidgetKey.settingsNetworkCategory.key));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKey.scanTimeoutTile.key), findsOneWidget);
      expect(find.byKey(WidgetKey.scanConcurrencyTile.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingMethodTile.key), findsOneWidget);
      expect(find.byKey(WidgetKey.mdnsDiscoveryTile.key), findsOneWidget);

      final mdnsSwitch = tester.widget<SwitchListTile>(
        find.byKey(WidgetKey.mdnsDiscoveryTile.key),
      );
      mdnsSwitch.onChanged?.call(false);
      await tester.pumpAndSettle();
      expect(AppSettings.instance.mdnsEnabled, isFalse);

      await tester.tap(find.byKey(WidgetKey.resetScanDefaultsButton.key));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.scanTimeout, 2);
      expect(AppSettings.instance.scanConcurrency,
          AppSettings.recommendedScanConcurrency);
      expect(AppSettings.instance.pingMethod, ScanPingMethod.tcpFallback);
      expect(AppSettings.instance.mdnsEnabled, isTrue);
    });

    testWidgets('choosing a language re-renders the page in it',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();
      final localeProvider = LocaleProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: Consumer<LocaleProvider>(
            builder: (context, locale, child) => MaterialApp(
              locale: locale.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      final dropdown = find.byType(DropdownButton<Locale?>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(localeProvider.locale, const Locale('de'));
    });

    testWidgets('support tile opens the donation page', (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      final tile = find.byKey(WidgetKey.donateSettingsTile.key);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(DonatePage), findsOneWidget);
    });

    testWidgets('updates tile opens the channel page', (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      final tile = find.byKey(WidgetKey.updateSettingsTile.key);
      // The flavored test matrix runs this file per flavor, and the fdroid
      // build ships no update check at all.
      if (!kUpdateChecksEnabled) {
        expect(tile, findsNothing);
        return;
      }

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(UpdatesPage), findsOneWidget);
      // The check itself moved onto the page it opens.
      expect(
        find.byKey(WidgetKey.checkForUpdatesButton.key),
        findsOneWidget,
      );
    });

    testWidgets('theme setting applies the selected preference',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();
      final themeProvider = DarkThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DarkThemeProvider>.value(
              value: themeProvider,
            ),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKey.changeThemeTile.key));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.darkThemeRadioButton.key));
      await tester.pumpAndSettle();
      expect(themeProvider.themePref, ThemePreference.dark);

      await tester.tap(find.byKey(WidgetKey.lightThemeRadioButton.key));
      await tester.pumpAndSettle();
      expect(themeProvider.themePref, ThemePreference.light);

      await tester.tap(find.byKey(WidgetKey.systemThemeRadioButton.key));
      await tester.pumpAndSettle();
      expect(themeProvider.themePref, ThemePreference.system);

      Navigator.of(tester.element(find.byType(ThemeDialog))).pop();
      await tester.pumpAndSettle();
      expect(find.text(l10nEn().themeSystem), findsOneWidget);
    });

    testWidgets('What’s New tile opens the current release notes',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();
      setupPackageInfoMock();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      final tile = find.byKey(WidgetKey.whatsNewSettingsTile.key);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(WhatsNewDialog), findsOneWidget);
      expect(find.byKey(WidgetKey.whatsNewGotItButton.key), findsOneWidget);
    });

    Future<void> openAboutDialog(
      WidgetTester tester, {
      Size size = const Size(800, 600),
    }) async {
      SharedPreferences.setMockInitialValues({});
      AppSettings.instance.resetForTesting();
      setupPackageInfoMock();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.settingsGeneralCategory.key));
      await tester.pumpAndSettle();
      final aboutTile = find.text('About');
      await tester.ensureVisible(aboutTile);
      await tester.tap(aboutTile);
      await tester.pumpAndSettle();
    }

    // Both About tiles built their URL from a constant naming the
    // maintainer's personal fork, which does not resolve for a reporter
    // who has no access to it (#690).
    testWidgets('report issues tile opens the osociety issues page',
        (tester) async {
      await openAboutDialog(tester);

      await tester.tap(find.text('Report Issues'));
      await tester.pumpAndSettle();

      expect(
        find.text('https://github.com/osociety/vernet/issues'),
        findsOneWidget,
      );
      expect(find.textContaining('git-elliot'), findsNothing);
    });

    testWidgets('source code tile opens the osociety repository',
        (tester) async {
      await openAboutDialog(tester);

      await tester.tap(find.text('Source Code'));
      await tester.pumpAndSettle();

      expect(find.text('https://github.com/osociety/vernet'), findsOneWidget);
      expect(find.textContaining('git-elliot'), findsNothing);
    });

    testWidgets('About dialog donate tile opens the donation page',
        (tester) async {
      await openAboutDialog(tester);

      await tester.tap(find.widgetWithText(ListTile, l10nEn().donateTitle));
      await tester.pumpAndSettle();

      expect(find.byType(DonatePage), findsOneWidget);
    });

    // The placeholder glyph was a coloured Material icon that looked different
    // from the logo every other surface shows; the mark now comes from the
    // bundled splash asset and is tinted by the active theme. Checked at phone
    // width because the dialog gives the icon no room to spare.
    testWidgets('About dialog carries the theme-tinted Vernet mark',
        (tester) async {
      await openAboutDialog(tester, size: const Size(390, 844));

      expect(find.byIcon(Icons.radar), findsNothing);

      final mark = find.descendant(
        of: find.byType(AboutDialog),
        matching: find.byType(ColorFiltered),
      );
      expect(mark, findsOneWidget);
      expect(
        tester.widget<ColorFiltered>(mark).colorFilter,
        ColorFilter.mode(
          Theme.of(tester.element(mark)).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
      final image = tester.widget<Image>(
        find.descendant(of: mark, matching: find.byType(Image)),
      );
      // AppMark asks for a cacheWidth, so the asset arrives wrapped.
      expect(
        ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/splash11/splash_dark/ic_launcher_round.png',
      );
      expect(tester.getSize(mark), const Size(64, 64));
      expect(
        tester.getRect(find.byType(AboutDialog)).right,
        lessThanOrEqualTo(390),
        reason: 'the icon must not push the dialog past the viewport',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
