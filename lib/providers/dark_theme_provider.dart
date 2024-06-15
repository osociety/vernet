import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vernet/helper/dark_theme_preference.dart';

class DarkThemeProvider with ChangeNotifier {
  DarkThemePreference darkThemePreference = DarkThemePreference();
  ThemePreference _darkTheme = ThemePreference.system;

  ThemePreference get themePref => _darkTheme;

  set themePref(ThemePreference value) {
    _darkTheme = value;
    darkThemePreference.setDarkTheme(value);
    notifyListeners();
  }

  bool get darkTheme {
    if (themePref == ThemePreference.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return ThemePreference.dark == themePref;
  }
}

enum ThemePreference { system, dark, light }
