import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DarkThemeProvider', () {
    late DarkThemeProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = DarkThemeProvider();
    });

    test('default themePref is system', () {
      expect(provider.themePref, ThemePreference.system);
    });

    test('setting themePref to dark notifies listeners and darkTheme is true',
        () {
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.themePref = ThemePreference.dark;

      expect(provider.themePref, ThemePreference.dark);
      expect(provider.darkTheme, isTrue);
      expect(notifyCount, 1);
    });

    test('setting themePref to light leads to darkTheme false', () {
      provider.themePref = ThemePreference.light;

      // Regardless of system brightness, explicit light should be false.
      expect(provider.darkTheme, isFalse);
    });

    test('system theme uses platform brightness', () {
      // Force system mode
      provider.themePref = ThemePreference.system;

      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;

      expect(provider.darkTheme, brightness == Brightness.dark);
    });
  });
}
