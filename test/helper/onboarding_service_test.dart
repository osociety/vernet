import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingService', () {
    test('walkthrough defaults to not done', () async {
      final done = await OnboardingService.instance.isWalkthroughDone();
      expect(done, isFalse);
    });

    test('walkthrough can be marked done', () async {
      await OnboardingService.instance.setWalkthroughDone();
      final done = await OnboardingService.instance.isWalkthroughDone();
      expect(done, isTrue);
    });

    test('consent defaults to not done', () async {
      final done = await OnboardingService.instance.isConsentDone();
      expect(done, isFalse);
    });

    test('consent can be marked done', () async {
      await OnboardingService.instance.setConsentDone();
      final done = await OnboardingService.instance.isConsentDone();
      expect(done, isTrue);
    });

    test('wifi prompt defaults to not dismissed', () async {
      final dismissed =
          await OnboardingService.instance.isWifiPromptDismissed();
      expect(dismissed, isFalse);
    });

    test('wifi prompt can be dismissed', () async {
      await OnboardingService.instance.setWifiPromptDismissed();
      final dismissed =
          await OnboardingService.instance.isWifiPromptDismissed();
      expect(dismissed, isTrue);
    });

    test('last seen version defaults to null', () async {
      final version = await OnboardingService.instance.getLastSeenVersion();
      expect(version, isNull);
    });

    test('last seen version can be set and retrieved', () async {
      await OnboardingService.instance.setLastSeenVersion('1.4.20');
      final version = await OnboardingService.instance.getLastSeenVersion();
      expect(version, '1.4.20');
    });

    test('hasNewVersion returns false when no version stored', () async {
      final hasNew = await OnboardingService.instance.hasNewVersion('1.4.20');
      expect(hasNew, isFalse);
    });

    test('hasNewVersion returns false for same version', () async {
      await OnboardingService.instance.setLastSeenVersion('1.4.20');
      final hasNew = await OnboardingService.instance.hasNewVersion('1.4.20');
      expect(hasNew, isFalse);
    });

    test('hasNewVersion returns true for different version', () async {
      await OnboardingService.instance.setLastSeenVersion('1.4.19');
      final hasNew = await OnboardingService.instance.hasNewVersion('1.4.20');
      expect(hasNew, isTrue);
    });

    test('resolveStage returns walkthrough when not done', () async {
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, OnboardingStage.walkthrough);
    });

    test('resolveStage returns consent when walkthrough done', () async {
      await OnboardingService.instance.setWalkthroughDone();
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, OnboardingStage.consent);
    });

    test('resolveStage returns null when all done', () async {
      await OnboardingService.instance.setWalkthroughDone();
      await OnboardingService.instance.setConsentDone();
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, isNull);
    });
  });
}
