import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStage { language, walkthrough, consent }

class OnboardingService {
  OnboardingService._();
  static final instance = OnboardingService._();

  static const String _languageKey = 'onboarding_language_done';
  static const String _walkthroughKey = 'onboarding_walkthrough_done';
  static const String _consentKey = 'ContinueWithoutPermission';
  static const String _seenWhatsNewVersionsKey =
      'onboarding_seen_whats_new_versions';

  Future<bool> isLanguageDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_languageKey) ?? false;
  }

  Future<void> setLanguageDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageKey, true);
  }

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

  Future<List<String>> getSeenWhatsNewVersions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_seenWhatsNewVersionsKey) ?? [];
  }

  Future<void> markWhatsNewSeen(String version) async {
    final versions = await getSeenWhatsNewVersions();
    if (!versions.contains(version)) {
      versions.add(version);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenWhatsNewVersionsKey, versions);
    }
  }

  Future<bool> hasSeenWhatsNew(String version) async {
    final versions = await getSeenWhatsNewVersions();
    return versions.contains(version);
  }

  Future<OnboardingStage?> resolveStage() async {
    if (!await isLanguageDone()) return OnboardingStage.language;
    if (!await isWalkthroughDone()) return OnboardingStage.walkthrough;
    if (!await isConsentDone()) return OnboardingStage.consent;
    return null;
  }
}
