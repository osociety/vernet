import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';
import 'package:vernet/values/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReverseDNSPage', () {
    test('ReverseDNSPage widget can be instantiated', () {
      const page = ReverseDNSPage();
      expect(page, isA<ReverseDNSPage>());
    });

    test('ReverseDNSPage is StatefulWidget', () {
      const page = ReverseDNSPage();
      expect(page, isA<StatefulWidget>());
    });

    testWidgets('shows empty placeholder before any lookup', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReverseDNSPage(),
          ),
        ),
      );

      expect(
        find.text(StringValue.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );
    });
  });
}
