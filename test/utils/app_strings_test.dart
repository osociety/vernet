import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/l10n/app_localizations_de.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/utils/app_strings.dart';

/// The no-[BuildContext] half of localization. Services, blocs and notification
/// bodies reach their strings through these helpers, and a wrong bundle here
/// reads as English in a German app with nothing else failing.
void main() {
  tearDown(() => LocaleProvider.active = null);

  group('stringsForLocale', () {
    test('picks the bundle by language code, ignoring the region', () {
      expect(stringsForLocale(const Locale('de')), isA<AppLocalizationsDe>());
      expect(stringsForLocale(const Locale('de', 'AT')),
          isA<AppLocalizationsDe>());
      expect(stringsForLocale(const Locale('en', 'AU')),
          isA<AppLocalizationsEn>());
    });

    test('falls back to English for a locale the app does not ship', () {
      expect(stringsForLocale(const Locale('fr')), isA<AppLocalizationsEn>());
      expect(
        stringsForLocale(const Locale('zh', 'CN')),
        isA<AppLocalizationsEn>(),
      );
    });
  });

  group('currentAppLocale', () {
    test('prefers the saved override', () {
      LocaleProvider.active = const Locale('de');

      expect(currentAppLocale(), const Locale('de'));
    });

    test('follows the system language when there is no override', () {
      LocaleProvider.active = null;

      expect(currentAppLocale(), systemDefaultLocale());
    });
  });

  group('resolveSystemLocale', () {
    test('matches by language code across the device preference list', () {
      expect(
          resolveSystemLocale(const [Locale('de', 'AT')]), const Locale('de'));
      expect(resolveSystemLocale(const [Locale('fr'), Locale('en', 'GB')]),
          const Locale('en'));
    });

    test('prefers the earlier device entry over a later match', () {
      expect(resolveSystemLocale(const [Locale('de'), Locale('en')]),
          const Locale('de'));
    });

    test('returns English when the device language is not shipped', () {
      // supportedLocales starts with German because gen-l10n orders it by ARB
      // filename, so Flutter's own fallback would answer a Russian device in
      // German. This is the rule lib/main.dart hands to the widget tree.
      expect(resolveSystemLocale(const [Locale('ru')]), const Locale('en'));
      expect(
          resolveSystemLocale(const [Locale('zh', 'CN')]), const Locale('en'));
      expect(resolveSystemLocale(const []), const Locale('en'));
    });
  });

  group('systemDefaultLocale', () {
    test('resolves to a locale the app ships', () {
      expect(
          AppLocalizations.supportedLocales, contains(systemDefaultLocale()));
    });
  });

  group('appStrings', () {
    test('returns the bundle of the locale in effect', () {
      LocaleProvider.active = const Locale('de');

      expect(appStrings().localeName, 'de');
    });

    test('tracks the system language when the user follows it', () {
      LocaleProvider.active = null;

      expect(appStrings().localeName, currentAppLocale().languageCode);
    });
  });
}
