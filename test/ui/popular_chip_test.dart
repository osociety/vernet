import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/popular_chip.dart';

void main() {
  group('PopularChip', () {
    testWidgets('renders with label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopularChip(
              label: 'Test Chip',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Chip'), findsOneWidget);
      expect(find.byType(ActionChip), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopularChip(
              label: 'Test',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      expect(pressed, isTrue);
    });

    testWidgets('uses secondary color from theme', (WidgetTester tester) async {
      const Color secondaryColor = Colors.blue;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: secondaryColor)),
          home: Scaffold(
            body: PopularChip(
              label: 'Test',
              onPressed: () {},
            ),
          ),
        ),
      );

      final ActionChip chip =
          find.byType(ActionChip).evaluate().first.widget as ActionChip;
      expect(chip, isNotNull);
    });

    testWidgets('is wrapped in Container with margin',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopularChip(
              label: 'Test',
              onPressed: () {},
            ),
          ),
        ),
      );

      final Container container =
          find.byType(Container).evaluate().first.widget as Container;
      expect(container.margin, EdgeInsets.all(2.0));
    });
  });
}
