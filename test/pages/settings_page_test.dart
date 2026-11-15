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

    // Further widget layout testing for SettingsPage is skipped to avoid
    // large-tree layout issues in tests; constructor/type checks are sufficient.

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
  });
}
