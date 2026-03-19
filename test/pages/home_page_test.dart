import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/keys.dart';

class MockNetworkInfo extends Mock implements NetworkInfo {}

Widget createHomePageTestWidget(Widget child) {
  return ChangeNotifierProvider<DarkThemeProvider>(
    create: (_) => DarkThemeProvider(),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNetworkInfo mockNetworkInfo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockNetworkInfo = MockNetworkInfo();
  });

  group('HomePage', () {
    test('HomePage widget can be instantiated', () {
      const page = HomePage();
      expect(page, isA<HomePage>());
    });

    test('HomePage is StatefulWidget', () {
      const page = HomePage();
      expect(page, isA<StatefulWidget>());
    });

    testWidgets('renders loading state initially', (tester) async {
      when(() => mockNetworkInfo.getWifiIP()).thenAnswer((_) async => null);
      when(() => mockNetworkInfo.getWifiBSSID())
          .thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'TestWiFi');
      when(() => mockNetworkInfo.getWifiGatewayIP())
          .thenAnswer((_) async => '192.168.1.1');

      await tester.pumpWidget(createHomePageTestWidget(const HomePage()));

      // Initial loading state
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('renders Network Troubleshooting card with buttons',
        (tester) async {
      when(() => mockNetworkInfo.getWifiIP())
          .thenAnswer((_) async => '192.168.1.100');
      when(() => mockNetworkInfo.getWifiBSSID())
          .thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'TestWiFi');
      when(() => mockNetworkInfo.getWifiGatewayIP())
          .thenAnswer((_) async => '192.168.1.1');

      await tester.pumpWidget(createHomePageTestWidget(const HomePage()));

      await tester.pumpAndSettle();

      // Network Troubleshooting card
      expect(find.text('Network Troubleshooting'), findsOneWidget);
      expect(find.byKey(WidgetKey.ping.key), findsOneWidget);
      expect(
        find.byKey(WidgetKey.scanForOpenPortsButton.key),
        findsOneWidget,
      );
    });

    testWidgets('renders DNS card with Lookup and Reverse Lookup buttons',
        (tester) async {
      when(() => mockNetworkInfo.getWifiIP())
          .thenAnswer((_) async => '192.168.1.100');
      when(() => mockNetworkInfo.getWifiBSSID())
          .thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'TestWiFi');
      when(() => mockNetworkInfo.getWifiGatewayIP())
          .thenAnswer((_) async => '192.168.1.1');

      await tester.pumpWidget(createHomePageTestWidget(const HomePage()));

      await tester.pumpAndSettle();

      // DNS card
      expect(find.text('Domain Name System (DNS)'), findsOneWidget);
      expect(find.byKey(WidgetKey.dnsLookupButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.reverseDnsLookupButton.key), findsOneWidget);
    });

    testWidgets('shows ISP card with In-App Internet disabled message',
        (tester) async {
      when(() => mockNetworkInfo.getWifiIP())
          .thenAnswer((_) async => '192.168.1.100');
      when(() => mockNetworkInfo.getWifiBSSID())
          .thenAnswer((_) async => 'aa:bb:cc:dd:ee:ff');
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'TestWiFi');
      when(() => mockNetworkInfo.getWifiGatewayIP())
          .thenAnswer((_) async => '192.168.1.1');

      await tester.pumpWidget(createHomePageTestWidget(const HomePage()));

      await tester.pumpAndSettle();

      // ISP card should be present
      expect(find.text('Internet Service Provider (ISP)'), findsOneWidget);
      expect(find.text("In-App Internet is off"), findsOneWidget);
    });
  });
}
