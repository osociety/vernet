import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the app language override. An absent key means follow the system,
/// which is the default the app has always had.
class LocalePreference {
  static const localeStatus = 'LOCALESTATUS';

  Future<void> setLocale(Locale? locale) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(localeStatus);
    } else {
      await prefs.setString(localeStatus, locale.toLanguageTag());
    }
  }

  Future<Locale?> getLocale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tag = prefs.getString(localeStatus);
    if (tag == null || tag.isEmpty) return null;
    return localeFromTag(tag);
  }
}

/// dart:ui has no Locale.fromLanguageTag, so the BCP 47 tag is split into the
/// language, script and region subtags toLanguageTag writes back out.
Locale localeFromTag(String tag) {
  final List<String> parts = tag.split('-');
  if (parts.length == 1) return Locale(parts[0]);
  if (parts.length == 2) return Locale(parts[0], parts[1]);
  return Locale.fromSubtags(
    languageCode: parts[0],
    scriptCode: parts[1],
    countryCode: parts[2],
  );
}
