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
    // `flutter test` runs on the host that built it, so the store row is
    // whatever this machine's platform resolves to — never Google Play unless
    // the test host is Android.
    final universal = [
      WidgetKey.donateLiberapayTile.key,
      WidgetKey.donateKofiTile.key,
      WidgetKey.donateRepositoryTile.key,
    ];

    testWidgets('lists every support channel', (tester) async {
      await tester.pumpWidget(_wrap(const DonatePage()));

      for (final key in universal) {
        expect(find.byKey(key), findsOneWidget, reason: '$key missing');
      }
      expect(find.text('Support Vernet'), findsOneWidget);
    });

    testWidgets('offers no Play rating row off Android', (tester) async {
      await tester.pumpWidget(_wrap(const DonatePage()));

      expect(find.byKey(WidgetKey.donatePlayStoreTile.key), findsNothing);
      expect(find.text('Rate Vernet on Google Play'), findsNothing);
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
      expect(DonatePage.microsoftStoreUrl, contains('9N1170N3PHMM'));
    });

    test('only the platform with ratings gets the rating row', () {
      expect(
        DonatePage.ratingStoreFor(os: 'android', isStoreBuild: true),
        RatingStore.play,
      );
      // An F-Droid or dev install is not on Play and asking for a Play rating
      // there is wrong twice over.
      expect(
        DonatePage.ratingStoreFor(os: 'android', isStoreBuild: false),
        RatingStore.none,
      );
      expect(
        DonatePage.ratingStoreFor(os: 'windows', isStoreBuild: false),
        RatingStore.microsoft,
      );
      // The Snap Store takes no reviews, and there is no Mac App Store build.
      expect(
        DonatePage.ratingStoreFor(os: 'linux', isStoreBuild: false),
        RatingStore.none,
      );
      expect(
        DonatePage.ratingStoreFor(os: 'macos', isStoreBuild: false),
        RatingStore.none,
      );
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
        find.byKey(WidgetKey.donateRepositoryTile.key),
        find.byType(ListView),
        const Offset(0, 100),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(WidgetKey.donateRepositoryTile.key), findsOneWidget);
    });
  });
}
