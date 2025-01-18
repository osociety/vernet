import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';

void main() {
  group('Ping integration test', () {
    testWidgets('tap on the ping button, verify ping ended', (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));

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

      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);

      expect(find.text('Sent: 5'), findsOneWidget);
      expect(find.text('Received : 5'), findsOneWidget);
      expect(find.byType(AdaptiveListTile), findsAtLeastNWidgets(5));
    });
  });
}
