import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/pages/onboarding/whats_new_page.dart';
import 'package:vernet/values/changelog_data.dart';
import 'package:vernet/values/keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({ChangelogEntry? entry}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAdaptiveDialog(
                context: context,
                builder: (_) => WhatsNewDialog(entry: entry),
              ),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('WhatsNewDialog', () {
    testWidgets('shows title and got it button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: kChangelogEntries.first,
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsOneWidget);
      expect(find.byKey(WidgetKey.whatsNewGotItButton.key), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('shows version badge', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: kChangelogEntries.first,
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('v${kChangelogEntries.first.version}'), findsOneWidget);
    });

    testWidgets('shows changelog items', (tester) async {
      final entry = kChangelogEntries.first;
      await tester.pumpWidget(createWidgetUnderTest(entry: entry));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      for (final change in entry.changes) {
        expect(find.text(change), findsOneWidget);
      }
    });

    testWidgets('got it button dismisses dialog', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: kChangelogEntries.first,
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsNothing);
    });
  });
}
