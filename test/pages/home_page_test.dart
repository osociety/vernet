import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/values/keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage', () {
    test('HomePage widget can be instantiated', () {
      const page = HomePage();
      expect(page, isA<HomePage>());
    });

    test('HomePage is StatefulWidget', () {
      const page = HomePage();
      expect(page, isA<StatefulWidget>());
    });

    // testWidgets('renders cards and navigates via buttons', (tester) async {
    //   await tester.pumpWidget(
    //     const MaterialApp(
    //       home: Scaffold(
    //         body: HomePage(),
    //       ),
    //     ),
    //   );

    //   // Initial wifi info future shows loading text.
    //   expect(find.textContaining('Loading'), findsWidgets);

    //   // Network troubleshooting card is present.
    //   expect(find.text('Network Troubleshooting'), findsOneWidget);

    //   // DNS card is present.
    //   expect(find.text('Domain Name System (DNS)'), findsOneWidget);

    //   // Tap Ping button; just ensure it exists and is tappable.
    //   await tester.tap(find.byKey(WidgetKey.ping.key));
    // });
  });
}
