import 'package:flutter/widgets.dart';
import 'package:vernet/helper/locale_preference.dart';

class LocaleProvider with ChangeNotifier {
  LocalePreference localePreference = LocalePreference();
  Locale? _locale;

  /// The override every provider instance shares, readable without a
  /// [BuildContext] by `appStrings()`. Null means follow the system language.
  static Locale? active;

  /// Null means follow the system language.
  Locale? get locale => _locale;

  set locale(Locale? value) {
    _locale = value;
    active = value;
    localePreference.setLocale(value);
    notifyListeners();
  }
}
