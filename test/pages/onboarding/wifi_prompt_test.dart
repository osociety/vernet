import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/pages/onboarding/wifi_prompt_page.dart';
import 'package:vernet/values/keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => WifiPromptSheet.show(context),
              child: const Text('Show Prompt'),
            ),
          ),
        ),
      ),
    );
  }

  group('WifiPromptSheet', () {
    testWidgets('shows wifi off icon and title', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Not connected to Wi-Fi'), findsOneWidget);
    });

    testWidgets('shows description text', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Network scanning works best on Wi-Fi'),
        findsOneWidget,
      );
    });

    testWidgets('shows open settings button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(WidgetKey.wifiPromptOpenSettingsButton.key),
        findsOneWidget,
      );
      expect(find.text('Open Wi-Fi Settings'), findsOneWidget);
    });

    testWidgets('shows continue anyway button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(WidgetKey.wifiPromptContinueButton.key),
        findsOneWidget,
      );
      expect(find.text('Continue anyway'), findsOneWidget);
    });

    testWidgets('continue anyway dismisses and sets flag', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue anyway'));
      await tester.pumpAndSettle();

      expect(find.text('Not connected to Wi-Fi'), findsNothing);

      final dismissed =
          await OnboardingService.instance.isWifiPromptDismissed();
      expect(dismissed, isTrue);
    });
  });
}
