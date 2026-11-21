import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/donate_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/pages/updates_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
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

    test('SettingsPage is StatefulWidget', () {
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

      expect(tester.takeException(), isNull);
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

    Future<void> openAboutDialog(WidgetTester tester) async {
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
  });
}
