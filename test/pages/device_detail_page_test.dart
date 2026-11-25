import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/values/keys.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceDetailPage(device: device),
      ),
    );
  }

  /// Drift schedules a zero-delay timer when the page's watched query is
  /// cancelled, and the test binding flags it if it outlives the test.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
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
      expect(find.text('Hostname'), findsOneWidget);
      expect(find.text('Apple Inc.'), findsOneWidget);
      expect(find.text('Vendor'), findsNothing);
      expect(find.text('mDNS name'), findsOneWidget);
      expect(find.text('my-macbook.local'), findsWidgets);
      expect(find.text('Gateway'), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);
    });

    testWidgets('renders the MAC vendor resolved during discovery',
        (tester) async {
      const deviceWithVendor = DeviceData(
        id: 1,
        scanId: 1,
        internetAddress: '192.168.1.42',
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
        macAddress: '00:03:93:DD:EE:FF',
        vendorName: 'Apple, Inc.',
        hostMake: 'my-macbook.local',
      );

      await tester.pumpWidget(createWidgetUnderTest(deviceWithVendor));

      expect(find.text('Vendor'), findsOneWidget);
      expect(find.text('Apple, Inc.'), findsOneWidget);
      expect(find.text('Hostname'), findsOneWidget);
    });

    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(testDevice));

      expect(find.text('Actions'), findsOneWidget);
      expect(
          find.byKey(WidgetKey.deviceDetailPortScanButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailQuickScanButton.key),
          findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailPingButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.deviceDetailWolButton.key), findsOneWidget);
    });

    testWidgets('hides Wake on LAN button when MAC is not present',
        (tester) async {
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
        find.text(
            'Tap "Quick scan" to check for common open ports on this device.'),
        findsOneWidget,
      );
    });

    testWidgets('ping button navigates to PingPage with target IP prefilled',
        (tester) async {
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

    testWidgets(
        'full port scan button navigates to PortScanPage with target IP',
        (tester) async {
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

  group('device trust', () {
    late AppDatabase db;
    late DeviceTrustService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      db = AppDatabase(NativeDatabase.memory());
      service = DeviceTrustService(
        KnownDeviceRepository(_InMemoryDatabaseService(db)),
      );
      await service.addTrustedMac('AA:BB:CC:DD:EE:FF', label: 'MacBook');
      getIt.registerSingleton<DeviceTrustService>(service);
    });

    tearDown(() async {
      await getIt.reset();
      await db.close();
    });

    testWidgets('shows the shield and trusts or revokes the device',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(testDevice));
      await tester.pumpAndSettle();

      expect(find.text('Device trust'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user), findsWidgets);
      final toggle = tester.widget<SwitchListTile>(find.byKey(
        WidgetKey.deviceDetailTrustSwitch.key,
      ));
      expect(toggle.value, isTrue);

      await tester.tap(find.byKey(WidgetKey.deviceDetailTrustSwitch.key));
      await tester.pumpAndSettle();

      final row = await service.getAll();
      expect(row.single.trusted, isFalse);
      expect(find.byIcon(Icons.gpp_maybe), findsWidgets);
      await disposeTree(tester);
    });
  });
}
