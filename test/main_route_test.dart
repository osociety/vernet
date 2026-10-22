import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'Vernet',
        'packageName': 'org.fsociety.vernet',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
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

  group('Main.dart Route Tests', () {
    testWidgets('initial route shows HomePage when allowed=true',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('MyApp with allowed=false shows LocationConsentPage',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Should show LocationConsentPage when not allowed
      expect(find.byType(LocationConsentPage), findsOneWidget);
    });

    testWidgets('navigatorKey is properly configured', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(MyApp.navigatorKey.currentState, isNotNull);
      expect(MyApp.navigatorKey.currentState?.context, isNotNull);
    });

    testWidgets('MyApp is StatefulWidget', (tester) async {
      expect(const MyApp(true), isA<StatefulWidget>());
    });

    testWidgets('MyApp navigatorKey is static and accessible', (tester) async {
      expect(MyApp.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });
}
