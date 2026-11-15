import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingService', () {
    test('language defaults to not done', () async {
      final done = await OnboardingService.instance.isLanguageDone();
      expect(done, isFalse);
    });

    test('language can be marked done', () async {
      await OnboardingService.instance.setLanguageDone();
      final done = await OnboardingService.instance.isLanguageDone();
      expect(done, isTrue);
    });

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

    test('resolveStage returns language on a fresh install', () async {
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, OnboardingStage.language);
    });

    test('resolveStage returns walkthrough once language is done', () async {
      await OnboardingService.instance.setLanguageDone();
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, OnboardingStage.walkthrough);
    });

    test('resolveStage returns consent when walkthrough done', () async {
      await OnboardingService.instance.setLanguageDone();
      await OnboardingService.instance.setWalkthroughDone();
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, OnboardingStage.consent);
    });

    test('an install predating the language step gets it once', () async {
      // The language flag shipped after the tour and consent, so an upgraded
      // install has never answered it. It is asked once and then the flow is
      // finished, which is all the upgrade costs.
      await OnboardingService.instance.setWalkthroughDone();
      await OnboardingService.instance.setConsentDone();
      expect(
        await OnboardingService.instance.resolveStage(),
        OnboardingStage.language,
      );

      await OnboardingService.instance.setLanguageDone();
      expect(await OnboardingService.instance.resolveStage(), isNull);
    });

    test('resolveStage returns null when all done', () async {
      await OnboardingService.instance.setLanguageDone();
      await OnboardingService.instance.setWalkthroughDone();
      await OnboardingService.instance.setConsentDone();
      final stage = await OnboardingService.instance.resolveStage();
      expect(stage, isNull);
    });
  });
}
