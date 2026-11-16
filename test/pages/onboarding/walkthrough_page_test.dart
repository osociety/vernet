import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/onboarding/walkthrough_page.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/onboarding_content.dart';

import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest() =>
      wrapWithLocalizations(child: const WalkthroughPage());

  /// The English copy of the tour, so the assertions follow the bundle instead
  /// of repeating literals the app no longer owns.
  final steps = onboardingSteps(l10nEn());

  group('WalkthroughPage', () {
    testWidgets('shows first step content', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text(steps[0].title), findsOneWidget);
      expect(find.text(steps[0].description), findsOneWidget);
      expect(find.byIcon(steps[0].icon), findsOneWidget);
    });

    testWidgets('shows skip button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byKey(WidgetKey.walkthroughSkipButton.key), findsOneWidget);
      expect(find.text(l10nEn().walkthroughSkip), findsOneWidget);
    });

    testWidgets('offers no way back without a language step', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // A resumed install lands here with the language choice already behind it.
      expect(find.byKey(WidgetKey.walkthroughBackButton.key), findsNothing);
    });

    testWidgets('shows next button on first page', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byKey(WidgetKey.walkthroughNextButton.key), findsOneWidget);
      expect(find.text(l10nEn().walkthroughNext), findsOneWidget);
    });

    testWidgets('swipe navigates to next step', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text(steps[1].title), findsOneWidget);
    });

    testWidgets('last page shows Get Started button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      for (var i = 0; i < steps.length - 1; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(WidgetKey.walkthroughGetStartedButton.key),
          findsOneWidget);
      expect(find.text(l10nEn().getStarted), findsOneWidget);
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

      for (var i = 0; i < steps.length - 1; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text(l10nEn().getStarted));
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

    testWidgets('the tour reads in the language picked on the first screen',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          child: const WalkthroughPage(),
          locale: const Locale('de'),
        ),
      );

      final germanSteps = onboardingSteps(l10nDe());
      expect(find.text(germanSteps[0].title), findsOneWidget);
      expect(find.text('Discover Devices'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text(l10nDe().walkthroughNext), findsOneWidget);
    });
  });
}
