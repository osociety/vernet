import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/onboarding/language_page.dart';
import 'package:vernet/pages/onboarding/walkthrough_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocaleProvider localeProvider;

  setUpAll(() => configureDependencies(Env.test));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    localeProvider = LocaleProvider();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    LanguagePage page = const LanguagePage(),
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Waits out the locale change, the preference write and the route swap that
  /// [LanguagePage] runs behind the Continue button. Bounded pumps, not
  /// `pumpAndSettle`: the dashboard the last branch opens never settles.
  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.byKey(WidgetKey.languageContinueButton.key));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('LanguagePage', () {
    testWidgets('offers every supported language by its endonym',
        (tester) async {
      await pumpPage(tester);

      for (final locale in AppLocalizations.supportedLocales) {
        expect(find.text(languageName(locale)), findsOneWidget);
      }
    });

    testWidgets('follows the system language until the user picks one',
        (tester) async {
      await pumpPage(tester);

      expect(
        tester
            .widget<RadioGroup<Locale?>>(
              find.descendant(
                of: find.byKey(WidgetKey.languageSystemOption.key),
                matching: find.byType(RadioGroup<Locale?>),
              ),
            )
            .groupValue,
        isNull,
      );
    });

    testWidgets('renders the prompt in the language it opens on',
        (tester) async {
      // Opening on German, the way the walkthrough hands the applied language
      // back, has to read the German bundle rather than fall back silently.
      await pumpPage(
        tester,
        locale: const Locale('de'),
        page: const LanguagePage(selected: Locale('de')),
      );

      expect(
          find.text('Welche Sprache soll Vernet verwenden?'), findsOneWidget);
      expect(find.text('Which language should Vernet use?'), findsNothing);
      expect(find.text(l10nEn().languageContinue), findsNothing);
      expect(find.text(l10nDe().languageContinue), findsOneWidget);
    });

    testWidgets('a pick stays unapplied until Continue', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(localeProvider.locale, isNull);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('previewing a pick translates the page before applying it',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(
          find.text('Welche Sprache soll Vernet verwenden?'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('Which language should Vernet use?'), findsNothing);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('Which language should Vernet use?'), findsOneWidget);
      // The preview must not leak into the persisted preference.
      expect(localeProvider.locale, isNull);
    });

    testWidgets(
        'System default follows the operating system, not the app language',
        (tester) async {
      // An English machine whose Vernet was put in German by hand, which is the
      // state returning to this step after a language has been applied.
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpPage(tester, locale: const Locale('de'));

      // System default means the system, so the page is in English from the
      // start and says out loud which language that is.
      expect(find.text('System default (English)'), findsOneWidget);
      expect(find.text('Which language should Vernet use?'), findsOneWidget);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(find.text('Systemstandard (English)'), findsOneWidget);

      await tester.tap(find.byKey(WidgetKey.languageSystemOption.key));
      await tester.pumpAndSettle();

      // The bug this guards: the row previewed the German the app was showing
      // instead of the English the operating system asks for.
      expect(find.text('Which language should Vernet use?'), findsOneWidget);
      expect(find.text('Welche Sprache soll Vernet verwenden?'), findsNothing);
      expect(localeProvider.locale, isNull);
    });

    testWidgets('the walkthrough goes back to the language step',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      await tapContinue(tester);
      expect(find.byType(WalkthroughPage), findsOneWidget);

      await tester.tap(find.byKey(WidgetKey.walkthroughBackButton.key));
      await tester.pumpAndSettle();

      expect(find.byType(LanguagePage), findsOneWidget);
      // Coming back shows the language already applied, not a reset pick: the
      // harness pins the app to English, so a German prompt can only come from
      // the selection the page was handed.
      expect(
          find.text('Welche Sprache soll Vernet verwenden?'), findsOneWidget);
      expect(find.text('Which language should Vernet use?'), findsNothing);
    });

    testWidgets('Continue persists the choice and moves to the walkthrough',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      await tapContinue(tester);

      expect(localeProvider.locale, const Locale('de'));
      expect(await OnboardingService.instance.isLanguageDone(), isTrue);
      expect(find.byType(WalkthroughPage), findsOneWidget);
    });

    testWidgets('the step is spent as soon as the user leaves it',
        (tester) async {
      await pumpPage(tester);
      await tapContinue(tester);

      // The flag is written before the route changes, so no later launch — and
      // no landing on the home page — can put the chooser back on screen.
      expect(
        await OnboardingService.instance.resolveStage(),
        isNot(OnboardingStage.language),
      );
    });

    testWidgets('skipping straight to the app when the tour is already done',
        (tester) async {
      await OnboardingService.instance.setWalkthroughDone();
      await pumpPage(tester);

      await tapContinue(tester);

      expect(find.byType(WalkthroughPage), findsNothing);
      expect(find.byType(TabBarPage), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
