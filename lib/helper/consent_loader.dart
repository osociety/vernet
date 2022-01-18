import 'package:shared_preferences/shared_preferences.dart';

class ConsentLoader {
  static const String consentKey = 'ContinueWithoutPermission';

  static Future<bool> isConsentPageShown() async {
    return (await SharedPreferences.getInstance()).getBool(consentKey) ?? false;
  }

  static Future<bool> setConsentPageShown(bool status) async {
    return (await SharedPreferences.getInstance()).setBool(consentKey, status);
  }
}
