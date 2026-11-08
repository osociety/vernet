import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/onboarding/walkthrough_page.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/onboarding_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: WalkthroughPage(),
    );
  }

  group('WalkthroughPage', () {
    testWidgets('shows first step content', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final firstStep = kOnboardingSteps[0];
      expect(find.text(firstStep.title), findsOneWidget);
      expect(find.text(firstStep.description), findsOneWidget);
      expect(find.byIcon(firstStep.icon), findsOneWidget);
    });

    testWidgets('shows skip button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byKey(WidgetKey.walkthroughSkipButton.key), findsOneWidget);
    });

    testWidgets('shows next button on first page', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byKey(WidgetKey.walkthroughNextButton.key), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('swipe navigates to next step', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final secondStep = kOnboardingSteps[1];
      expect(find.text(secondStep.title), findsOneWidget);
    });

    testWidgets('last page shows Get Started button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      for (var i = 0; i < kOnboardingSteps.length - 1; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(WidgetKey.walkthroughGetStartedButton.key),
          findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('skip button completes walkthrough and shows consent',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byKey(WidgetKey.walkthroughSkipButton.key));
      await tester.pumpAndSettle();

      expect(find.byType(LocationConsentPage), findsOneWidget);

      final done = await OnboardingService.instance.isWalkthroughDone();
      expect(done, isTrue);
    });

    testWidgets('get started button completes walkthrough', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      for (var i = 0; i < kOnboardingSteps.length - 1; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationConsentPage), findsOneWidget);

      final done = await OnboardingService.instance.isWalkthroughDone();
      expect(done, isTrue);
    });

    testWidgets('page indicator shows correct count', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(
          find.byKey(WidgetKey.walkthroughPageIndicator.key), findsOneWidget);
    });
  });
}
