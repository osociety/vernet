import 'package:flutter/widgets.dart';
import 'package:vernet/helper/locale_preference.dart';

class LocaleProvider with ChangeNotifier {
  LocalePreference localePreference = LocalePreference();
  Locale? _locale;

  /// Null means follow the system language.
  Locale? get locale => _locale;

  set locale(Locale? value) {
    _locale = value;
    localePreference.setLocale(value);
    notifyListeners();
  }
}
