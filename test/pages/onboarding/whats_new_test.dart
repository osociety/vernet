import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  // Beta builds opened this dialog with no notes at all because the running
  // version had no entry in lib/values/changelog_data.dart.
  group('WhatsNewDialog.showIfNewVersion', () {
    Future<void> pumpHost(WidgetTester tester, String version) async {
      // PackageInfo.fromPlatform caches, so a method-channel mock would leak
      // the first version seen across tests in this file.
      PackageInfo.setMockInitialValues(
        appName: 'Vernet',
        packageName: 'org.fsociety.vernet',
        version: version,
        buildNumber: '1',
        buildSignature: '',
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: Text('Host')))),
      );
    }

    testWidgets('lists the changes for the running version', (tester) async {
      await pumpHost(tester, '1.5.0');

      // showIfNewVersion awaits dismissal, so it is deliberately not awaited.
      WhatsNewDialog.showIfNewVersion(tester.element(find.text('Host')));
      await tester.pumpAndSettle();

      final entry = changelogEntryForVersion('1.5.0')!;
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('v${entry.version}'), findsOneWidget);
      for (final change in entry.changes) {
        expect(find.text(change), findsOneWidget);
      }
    });

    testWidgets('stays hidden when the version has no notes', (tester) async {
      await pumpHost(tester, '0.0.1');

      WhatsNewDialog.showIfNewVersion(tester.element(find.text('Host')));
      // Bounded pumping drains the awaited package-info and shared-preferences
      // lookups without hanging if the guard ever regresses to opening a dialog.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text("What's New"), findsNothing);
      expect(find.text('No release notes available for this version.'),
          findsNothing);
    });
  });
}
