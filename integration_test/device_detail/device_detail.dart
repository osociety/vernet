import 'dart:io';

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
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';

/// The resource bundle the test device renders: these suites run in English.
final _en = AppLocalizationsEn();
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
    vendorName: 'CIMSYS Inc',
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

  /// Polls the registry because the switch writes through the service and the
  /// card rebuilds from the watcher stream, not from the tap itself.
  Future<void> waitForTrust(
    WidgetTester tester,
    DeviceTrustService service,
    DeviceData device, {
    required bool trusted,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final rows = await service.getAll();
      if (DeviceTrustService.knownDeviceFor(rows, device)?.trusted == trusted) {
        await tester.pump();
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('the registry never recorded ${device.internetAddress} as '
        'trusted=$trusted');
  }

  Widget buildTestApp({DeviceData device = testDevice}) {
    return ChangeNotifierProvider(
      create: (_) => DarkThemeProvider(),
      child: TestUtils.wrapWithLocalizations(
        child: DeviceDetailPage(device: device),
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
      expect(find.text(_en.deviceDetailPageTitle), findsOneWidget);

      // Header card
      expect(find.byKey(WidgetKey.deviceDetailName.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailIp.key), findsOneWidget);
      expect(find.text('192.168.1.150'), findsWidgets);

      // Network info section
      expect(find.text('Network information'), findsOneWidget);
      expect(find.text('IP address'), findsOneWidget);
      expect(find.text('MAC address'), findsOneWidget);
      expect(find.text('00:11:22:33:44:55'), findsOneWidget);
      expect(find.text('Vendor'), findsOneWidget);
      expect(find.text('CIMSYS Inc'), findsOneWidget);
      expect(find.text('Hostname'), findsOneWidget);
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

    testWidgets(
        'Full port scan button navigates to PortScanPage with target IP',
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
      expect(find.text(_en.wakeOnLanPageTitle), findsOneWidget);

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

    testWidgets('trust card reflects and updates the device registry',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final trustService = getIt<DeviceTrustService>();
      final deviceKey = DeviceUtil.deviceKey(testDevice);
      await trustService.forget(deviceKey);
      await trustService.setTrusted(testDevice, false);
      addTearDown(() => trustService.forget(deviceKey));

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(_en.deviceTrustCardTitle), findsOneWidget);
      final trustSwitch = find.byKey(WidgetKey.deviceDetailTrustSwitch.key);
      await tester.ensureVisible(trustSwitch);
      await tester.pump();

      expect(tester.widget<SwitchListTile>(trustSwitch).value, isFalse);
      expect(find.text(_en.deviceTrustToggleOff), findsOneWidget);

      await tester.tap(trustSwitch);
      await waitForTrust(
        tester,
        trustService,
        testDevice,
        trusted: true,
      );

      expect(tester.widget<SwitchListTile>(trustSwitch).value, isTrue);
      expect(find.text(_en.deviceTrustToggleOn), findsOneWidget);
    });
  });

  group('MAC vendor lookup', () {
    test('resolves the vendor owning a discovered MAC prefix', () async {
      final host = ActiveHost(
        internetAddress: InternetAddress('192.168.1.10'),
        macAddress: '00:03:93:AB:CD:EF',
      );

      expect((await host.vendor)?.vendorName, 'Apple, Inc.');
    });

    test('leaves the vendor unset for an unregistered prefix', () async {
      final host = ActiveHost(
        internetAddress: InternetAddress('192.168.1.11'),
        macAddress: 'FF:FF:FF:FF:FF:FF',
      );

      expect(await host.vendor, isNull);
    });
  });
}
