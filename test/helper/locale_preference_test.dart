import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/locale_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalePreference', () {
    late LocalePreference preference;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preference = LocalePreference();
    });

    test('follows the system when nothing stored', () async {
      expect(await preference.getLocale(), isNull);
    });

    test('stores a picked language across launches', () async {
      await preference.setLocale(const Locale('de'));

      expect(await preference.getLocale(), const Locale('de'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalePreference.localeStatus), 'de');
    });

    test('back to the system default clears the stored tag', () async {
      await preference.setLocale(const Locale('de'));
      await preference.setLocale(null);

      expect(await preference.getLocale(), isNull);
    });

    test('a stale or empty tag means follow the system', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalePreference.localeStatus, '');

      expect(await preference.getLocale(), isNull);
    });
  });
}
