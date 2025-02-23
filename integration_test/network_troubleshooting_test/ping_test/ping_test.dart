import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final appSettings = AppSettings.instance;
  group('Ping integration test', () {
    testWidgets('tap on the ping button, verify ping ended', (tester) async {
      await appSettings.load();
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));

      // Finds the scan for devices button to tap on.
      final pingButton = find.byKey(WidgetKey.ping.key);

      // Emulate a tap on the button.
      await tester.tap(pingButton);
      await tester.pumpAndSettle();
      final interface = await NetInterface.localInterface();

      await tester.enterText(
        find.byType(TextFormField),
        interface?.ipAddress ?? '192.168.0.1',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);

      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);

      expect(find.text('Sent: ${appSettings.pingCount}'), findsOneWidget);
      expect(find.text('Received : ${appSettings.pingCount}'), findsOneWidget);
      expect(
        find.byType(AdaptiveListTile),
        findsAtLeastNWidgets(appSettings.pingCount),
      );
    });
  });
}
