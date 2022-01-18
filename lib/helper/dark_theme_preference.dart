import 'package:shared_preferences/shared_preferences.dart';

class DarkThemePreference {
  static const themeStatus = 'THEMESTATUS';

  Future<void> setDarkTheme(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(themeStatus, value);
  }

  Future<bool> getTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(themeStatus) ?? false;
  }
}
