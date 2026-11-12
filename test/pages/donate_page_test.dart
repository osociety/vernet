import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/pages/donate_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/keys.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DonatePage', () {
    final tiles = [
      WidgetKey.donateLiberapayTile.key,
      WidgetKey.donateKofiTile.key,
      WidgetKey.donateRepositoryTile.key,
      WidgetKey.donatePlayStoreTile.key,
    ];

    testWidgets('lists every support channel', (tester) async {
      await tester.pumpWidget(_wrap(const DonatePage()));

      for (final key in tiles) {
        expect(find.byKey(key), findsOneWidget, reason: '$key missing');
      }
      expect(find.text('Support Vernet'), findsOneWidget);
    });

    testWidgets('a channel opens the external link warning with its url',
        (tester) async {
      await tester.pumpWidget(_wrap(const DonatePage()));

      await tester.tap(find.byKey(WidgetKey.donateKofiTile.key));
      await tester.pumpAndSettle();

      expect(find.text('Open this link?'), findsOneWidget);
      expect(find.text(DonatePage.koFiUrl), findsOneWidget);
    });

    test('channels match what the repository advertises', () {
      expect(
          DonatePage.liberapayUrl, 'https://liberapay.com/OpenSociety/donate');
      expect(DonatePage.koFiUrl, 'https://ko-fi.com/fs0c13ty');
      expect(DonatePage.repositoryUrl, 'https://github.com/osociety/vernet');
      expect(DonatePage.playStoreUrl, contains('org.fsociety.vernet.store'));
    });

    test('the Android wording makes no ad-free claim', () {
      expect(DonatePage.introFor(hasAds: true), isNot(contains('no ads')));
      expect(DonatePage.introFor(hasAds: true), contains('no paid features'));
      expect(DonatePage.introFor(hasAds: false), contains('no ads'));
    });

    testWidgets('lays out at phone width without overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const DonatePage()));
      await tester.dragUntilVisible(
        find.byKey(WidgetKey.donatePlayStoreTile.key),
        find.byType(ListView),
        const Offset(0, 100),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(WidgetKey.donatePlayStoreTile.key), findsOneWidget);
    });
  });
}
