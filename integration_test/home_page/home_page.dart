import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/ui/network_troubleshoot_dialog.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    NotificationService.skipPermissionRequests = true;
    // Only initialize if not already initialized
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    appSettings.resetForTesting();
    TestUtils.configureAndroidChannelMocks();

    // Mock NetworkInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'wifiIPAddress':
            return '192.168.1.10';
          case 'wifiBSSID':
            return '00:11:22:33:44:55';
          case 'wifiName':
            return 'Mock WiFi';
          case 'wifiGatewayAddress':
            return '192.168.1.1';
          default:
            return null;
        }
      },
    );

    // Mock PermissionHandler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          final permissions = (methodCall.arguments as List<dynamic>?) ?? [];
          return <int, int>{
            for (final permission in permissions) permission as int: 1,
          };
        }
        if (methodCall.method == 'checkPermissionStatus' ||
            methodCall.method == 'checkServiceStatus') {
          return 1;
        }
        return null;
      },
    );

    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'Vernet',
            'packageName': 'org.fsociety.vernet',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return null;
      },
    );
  });

  group('HomePage Integration Tests', () {
    testWidgets('HomePage navigation to HostScanPage works', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Tap the scan button
      await TestUtils.tapByWidgetKey(
        WidgetKey.scanForDevicesButton,
        tester,
        find,
      );
      await tester.pumpAndSettle();

      // Verify HostScanPage is displayed
      expect(find.byType(HostScanPage), findsOneWidget);
    });

    testWidgets('HomePage refresh button works', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.waitForWidget(tester, find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Page should still be visible (no crash)
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('sidebar selection replaces the dashboard content',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapNavigationItem('Check a website', tester, find);

      expect(find.byType(PingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);

      await TestUtils.tapHomeButton(tester, find);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Settings remains available from the sidebar footer',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets(
        'HomePage displays connection path connectors and opens troubleshoot dialog',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify connection path section is shown
      expect(find.text('CONNECTION PATH'), findsOneWidget);

      // Verify device to router connector exists
      final deviceToRouterFinder =
          find.byKey(WidgetKey.deviceToRouterConnector.key);
      await TestUtils.waitForWidget(tester, deviceToRouterFinder);

      // Verify router to internet connector exists
      final routerToInternetFinder =
          find.byKey(WidgetKey.routerToInternetConnector.key);
      expect(routerToInternetFinder, findsOneWidget);

      // Verify the connection status text is displayed
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Connected' ||
                  widget.data == 'Disconnected' ||
                  widget.data == 'Checking…'),
        ),
        findsWidgets,
      );

      // Tap device to router connector to open dialog
      await tester.tap(deviceToRouterFinder);
      await tester.pumpAndSettle();

      // Verify NetworkTroubleshootDialog appears
      expect(find.byType(NetworkTroubleshootDialog), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(NetworkTroubleshootDialog), findsNothing);

      // Tap router to internet connector to open dialog
      await tester.tap(routerToInternetFinder);
      await tester.pumpAndSettle();

      expect(find.byType(NetworkTroubleshootDialog), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(NetworkTroubleshootDialog), findsNothing);
    });
  });
}
