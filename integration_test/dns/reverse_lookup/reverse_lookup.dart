import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

void main() {
  globals.testingActive = true;
  group('Reverse DNS lookup integration test', () {
    testWidgets('tap on the reverse DNS lookup button, verify lookup ended',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));

      // Finds the scan for devices button to tap on.
      final reverseDnsLookupButton =
          find.byKey(WidgetKey.reverseDnsLookupButton.key);

      // Emulate a tap on the button.
      await tester.tap(reverseDnsLookupButton);
      await tester.pumpAndSettle();

      expect(
        find.text(StringValue.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '172.217.160.142',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final textWidget = find.text("maa03s29-in-f14.1e100.net");

      expect(textWidget, findsOneWidget);
      await tester.tap(textWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tap on the reverse DNS lookup button, verify error returned',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));

      // Finds the scan for devices button to tap on.
      final reverseDnsLookupButton =
          find.byKey(WidgetKey.reverseDnsLookupButton.key);

      // Emulate a tap on the button.
      await tester.tap(reverseDnsLookupButton);
      await tester.pumpAndSettle();

      expect(
        find.text(StringValue.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '172.217.160.',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'tap on the reverse DNS lookup button, verify reverse address not found returned',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));

      // Finds the scan for devices button to tap on.
      final reverseDnsLookupButton =
          find.byKey(WidgetKey.reverseDnsLookupButton.key);

      // Emulate a tap on the button.
      await tester.tap(reverseDnsLookupButton);
      await tester.pumpAndSettle();

      expect(
        find.text(StringValue.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '0.0.0.0',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
