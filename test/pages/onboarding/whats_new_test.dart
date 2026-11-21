import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/changelog_entry.dart';
import 'package:vernet/pages/onboarding/whats_new_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/changelog_data.dart';
import 'package:vernet/values/keys.dart';

import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({
    ChangelogEntry? entry,
    String? releaseUrl,
  }) {
    // The release link opens a `showAdaptiveDialog` route, and that dialog reads
    // `DarkThemeProvider` from the app root. Provider are not visible across
    // routes when they hang off `home`, so the real entry point's position above
    // `MaterialApp` is repeated here.
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => DarkThemeProvider())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAdaptiveDialog(
                  context: context,
                  builder: (_) =>
                      WhatsNewDialog(entry: entry, releaseUrl: releaseUrl),
                ),
                child: const Text('Show Dialog'),
              ),
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

    testWidgets('links the running build to its own GitHub release',
        (tester) async {
      const url = 'https://github.com/osociety/vernet/releases/tag/v1.7.0+84';
      await tester.pumpWidget(createWidgetUnderTest(
        entry: currentChangelog(l10nEn()),
        releaseUrl: url,
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.whatsNewReleaseLink.key));
      await tester.pumpAndSettle();

      // The external-link warning is what every other in-app link goes through,
      // and it prints the address it is about to open.
      expect(find.text(url), findsOneWidget);
    });

    testWidgets('leaves the release link out when there is no tag to name',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        entry: currentChangelog(l10nEn()),
      ));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKey.whatsNewReleaseLink.key), findsNothing);
      expect(find.text('This release on GitHub'), findsNothing);
    });

    // A fixed 6px top offset only ever met one language at one font size, so
    // the tick sat off the line for wrapped German notes.
    testWidgets('the tick meets the first line even when the note wraps',
        (tester) async {
      const wrapped = 'A release note long enough that the dialog has to wrap '
          'it across several lines instead of showing it once';
      const entry = ChangelogEntry(
        version: changelogVersion,
        changes: [wrapped],
      );
      await tester.pumpWidget(createWidgetUnderTest(entry: entry));
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      final note = find.text(entry.changes.single);
      final tick = find.byIcon(Icons.check_circle_outline);
      expect(tester.getSize(note).height, greaterThan(40),
          reason: 'the note must wrap, or this proves nothing about alignment');
      // A tick box that expanded across the row would leave the note no width to
      // wrap in, so the height check above would pass on a broken layout.
      expect(tester.getSize(note).width, greaterThan(150),
          reason: 'the note keeps the width the row gives it');

      // bodyMedium is 14px at height 1.43, so its first line centre sits about
      // 10px below the top of the text block.
      expect(
        tester.getCenter(tick).dy,
        closeTo(tester.getTopLeft(note).dy + 10, 1.5),
      );
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
