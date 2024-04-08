import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/dark_theme_provider.dart';

class DarkThemePreference {
  static const themeStatus = 'THEMESTATUS_NEW';

  Future<void> setDarkTheme(ThemePreference value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(themeStatus, value.name);
  }

  Future<ThemePreference> getTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ThemePreference.values.firstWhere(
      (element) => element.name == prefs.getString(themeStatus),
      orElse: () => ThemePreference.system,
    );
  }
}
