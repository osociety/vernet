import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/pages/onboarding/whats_new_page.dart';
import 'package:vernet/values/changelog_data.dart';
import 'package:vernet/values/keys.dart';

import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({ChangelogEntry? entry}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
        entry: currentChangelog(l10nEn()),
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsOneWidget);
      expect(find.byKey(WidgetKey.whatsNewGotItButton.key), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('shows version badge', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: currentChangelog(l10nEn()),
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(
          find.text('v${currentChangelog(l10nEn()).version}'), findsOneWidget);
    });

    testWidgets('shows changelog items', (tester) async {
      final entry = currentChangelog(l10nEn());
      await tester.pumpWidget(createWidgetUnderTest(entry: entry));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      for (final change in entry.changes) {
        expect(find.text(change), findsOneWidget);
      }
    });

    testWidgets('got it button dismisses dialog', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: currentChangelog(l10nEn()),
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
    Future<void> pumpHost(
      WidgetTester tester,
      String version, {
      Locale locale = const Locale('en'),
    }) async {
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
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: Text('Host'))),
        ),
      );
    }

    testWidgets('lists the changes for the running version', (tester) async {
      await pumpHost(tester, changelogVersion);

      // showIfNewVersion awaits dismissal, so it is deliberately not awaited.
      WhatsNewDialog.showIfNewVersion(tester.element(find.text('Host')));
      await tester.pumpAndSettle();

      final entry = currentChangelog(l10nEn());
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('v${entry.version}'), findsOneWidget);
      for (final change in entry.changes) {
        expect(find.text(change), findsOneWidget);
      }
    });

    testWidgets('lists the notes in the language the app runs in',
        (tester) async {
      await pumpHost(tester, changelogVersion, locale: const Locale('de'));

      WhatsNewDialog.showIfNewVersion(tester.element(find.text('Host')));
      await tester.pumpAndSettle();

      final notes = currentChangelog(l10nDe());
      expect(find.text('Was ist neu'), findsOneWidget);
      for (final change in notes.changes) {
        expect(find.text(change), findsOneWidget);
      }
      // The English wording only lives in the English bundle, so its absence
      // says the notes were built for German, not silently fallen back.
      expect(find.text(currentChangelog(l10nEn()).changes.first), findsNothing);
    });

    // Only the running build gets a dialog; the notes of every earlier release
    // live on the GitHub releases page instead of in the app.
    testWidgets('stays hidden for a release that has been superseded',
        (tester) async {
      await pumpHost(tester, '1.6.3');

      WhatsNewDialog.showIfNewVersion(tester.element(find.text('Host')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text("What's New"), findsNothing);
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
