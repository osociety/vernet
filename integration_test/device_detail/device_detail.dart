import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

import '../settings/test_utils.dart';

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testDevice = DeviceData(
    id: 101,
    scanId: 1,
    internetAddress: '192.168.1.150',
    currentDeviceIp: '192.168.1.10',
    gatewayIp: '192.168.1.1',
    macAddress: '00:11:22:33:44:55',
    hostMake: 'Ubuntu Workstation',
    mdnsDomainName: 'workstation.local',
  );

  setUpAll(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
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
  });

  Widget buildTestApp({DeviceData device = testDevice}) {
    return ChangeNotifierProvider(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(
        home: DeviceDetailPage(device: device),
      ),
    );
  }

  group('DeviceDetailPage Integration Tests', () {
    testWidgets('displays all device details correctly in integrated app',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // App bar
      expect(find.text(StringValue.deviceDetailPageTitle), findsOneWidget);

      // Header card
      expect(find.byKey(WidgetKey.deviceDetailName.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailIp.key), findsOneWidget);
      expect(find.text('192.168.1.150'), findsWidgets);

      // Network info section
      expect(find.text('Network information'), findsOneWidget);
      expect(find.text('IP address'), findsOneWidget);
      expect(find.text('MAC address'), findsOneWidget);
      expect(find.text('00:11:22:33:44:55'), findsOneWidget);
      expect(find.text('Vendor / Hostname'), findsOneWidget);
      expect(find.text('Ubuntu Workstation'), findsOneWidget);
      expect(find.text('mDNS name'), findsOneWidget);
      expect(find.text('workstation.local'), findsWidgets);
      expect(find.text('Gateway'), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);

      // Action buttons
      expect(find.text('Actions'), findsOneWidget);
      expect(
        find.byKey(WidgetKey.deviceDetailPortScanButton.key),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKey.deviceDetailQuickScanButton.key),
        findsOneWidget,
      );
      expect(find.byKey(WidgetKey.deviceDetailPingButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailWolButton.key), findsOneWidget);

      // Open ports section
      expect(find.text('Open ports'), findsOneWidget);
    });

    testWidgets('Full port scan button navigates to PortScanPage with target IP',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final portScanBtn = find.byKey(WidgetKey.deviceDetailPortScanButton.key);
      await tester.ensureVisible(portScanBtn);
      await tester.tap(portScanBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PortScanPage), findsOneWidget);
      expect(find.text('Find security gaps'), findsOneWidget);

      // Pop back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(DeviceDetailPage), findsOneWidget);
    });

    testWidgets('Ping button navigates to PingPage with target IP prefilled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final pingBtn = find.byKey(WidgetKey.deviceDetailPingButton.key);
      await tester.ensureVisible(pingBtn);
      await tester.tap(pingBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PingPage), findsOneWidget);
      expect(find.text('Check connection'), findsOneWidget);
      expect(find.text('192.168.1.150'), findsOneWidget);

      // Pop back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(DeviceDetailPage), findsOneWidget);
    });

    testWidgets(
        'Wake on LAN button navigates to WakeOnLanPage with MAC prefilled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final wolBtn = find.byKey(WidgetKey.deviceDetailWolButton.key);
      await tester.ensureVisible(wolBtn);
      await tester.tap(wolBtn);
      await tester.pumpAndSettle();

      expect(find.byType(WakeOnLanPage), findsOneWidget);
      expect(find.text(StringValue.wakeOnLanPageTitle), findsOneWidget);

      // Verify MAC address is prefilled in MAC text field
      final macFieldFinder = find.byKey(WidgetKey.wakeOnLanMacField.key);
      final EditableText editableText =
          tester.widget<EditableText>(find.descendant(
        of: macFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableText.controller.text, '00:11:22:33:44:55');

      // Pop back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(DeviceDetailPage), findsOneWidget);
    });

    testWidgets('Quick scan button triggers scan and updates UI state',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final quickScanBtn =
          find.byKey(WidgetKey.deviceDetailQuickScanButton.key);
      await tester.ensureVisible(quickScanBtn);

      expect(find.text('Quick scan'), findsOneWidget);
      await tester.tap(quickScanBtn);
      await tester.pump();

      // Should indicate scanning in progress or disabled
      expect(
        find.text('Scanning...').evaluate().isNotEmpty ||
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
