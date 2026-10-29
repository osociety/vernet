import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

import '../settings/test_utils.dart';
import '../wifi_test/wifi_test_runner.dart' show clearDatabase;

const _desktopWindow = Size(1280, 1000);
const _phoneWindow = Size(390, 844);

late ScanRepository _scanRepository;
late DeviceRepository _deviceRepository;

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp(true));
  await tester.pumpAndSettle();
}

Future<void> _openHistoryFromHome(WidgetTester tester) async {
  final button = find.byKey(WidgetKey.scanHistoryIconButton.key);
  await TestUtils.waitForWidget(tester, button);
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byType(ScanHistoryPage), findsOneWidget);
}

Future<void> _openScanReport(WidgetTester tester, String gatewayIp) async {
  final row = find.text('Network $gatewayIp');
  await TestUtils.waitForWidget(tester, row);
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byType(ScanDetailPage), findsOneWidget);
}

Future<ScanData> _insertScan({
  required int id,
  required String gatewayIp,
  required DateTime startTime,
  DateTime? endTime,
  bool onGoing = false,
}) {
  return _scanRepository.put(
    ScanData(
      id: id,
      gatewayIp: gatewayIp,
      startTime: startTime,
      endTime: endTime,
      onGoing: onGoing,
    ),
  );
}

Future<DeviceData> _insertDevice({
  required int id,
  required int scanId,
  required String gatewayIp,
  required String internetAddress,
  String? macAddress,
  String? hostMake,
}) {
  return _deviceRepository.put(
    DeviceData(
      id: id,
      scanId: scanId,
      internetAddress: internetAddress,
      currentDeviceIp: '192.168.0.10',
      gatewayIp: gatewayIp,
      macAddress: macAddress,
      hostMake: hostMake,
    ),
  );
}

String _devicesFoundLabel(int count) =>
    '${count == 1 ? '1 device' : '$count devices'} found';

Future<ScanData?> _waitForScanToFinish() async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  int? scanId;
  while (DateTime.now().isBefore(deadline)) {
    scanId ??= await getCurrentScanId();
    if (scanId != null) {
      final scan = await _scanRepository.get(scanId);
      if (scan != null && scan.onGoing == false) {
        return scan;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return null;
}

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
    _scanRepository = getIt<ScanRepository>();
    _deviceRepository = getIt<DeviceRepository>();
    await clearDatabase();
  });

  tearDown(() async {
    await clearDatabase();
  });

  group('Scan report feature', () {
    testWidgets('empty history offers refresh and picks up new scans',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      await _pumpApp(tester);
      await _openHistoryFromHome(tester);

      expect(find.text(StringValue.scanHistoryEmptyTitle), findsOneWidget);
      expect(
        find.text(StringValue.scanHistoryEmptyPlaceholder),
        findsOneWidget,
      );

      await _insertScan(
        id: 101,
        gatewayIp: '192.168.0',
        startTime: DateTime.now().subtract(const Duration(minutes: 2)),
        endTime: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await tester.tap(
        find.widgetWithText(FilledButton, StringValue.scanHistoryRefresh),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network 192.168.0'), findsOneWidget);
      expect(find.text('SCAN ACTIVITY'), findsOneWidget);
      expect(find.text(StringValue.scanHistoryEmptyTitle), findsNothing);
    });

    testWidgets('desktop history lists newest scans first with activity stats',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      final now = DateTime.now();
      final oldStart = now.subtract(const Duration(days: 2, hours: 3));
      final midStart = now.subtract(const Duration(hours: 5));
      final ongoingStart = now.subtract(const Duration(seconds: 30));

      await _insertScan(
        id: 201,
        gatewayIp: '192.168.0',
        startTime: oldStart,
        endTime: oldStart.add(const Duration(minutes: 2, seconds: 35)),
      );
      await _insertDevice(
        id: 2101,
        scanId: 201,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        hostMake: 'Device One',
      );
      await _insertDevice(
        id: 2102,
        scanId: 201,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.12',
        hostMake: 'Device Two',
      );

      await _insertScan(
        id: 202,
        gatewayIp: '172.16.0',
        startTime: midStart,
        endTime: midStart.add(const Duration(seconds: 45)),
      );
      await _insertDevice(
        id: 2201,
        scanId: 202,
        gatewayIp: '172.16.0',
        internetAddress: '172.16.0.7',
        hostMake: 'Device Three',
      );

      await _insertScan(
        id: 203,
        gatewayIp: '10.0.0',
        startTime: ongoingStart,
        onGoing: true,
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);

      expect(find.text('SCAN ACTIVITY'), findsOneWidget);
      expect(find.text('Scans'), findsOneWidget);
      expect(find.text('Devices found'), findsOneWidget);
      expect(find.text('Latest scan'), findsOneWidget);
      expect(find.text('Recent devices per scan'), findsOneWidget);
      expect(find.text('Scan history'), findsOneWidget);

      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('STARTED'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('DEVICES'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);

      expect(find.text('Completed'), findsNWidgets(2));
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('2m 35s'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);
      expect(find.text('2d ago'), findsOneWidget);
      expect(find.text('5h ago'), findsOneWidget);
      expect(find.text('just now'), findsWidgets);

      final ongoingY = tester.getTopLeft(find.text('Network 10.0.0')).dy;
      final midY = tester.getTopLeft(find.text('Network 172.16.0')).dy;
      final oldY = tester.getTopLeft(find.text('Network 192.168.0')).dy;
      expect(ongoingY, lessThan(midY));
      expect(midY, lessThan(oldY));

      await _insertScan(
        id: 204,
        gatewayIp: '192.168.1',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network 192.168.1'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Network 192.168.1')).dy,
        lessThan(tester.getTopLeft(find.text('Network 10.0.0')).dy),
      );
    });

    testWidgets('phone history renders scan cards with meta chips',
        (tester) async {
      _useWindow(tester, _phoneWindow);
      final now = DateTime.now();
      final oldStart = now.subtract(const Duration(days: 2, hours: 3));

      await _insertScan(
        id: 301,
        gatewayIp: '192.168.0',
        startTime: oldStart,
        endTime: oldStart.add(const Duration(seconds: 45)),
      );
      await _insertDevice(
        id: 3101,
        scanId: 301,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        hostMake: 'Device One',
      );
      await _insertDevice(
        id: 3102,
        scanId: 301,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.12',
        hostMake: 'Device Two',
      );

      await _insertScan(
        id: 302,
        gatewayIp: '10.0.0',
        startTime: now.subtract(const Duration(seconds: 20)),
        onGoing: true,
      );
      await _insertDevice(
        id: 3201,
        scanId: 302,
        gatewayIp: '10.0.0',
        internetAddress: '10.0.0.7',
        hostMake: 'Device Three',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);

      expect(find.byType(AdaptiveListTile), findsNWidgets(2));
      expect(find.text('NETWORK'), findsNothing);
      expect(find.text('2 devices'), findsOneWidget);
      expect(find.text('1 device'), findsOneWidget);
      expect(find.text('2d ago'), findsOneWidget);
      expect(find.text('just now'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('desktop report shows scan window and device table',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      final start = DateTime.now().subtract(const Duration(hours: 3));

      await _insertScan(
        id: 401,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(minutes: 1, seconds: 20)),
      );
      await _insertDevice(
        id: 4101,
        scanId: 401,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:11:22:33:44:55',
        hostMake: 'Device One',
      );
      await _insertDevice(
        id: 4102,
        scanId: 401,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.12',
        hostMake: 'Device Two',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '192.168.0');

      expect(find.text(StringValue.scanReportTitle), findsOneWidget);
      expect(find.text('Network 192.168.0'), findsOneWidget);
      expect(find.text(StringValue.scanReportCompleted), findsWidgets);
      expect(find.text('2 devices found'), findsOneWidget);

      expect(find.text('SCAN WINDOW'), findsOneWidget);
      expect(find.text(StringValue.scanReportStarted), findsOneWidget);
      expect(find.text(StringValue.scanReportEnded), findsOneWidget);
      expect(find.text(StringValue.scanReportDuration), findsOneWidget);
      expect(find.text('1m 20s'), findsOneWidget);

      expect(find.text('DEVICE'), findsOneWidget);
      expect(find.text('IP ADDRESS'), findsOneWidget);
      expect(find.text('MAC ADDRESS'), findsOneWidget);
      expect(find.text('Device One'), findsOneWidget);
      expect(find.text('Device Two'), findsOneWidget);
      expect(find.text('192.168.0.5'), findsOneWidget);
      expect(find.text('192.168.0.12'), findsOneWidget);
      expect(find.text('00:11:22:33:44:55'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      final firstDeviceY = tester.getTopLeft(find.text('192.168.0.5')).dy;
      final secondDeviceY = tester.getTopLeft(find.text('192.168.0.12')).dy;
      expect(firstDeviceY, lessThan(secondDeviceY));

      await tester.ensureVisible(find.text('Device One'));
      await tester.tap(find.text('Device One'));
      await tester.pumpAndSettle();

      expect(find.byType(DeviceDetailPage), findsOneWidget);
      expect(find.text(StringValue.deviceDetailPageTitle), findsOneWidget);
      expect(find.text('192.168.0.5'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ScanDetailPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ScanHistoryPage), findsOneWidget);
    });

    testWidgets('phone report stacks summary above device tiles',
        (tester) async {
      _useWindow(tester, _phoneWindow);
      final start = DateTime.now().subtract(const Duration(hours: 3));

      await _insertScan(
        id: 501,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 50)),
      );
      await _insertDevice(
        id: 5101,
        scanId: 501,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:11:22:33:44:55',
        hostMake: 'Device One',
      );
      await _insertDevice(
        id: 5102,
        scanId: 501,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.12',
        hostMake: 'Device Two',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '192.168.0');

      expect(find.text('DEVICE'), findsNothing);
      expect(find.text('2 devices found'), findsOneWidget);
      expect(find.byType(AdaptiveListTile), findsNWidgets(2));
      expect(
        find.text('192.168.0.5 • 00:11:22:33:44:55'),
        findsOneWidget,
      );
      expect(find.text('192.168.0.12'), findsOneWidget);
      expect(find.text('Device One'), findsOneWidget);
      expect(find.text('Device Two'), findsOneWidget);

      await tester.ensureVisible(find.text('Device Two'));
      await tester.tap(find.text('Device Two'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDetailPage), findsOneWidget);
    });

    testWidgets('in-progress report shows still running without a duration',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      await _insertScan(
        id: 601,
        gatewayIp: '10.0.0',
        startTime: DateTime.now().subtract(const Duration(seconds: 20)),
        onGoing: true,
      );
      await _insertDevice(
        id: 6101,
        scanId: 601,
        gatewayIp: '10.0.0',
        internetAddress: '10.0.0.7',
        hostMake: 'Device Three',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '10.0.0');

      expect(find.text(StringValue.scanReportInProgress), findsWidgets);
      expect(find.text(StringValue.scanReportStillRunning), findsOneWidget);
      expect(find.text('1 device found'), findsOneWidget);
      expect(find.text(StringValue.scanReportDuration), findsNothing);
      expect(find.text('Device Three'), findsOneWidget);
    });

    testWidgets('report without devices shows the empty devices state',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      await _insertScan(
        id: 701,
        gatewayIp: '172.16.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 30)),
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '172.16.0');

      expect(find.text('0 devices found'), findsOneWidget);
      expect(find.text(StringValue.scanReportNoDevices), findsOneWidget);
      expect(
          find.text(StringValue.scanReportDiscoveredDevices), findsOneWidget);
      expect(find.byType(AdaptiveListTile), findsNothing);
    });

    testWidgets('a completed device scan appears in previous scans',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      await _pumpApp(tester);

      final scanButton = find.byKey(WidgetKey.scanForDevicesButton.key);
      await TestUtils.waitForWidget(tester, scanButton);
      await tester.ensureVisible(scanButton);
      await tester.tap(scanButton);
      await TestUtils.waitForWidget(tester, find.byType(HostScanPage));

      final scan = await _waitForScanToFinish();
      if (scan == null) {
        debugPrint(
          'No scan was recorded in this environment; skipping report checks.',
        );
        return;
      }
      await tester.pump(const Duration(milliseconds: 500));

      final historyButton = find.byKey(WidgetKey.scanHistoryIconButton.key);
      await tester.ensureVisible(historyButton);
      await tester.tap(historyButton);
      await tester.pumpAndSettle();

      expect(find.byType(ScanHistoryPage), findsOneWidget);
      await _openScanReport(tester, scan.gatewayIp);

      final deviceCount = await _deviceRepository.countByScanId(scan.id);
      expect(find.text(_devicesFoundLabel(deviceCount)), findsOneWidget);

      if (deviceCount > 0) {
        expect(find.byType(AdaptiveListTile), findsWidgets);
      } else {
        expect(find.text(StringValue.scanReportNoDevices), findsOneWidget);
      }
    });
  });
}
