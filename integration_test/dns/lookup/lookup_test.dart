import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

void main() {
  group('Dns lookup integration test', () {
    testWidgets('tap on the DNS lookup button, verify lookup ended',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));

      // Finds the scan for devices button to tap on.
      final lookupButton = find.byKey(WidgetKey.dnsLookupButton.key);

      // Emulate a tap on the button.
      await tester.tap(lookupButton);
      await tester.pumpAndSettle();

      expect(find.text(StringValue.dnsLookupEmptyPlaceholder), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField),
        'google.com',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(AdaptiveListTile), findsExactly(7));
    });
  });
}
