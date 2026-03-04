import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/custom_tile.dart';

void main() {
  group('CustomTile', () {
    testWidgets('renders with leading and child widgets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTile(
              leading: Icon(Icons.info),
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.info), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('arranges leading and child horizontally',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTile(
              leading: SizedBox(
                  width: 50, height: 50, child: Container(color: Colors.red)),
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Expanded), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('has correct spacing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTile(
              leading: SizedBox(width: 24, height: 24),
              child: Text('Content'),
            ),
          ),
        ),
      );

      final Column columnWidget =
          find.byType(Column).evaluate().first.widget as Column;
      expect(columnWidget.children.length, 2);
    });
  });
}
