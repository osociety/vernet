import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'vernet',
        'packageName': 'org.fsociety.vernet',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => switch (call.method) {
        'getWifiIP' => '192.168.1.10',
        'getWifiBSSID' => '00:11:22:33:44:55',
        'getWifiName' => 'Mock WiFi',
        'getWifiGatewayIP' => '192.168.1.1',
        _ => null,
      },
    );
  });

  tearDown(() {
    NotificationService.skipPermissionRequests = false;
  });

  Future<void> pumpVisibleFrame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpTabBarPage(
    WidgetTester tester, {
    Size size = const Size(900, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(home: TabBarPage()),
      ),
    );
    await pumpVisibleFrame(tester);
  }

  Future<void> openDrawerIfCompact(WidgetTester tester) async {
    final menuButton = find.byIcon(Icons.menu);
    if (menuButton.evaluate().isNotEmpty) {
      await tester.tap(menuButton);
      await pumpVisibleFrame(tester);
    }
  }

  group('MyApp', () {
    testWidgets('renders the redesigned entry point when allowed',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await pumpVisibleFrame(tester);

      expect(find.byType(TabBarPage), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders LocationConsentPage when access is not allowed',
        (tester) async {
      await tester.pumpWidget(const MyApp(false));
      await pumpVisibleFrame(tester);

      expect(find.byType(LocationConsentPage), findsOneWidget);
    });

    testWidgets('navigator key is configured', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await pumpVisibleFrame(tester);

      expect(MyApp.navigatorKey.currentState, isNotNull);
    });
  });

  group('Responsive entry-point navigation', () {
    testWidgets('desktop keeps the sidebar visible beside the home dashboard',
        (tester) async {
      await pumpTabBarPage(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Scan your network'), findsWidgets);
      expect(find.text('Service Provider Details'), findsWidgets);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('sidebar selection replaces the main content', (tester) async {
      await pumpTabBarPage(tester);

      await tester.tap(find.text('Check a website'));
      await pumpVisibleFrame(tester);

      expect(find.byType(PingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.text('Check a website'), findsOneWidget);
    });

    testWidgets('Settings and Home are available from the persistent menu',
        (tester) async {
      await pumpTabBarPage(tester);

      await tester.tap(find.text('Settings').last);
      await pumpVisibleFrame(tester);
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await pumpVisibleFrame(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('compact layout opens the drawer and selects provider details',
        (tester) async {
      await pumpTabBarPage(tester, size: const Size(390, 844));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Service Provider Details'), findsNothing);

      await openDrawerIfCompact(tester);
      await tester.tap(find.text('Service Provider Details').last);
      await pumpVisibleFrame(tester);

      expect(find.text('Turn on internet access in Settings to continue.'),
          findsOneWidget);
      expect(find.text('Service Provider Details'), findsWidgets);
    });
  });
}
