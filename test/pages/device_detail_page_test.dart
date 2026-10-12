import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/keys.dart';

void main() {
  const testDevice = DeviceData(
    id: 1,
    scanId: 1,
    internetAddress: '192.168.1.42',
    currentDeviceIp: '192.168.1.10',
    gatewayIp: '192.168.1.1',
    macAddress: 'AA:BB:CC:DD:EE:FF',
    hostMake: 'Apple Inc.',
    mdnsDomainName: 'my-macbook.local',
  );

  Widget createWidgetUnderTest(DeviceData device) {
    return ChangeNotifierProvider(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(
        home: DeviceDetailPage(device: device),
      ),
    );
  }

  group('DeviceDetailPage', () {
    testWidgets('renders device identity header correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      expect(find.text('Device details'), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailName.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailIp.key), findsOneWidget);
      expect(find.text('192.168.1.42'), findsWidgets);
    });

    testWidgets('renders network information section', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      expect(find.text('Network information'), findsOneWidget);
      expect(find.text('IP address'), findsOneWidget);
      expect(find.text('MAC address'), findsOneWidget);
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
      expect(find.text('Vendor / Hostname'), findsOneWidget);
      expect(find.text('Apple Inc.'), findsOneWidget);
      expect(find.text('mDNS name'), findsOneWidget);
      expect(find.text('my-macbook.local'), findsWidgets);
      expect(find.text('Gateway'), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);
    });

    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      expect(find.text('Actions'), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailPortScanButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailQuickScanButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailPingButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailWolButton.key), findsOneWidget);
    });

    testWidgets('hides Wake on LAN button when MAC is not present', (tester) async {
      const deviceWithoutMac = DeviceData(
        id: 2,
        scanId: 1,
        internetAddress: '192.168.1.50',
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
      );

      await tester.pumpWidget(createWidgetUnderTest(deviceWithoutMac));

      expect(find.byKey(WidgetKey.deviceDetailWolButton.key), findsNothing);
      expect(find.text('MAC address'), findsNothing);
    });

    testWidgets('shows port scan initial state', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      expect(find.text('Open ports'), findsOneWidget);
      expect(
        find.text('Tap "Quick scan" to check for common open ports on this device.'),
        findsOneWidget,
      );
    });

    testWidgets('ping button navigates to PingPage with target IP prefilled', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      await tester.tap(find.byKey(WidgetKey.deviceDetailPingButton.key));
      await tester.pumpAndSettle();

      expect(find.text('Check connection'), findsOneWidget);
      expect(find.text('192.168.1.42'), findsOneWidget);
    });

    testWidgets('full port scan button navigates to PortScanPage with target IP', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      await tester.tap(find.byKey(WidgetKey.deviceDetailPortScanButton.key));
      await tester.pumpAndSettle();

      expect(find.byType(PortScanPage), findsOneWidget);
      expect(find.text('Find security gaps'), findsOneWidget);
    });
  });
}
