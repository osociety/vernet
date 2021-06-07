import 'package:shared_preferences/shared_preferences.dart';

class Consent {
  static const String CONSENT_KEY = 'ContinueWithoutPermission';

  static Future<bool> isConsentPageShown() async {
    return (await SharedPreferences.getInstance()).getBool(CONSENT_KEY) ??
        false;
  }

  static Future<bool> setConsentPageShown(bool status) async {
    return (await SharedPreferences.getInstance()).setBool(CONSENT_KEY, status);
  }
}
