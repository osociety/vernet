import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/pages/updates_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/store_links.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(home: child),
    );

/// The guidance the page renders on the machine running the test, which is
/// the same one `Platform.operatingSystem` gives it.
UpdateGuidance get _hostGuidance => UpdatesPage.guidanceFor(
      os: Platform.operatingSystem,
      isStoreBuild: kStoreBuild,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'Vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.6.2',
          'buildNumber': '81',
        };
      }
      return null;
    });
  });

  tearDown(() {
    AppSettings.instance.resetForTesting();
  });

  group('UpdatesPage', () {
    testWidgets('shows the installed version and a check action',
        (tester) async {
      await tester.pumpWidget(_wrap(const UpdatesPage()));
      await tester.pumpAndSettle();

      expect(find.text('Vernet 1.6.2+81'), findsOneWidget);
      expect(find.byKey(WidgetKey.checkForUpdatesButton.key), findsOneWidget);
      expect(find.text('How updates reach you'), findsOneWidget);
    });

    testWidgets('matches the channel card to a beta track that exists',
        (tester) async {
      await tester.pumpWidget(_wrap(const UpdatesPage()));
      await tester.pumpAndSettle();

      // `flutter test` runs on whatever host built it, so this cannot assume
      // one platform; it asserts the page and the seam agree.
      if (_hostGuidance.hasBeta) {
        expect(find.byKey(WidgetKey.updateStableTile.key), findsOneWidget);
        expect(find.byKey(WidgetKey.updateBetaTile.key), findsOneWidget);
      } else {
        expect(find.byKey(WidgetKey.updateBetaTile.key), findsNothing);
      }
    });

    testWidgets('starts on stable and remembers the switch to beta',
        (tester) async {
      await tester.pumpWidget(_wrap(const UpdatesPage()));
      await tester.pumpAndSettle();

      expect(AppSettings.instance.betaUpdates, isFalse);
      final stable = find.byKey(WidgetKey.updateStableTile.key);
      if (stable.evaluate().isEmpty) {
        // No beta track on this host; the seam tests cover the other case.
        return;
      }

      await tester.tap(find.byKey(WidgetKey.updateBetaTile.key));
      await tester.pumpAndSettle();

      expect(AppSettings.instance.betaUpdates, isTrue);
      expect(find.textContaining('Checking the beta'), findsOneWidget);

      await tester.tap(stable);
      await tester.pumpAndSettle();

      expect(AppSettings.instance.betaUpdates, isFalse);
    });

    testWidgets('keeps the saved channel across a restart', (tester) async {
      await AppSettings.instance.setBetaUpdates(true);
      // A restart starts from the defaults and then reads back what was saved.
      AppSettings.instance.resetForTesting();
      expect(AppSettings.instance.betaUpdates, isFalse);
      await AppSettings.instance.load();
      expect(AppSettings.instance.betaUpdates, isTrue);

      await tester.pumpWidget(_wrap(const UpdatesPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Checking the beta'), findsOneWidget);
    });

    testWidgets('lays out at phone width without overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const UpdatesPage()));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('How updates reach you'),
        find.byType(ListView),
        const Offset(0, 60),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('release channel guidance', () {
    test('snap users get the command they actually have to run', () {
      final guidance = UpdatesPage.guidanceFor(
        os: 'linux',
        isStoreBuild: false,
      );

      expect(guidance.hasBeta, isTrue);
      expect(guidance.copyCommand, 'sudo snap refresh vernet --channel=beta');
      expect(guidance.betaLinkUrl, snapStoreListingUrl);
    });

    test('the Play build is sent to the beta opt-in page', () {
      final guidance = UpdatesPage.guidanceFor(
        os: 'android',
        isStoreBuild: true,
      );

      expect(guidance.betaLinkUrl, playBetaOptInUrl);
      expect(playBetaOptInUrl, contains('apps/testing/org.fsociety.vernet'));
    });

    test('an F-Droid install is not pointed at Play', () {
      final guidance = UpdatesPage.guidanceFor(
        os: 'android',
        isStoreBuild: false,
      );

      expect(guidance.betaLinkUrl, isNot(contains('play.google.com')));
      expect(guidance.betaHowTo, contains('F-Droid'));
    });

    test('no platform is promised a beta channel it does not have', () {
      for (final os in ['windows', 'macos', 'ios']) {
        final guidance = UpdatesPage.guidanceFor(
          os: os,
          isStoreBuild: false,
        );
        expect(guidance.hasBeta, isFalse, reason: '$os has no beta track');
        expect(guidance.copyCommand, isNull, reason: '$os has no snapd');
      }
    });

    test('every platform says what updates it by itself', () {
      for (final os in ['android', 'linux', 'windows', 'macos']) {
        final guidance = UpdatesPage.guidanceFor(
          os: os,
          isStoreBuild: true,
        );
        expect(guidance.autoUpdate, isNotEmpty, reason: os);
        expect(guidance.betaHowTo, isNotEmpty, reason: os);
      }
    });
  });
}
