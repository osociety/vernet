import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => switch (call.method) {
        'wifiIPAddress' => '192.168.1.10',
        'wifiBSSID' => '00:11:22:33:44:55',
        'wifiName' => 'Mock WiFi',
        'wifiGatewayAddress' => '192.168.1.1',
        _ => null,
      },
    );
  });

  Future<void> pumpHomePage(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    // The dashboard has live network futures and a refresh indicator; advance
    // frames without waiting for every ongoing indicator to settle.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('HomePage dashboard', () {
    testWidgets('shows the network overview and connection details',
        (tester) async {
      await pumpHomePage(tester, size: const Size(900, 800));

      expect(find.text('NETWORK OVERVIEW'), findsOneWidget);
      expect(find.text('Your network'), findsOneWidget);
      expect(find.text('CONNECTION PATH'), findsOneWidget);
      expect(find.text('THIS DEVICE'), findsOneWidget);
      expect(find.text('WI-FI ROUTER'), findsOneWidget);
      expect(find.text('INTERNET PROVIDER'), findsOneWidget);
      expect(find.text('WI-FI CONNECTION'), findsOneWidget);
      expect(find.text('INTERNET SERVICE'), findsOneWidget);
    });

    testWidgets('keeps the tool shortcuts in the sidebar, not the dashboard',
        (tester) async {
      await pumpHomePage(tester, size: const Size(900, 800));

      expect(find.text('Check your connection'), findsNothing);
      expect(find.text('Website and address tools'), findsNothing);
      expect(find.byKey(const ValueKey('ping')), findsNothing);
      expect(find.text('Internet lookups are off'), findsOneWidget);
    });

    testWidgets('centers the mobile header', (tester) async {
      await pumpHomePage(tester, size: const Size(390, 844));

      final overview = tester.widget<Text>(find.text('NETWORK OVERVIEW'));
      final title = tester.widget<Text>(find.text('Your network'));
      expect(overview.textAlign, TextAlign.center);
      expect(title.textAlign, TextAlign.center);
    });

    testWidgets('matches Wi-Fi and internet panel heights on desktop',
        (tester) async {
      await pumpHomePage(tester, size: const Size(1100, 800));

      final wifiPanel = find
          .ancestor(
            of: find.text('WI-FI CONNECTION'),
            matching: find.byType(Container),
          )
          .first;
      final ispPanel = find
          .ancestor(
            of: find.text('INTERNET SERVICE'),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(wifiPanel).height, tester.getSize(ispPanel).height);
    });
  });
}
