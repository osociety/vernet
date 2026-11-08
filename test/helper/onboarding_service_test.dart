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

    test('seen whats new versions defaults to empty list', () async {
      final versions =
          await OnboardingService.instance.getSeenWhatsNewVersions();
      expect(versions, isEmpty);
    });

    test('whats new version can be marked as seen', () async {
      await OnboardingService.instance.markWhatsNewSeen('1.4.20');
      final hasSeen =
          await OnboardingService.instance.hasSeenWhatsNew('1.4.20');
      expect(hasSeen, isTrue);
    });

    test('hasSeenWhatsNew returns false for unseen version', () async {
      final hasSeen =
          await OnboardingService.instance.hasSeenWhatsNew('1.4.20');
      expect(hasSeen, isFalse);
    });

    test('multiple versions can be tracked', () async {
      await OnboardingService.instance.markWhatsNewSeen('1.4.19');
      await OnboardingService.instance.markWhatsNewSeen('1.4.20');
      final versions =
          await OnboardingService.instance.getSeenWhatsNewVersions();
      expect(versions, containsAll(['1.4.19', '1.4.20']));
    });

    test('marking same version twice does not duplicate', () async {
      await OnboardingService.instance.markWhatsNewSeen('1.4.20');
      await OnboardingService.instance.markWhatsNewSeen('1.4.20');
      final versions =
          await OnboardingService.instance.getSeenWhatsNewVersions();
      expect(versions.where((v) => v == '1.4.20').length, 1);
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
