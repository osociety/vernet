import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStage { walkthrough, consent }

class OnboardingService {
  OnboardingService._();
  static final instance = OnboardingService._();

  static const String _walkthroughKey = 'onboarding_walkthrough_done';
  static const String _consentKey = 'ContinueWithoutPermission';
  static const String _wifiPromptKey = 'onboarding_wifi_prompt_dismissed';
  static const String _lastSeenVersionKey = 'onboarding_last_seen_version';

  Future<bool> isWalkthroughDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_walkthroughKey) ?? false;
  }

  Future<void> setWalkthroughDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughKey, true);
  }

  Future<bool> isConsentDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  Future<void> setConsentDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
  }

  Future<bool> isWifiPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiPromptKey) ?? false;
  }

  Future<void> setWifiPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiPromptKey, true);
  }

  Future<String?> getLastSeenVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSeenVersionKey);
  }

  Future<void> setLastSeenVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenVersionKey, version);
  }

  Future<bool> hasNewVersion(String currentVersion) async {
    final lastSeen = await getLastSeenVersion();
    if (lastSeen == null) return false;
    return lastSeen != currentVersion;
  }

  Future<OnboardingStage?> resolveStage() async {
    if (!await isWalkthroughDone()) return OnboardingStage.walkthrough;
    if (!await isConsentDone()) return OnboardingStage.consent;
    return null;
  }
}
