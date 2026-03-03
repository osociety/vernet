import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/dark_theme_preference.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DarkThemePreference', () {
    late DarkThemePreference preference;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preference = DarkThemePreference();
    });

    test('returns system theme when nothing stored', () async {
      final theme = await preference.getTheme();
      expect(theme, ThemePreference.system);
    });

    test('persists and returns dark theme', () async {
      await preference.setDarkTheme(ThemePreference.dark);
      final theme = await preference.getTheme();
      expect(theme, ThemePreference.dark);
    });

    test('persists and returns light theme', () async {
      await preference.setDarkTheme(ThemePreference.light);
      final theme = await preference.getTheme();
      expect(theme, ThemePreference.light);
    });
  });
}

