import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock NetworkInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/network_info'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getWifiIP':
          return '192.168.1.10';
        case 'getWifiBSSID':
          return '00:11:22:33:44:55';
        case 'getWifiName':
          return 'Mock WiFi';
        case 'getWifiGatewayIP':
          return '192.168.1.1';
        default:
          return null;
      }
    });

    // Mock PermissionHandler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions' ||
          methodCall.method == 'checkPermissionStatus' ||
          methodCall.method == 'checkServiceStatus') {
        return 1; // Granted / Enabled
      }
      return null;
    });

    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });
  });

  group('Run device scan on startup', () {
    testWidgets('if settings for startup is on, then it should run',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.tapByWidgetKey(
        WidgetKey.runOnAppStartupSwitch,
        tester,
        find,
      );

      await TestUtils.tapHomeButton(tester, find);

      // pump with a longer timeout to rebuild HomePage after navigation
      // and allow platform channels to respond
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(WidgetKey.runScanOnStartup.key), findsOne);
    });
  });
}
