import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/health_report/network_health_report_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/health_report_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/services/network_analysis/network_health_report_service.dart';
import 'package:vernet/services/network_score_service.dart';
import 'package:vernet/ui/device_risk_chip.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';
import '../wifi_test/wifi_test_runner.dart' show clearDatabase;

/// The resource bundle the test device renders: these suites run in English.
final _en = AppLocalizationsEn();

const _desktopWindow = Size(1280, 1200);
const _tallWindow = Size(1000, 2000);

late ScanRepository _scans;
late DeviceRepository _devices;
late HealthReportRepository _reports;

/// Every MAC the fixtures insert, forgotten before and after each test so a
/// trust verdict left by another suite cannot change the score's device line.
const _fixtureMacs = [
  '00:03:93:AA:BB:01',
  '00:03:93:AA:BB:02',
  '02:11:22:33:44:55',
];

const _fixtureAddresses = [
  '192.168.0.5',
  '192.168.0.6',
  '192.168.0.7',
  '10.0.0.7',
];

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Health reports have no foreign key to scans, so clearing the scan tables
/// leaves their snapshots behind for the trend line to pick up.
Future<void> _clearHealthReports() async {
  try {
    final database = await getIt<DatabaseService<AppDatabase>>().open();
    await database!.delete(database.healthReport).go();
  } catch (error) {
    debugPrint('Failed to clear health reports: $error');
  }
}

Future<void> _forgetFixtures() async {
  final trust = getIt<DeviceTrustService>();
  for (final mac in _fixtureMacs) {
    final key = DeviceUtil.macDeviceKey(mac);
    if (key != null) await trust.forget(key);
  }
  for (final address in _fixtureAddresses) {
    await trust.forget(DeviceUtil.addressDeviceKey(address));
  }
}

Future<ScanData> _insertScan({
  required int id,
  required String gatewayIp,
  required DateTime startTime,
  DateTime? endTime,
  bool onGoing = false,
}) =>
    _scans.put(
      ScanData(
        id: id,
        gatewayIp: gatewayIp,
        startTime: startTime,
        endTime: endTime,
        onGoing: onGoing,
      ),
    );

Future<DeviceData> _insertDevice({
  required int id,
  required int scanId,
  required String gatewayIp,
  required String internetAddress,
  String? macAddress,
  String? hostMake,
  String? vendorName,
  String? deviceType,
  String? openPorts,
}) =>
    _devices.put(
      DeviceData(
        id: id,
        scanId: scanId,
        internetAddress: internetAddress,
        currentDeviceIp: '192.168.0.10',
        gatewayIp: gatewayIp,
        macAddress: macAddress,
        hostMake: hostMake,
        vendorName: vendorName,
        deviceType: deviceType,
        openPorts: openPorts,
      ),
    );

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp(null));
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

/// Scrolls [scrollable] until [target] is built, then brings it on screen.
///
/// The pages under test are `ListView`s, so a section below the fold has no
/// element until it is dragged into the cache extent.
Future<void> _revealInPage(
  WidgetTester tester,
  Finder scrollable,
  Finder target,
) async {
  for (var attempt = 0; attempt < 15 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (target.evaluate().isEmpty) {
    fail('${target.description} was never built by scrolling.');
  }
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<NetworkScore> _waitForScore(
  WidgetTester tester,
  bool Function(NetworkScore score) done,
) async {
  final bloc = getIt<NetworkScoreBloc>();
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final score = bloc.state.maybeWhen(
      success: (value) => value,
      orElse: () => null,
    );
    if (score != null && done(score)) return score;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  fail('the score bloc never reached the expected state');
}

Future<void> _waitForStoredReport(WidgetTester tester, int scanId) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await _reports.get(scanId) != null) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the health report snapshot for scan $scanId was never stored');
}

Finder _chipLabel(String label) => find.descendant(
      of: find.byType(DeviceRiskChip),
      matching: find.text(label),
    );

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .localesTestValue = const [Locale('en')];

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
    _scans = getIt<ScanRepository>();
    _devices = getIt<DeviceRepository>();
    _reports = getIt<HealthReportRepository>();
    await clearDatabase();
    await _clearHealthReports();
    await _forgetFixtures();
  });

  tearDown(() async {
    await clearDatabase();
    await _clearHealthReports();
    await _forgetFixtures();
  });

  group('Scan insights', () {
    testWidgets('the report tiers each device and opens its findings',
        (tester) async {
      _useWindow(tester, _desktopWindow);
      final start = DateTime.now().subtract(const Duration(minutes: 8));
      final scan = await _insertScan(
        id: 1101,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 40)),
      );
      // Telnet is critical, so this device is high.
      await _insertDevice(
        id: 11001,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        vendorName: 'Acme Networks',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '23,443',
      );
      // 80 is only an info finding, so this device is medium.
      await _insertDevice(
        id: 11002,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.6',
        macAddress: '02:11:22:33:44:55',
        hostMake: 'Phone',
        deviceType: 'phone',
        openPorts: '80',
      );
      // One named, encrypted port leaves this device low.
      await _insertDevice(
        id: 11003,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.7',
        hostMake: 'Printer',
        deviceType: 'printer',
        openPorts: '443',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '192.168.0');

      await TestUtils.waitForAnyWidget(tester, find.byType(DeviceRiskChip));
      expect(_chipLabel(_en.deviceRiskLevelHigh), findsOneWidget);
      expect(_chipLabel(_en.deviceRiskLevelMedium), findsOneWidget);
      expect(_chipLabel(_en.deviceRiskLevelLow), findsOneWidget);
      expect(
        find.byTooltip(_en.deviceRiskReasonVulnerableService),
        findsOneWidget,
      );
      expect(find.byTooltip(_en.deviceRiskReasonUnusualPorts), findsOneWidget);
      expect(find.byTooltip(_en.deviceRiskLowDescription), findsOneWidget);

      final address = find.text('192.168.0.5');
      await _revealInPage(
        tester,
        find
            .descendant(
              of: find.byType(ScanDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
        address,
      );
      await tester.tap(address);
      await tester.pumpAndSettle();

      expect(find.byType(DeviceDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DeviceDetailPage),
          matching: find.byTooltip(_en.deviceRiskReasonVulnerableService),
        ),
        findsOneWidget,
      );

      await _revealInPage(
        tester,
        find
            .descendant(
              of: find.byType(DeviceDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
        find.byKey(WidgetKey.deviceDetailSecurityFindings.key),
      );
      expect(find.text(_en.securityFindingTelnetTitle), findsOneWidget);
      expect(find.text(_en.securityFindingTelnetBody), findsOneWidget);
      expect(find.text(_en.securitySeverityCritical), findsOneWidget);
    });

    testWidgets('a device with only encrypted web access shows no findings',
        (tester) async {
      _useWindow(tester, const Size(800, 1600));
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final scan = await _insertScan(
        id: 1201,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 30)),
      );
      final clean = await _insertDevice(
        id: 12001,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.7',
        hostMake: 'Printer',
        deviceType: 'printer',
        openPorts: '443',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => DarkThemeProvider(),
          child: TestUtils.wrapWithLocalizations(
            child: DeviceDetailPage(device: clean),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipLabel(_en.deviceRiskLevelLow), findsOneWidget);

      await _revealInPage(
        tester,
        find
            .descendant(
              of: find.byType(DeviceDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
        find.text(_en.securityFindingsNone),
      );
      expect(find.text(_en.securityFindingTelnetTitle), findsNothing);
    });

    testWidgets('the health report grades the scan and stores its snapshot',
        (tester) async {
      _useWindow(tester, _tallWindow);
      final start = DateTime.now().subtract(const Duration(minutes: 6));
      final scan = await _insertScan(
        id: 1301,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(minutes: 1)),
      );
      await _insertDevice(
        id: 13001,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        vendorName: 'Acme Networks',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '23,443',
      );
      await _insertDevice(
        id: 13002,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.7',
        hostMake: 'Printer',
        deviceType: 'printer',
        openPorts: '443',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '192.168.0');
      await tester.tap(find.byTooltip(_en.healthReportOpenTooltip));
      // The page shows an indeterminate spinner until the report resolves, so
      // it must not be settled here. The real-time wait lets the push
      // transition finish before anything on the new page is tapped; a single
      // pump on a starved frame leaves the page still sliding in, and its
      // right-hand app bar action then sits outside the window.
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(NetworkHealthReportPage), findsOneWidget);
      await TestUtils.waitForWidget(
        tester,
        find.text(_en.healthReportCriticalTitle),
      );

      // One critical finding costs 25 and its high-risk device 10 more.
      expect(find.text('D'), findsOneWidget);
      expect(find.text(_en.healthReportGradeD), findsOneWidget);
      expect(find.text(_en.healthReportScoreOf('65')), findsOneWidget);
      expect(find.text(_en.healthReportTrendUnknown), findsOneWidget);
      expect(find.text(_en.securityFindingTelnetTitle), findsOneWidget);
      expect(find.text('Storage Box · 192.168.0.5'), findsOneWidget);
      expect(find.text(_en.healthReportWarningTitle), findsOneWidget);
      expect(find.text(_en.healthReportInfoTitle), findsOneWidget);
      expect(find.text(_en.healthReportNoFindings), findsNWidgets(2));
      expect(find.text(_en.healthReportDeviceSummary), findsOneWidget);
      expect(find.text('${_en.deviceRiskLevelHigh} 1'), findsOneWidget);
      expect(find.text('${_en.deviceRiskLevelLow} 1'), findsOneWidget);
      // The report sits on top of the scan report, which still renders the
      // same host make in its device row, so this one is scoped.
      expect(
        find.descendant(
          of: find.byType(NetworkHealthReportPage),
          matching: find.text('Storage Box'),
        ),
        findsOneWidget,
      );

      // The tooltip surface spans the app bar action at the window edge, so
      // tap the icon itself.
      expect(find.byTooltip(_en.healthReportCopyTooltip), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await TestUtils.waitForWidget(tester, find.text(_en.healthReportCopied));

      await _waitForStoredReport(tester, scan.id);
    });

    testWidgets('a later scan trends against the saved earlier report',
        (tester) async {
      _useWindow(tester, _tallWindow);
      final oldStart = DateTime.now().subtract(const Duration(hours: 3));
      final oldScan = await _insertScan(
        id: 1401,
        gatewayIp: '192.168.0',
        startTime: oldStart,
        endTime: oldStart.add(const Duration(minutes: 1)),
      );
      final oldDevices = [
        await _insertDevice(
          id: 14001,
          scanId: oldScan.id,
          gatewayIp: '192.168.0',
          internetAddress: '192.168.0.5',
          macAddress: '00:03:93:AA:BB:01',
          vendorName: 'Acme Networks',
          hostMake: 'Storage Box',
          deviceType: 'nas',
          openPorts: '23',
        ),
      ];
      final service = getIt<NetworkHealthReportService>();
      await service.save(await service.buildFor(oldScan, oldDevices, _en));

      final newStart = DateTime.now().subtract(const Duration(minutes: 5));
      final newScan = await _insertScan(
        id: 1402,
        gatewayIp: '10.0.0',
        startTime: newStart,
        endTime: newStart.add(const Duration(seconds: 30)),
      );
      await _insertDevice(
        id: 14002,
        scanId: newScan.id,
        gatewayIp: '10.0.0',
        internetAddress: '10.0.0.7',
        hostMake: 'Printer',
        deviceType: 'printer',
        openPorts: '443',
      );

      await _pumpApp(tester);
      await _openHistoryFromHome(tester);
      await _openScanReport(tester, '10.0.0');
      await tester.tap(find.byTooltip(_en.healthReportOpenTooltip));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
      await TestUtils.waitForWidget(
        tester,
        find.text(_en.healthReportCriticalTitle),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text(_en.healthReportGradeA), findsOneWidget);
      expect(find.text(_en.healthReportTrendImproving), findsOneWidget);

      await _waitForStoredReport(tester, newScan.id);
    });
  });

  group('Network score from scan findings', () {
    testWidgets('Telnet lowers the vulnerabilities dimension and itemises it',
        (tester) async {
      final start = DateTime.now().subtract(const Duration(minutes: 10));
      final scan = await _insertScan(
        id: 1501,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 40)),
      );
      await _insertDevice(
        id: 15001,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '23',
      );
      await _insertDevice(
        id: 15002,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.6',
        macAddress: '00:03:93:AA:BB:02',
        hostMake: 'Phone',
        deviceType: 'phone',
        openPorts: '443',
      );

      final score = await getIt<NetworkScoreService>().computeScore();

      // 25 for the critical finding plus 10 for half the exposed surface.
      expect(score.vulnerabilities.value, 65);
      final factors = score.vulnerabilities.factors;
      expect(
        factors.where(
          (factor) =>
              factor.contains('Telnet') &&
              factor.contains('192.168.0.5') &&
              factor.contains('25'),
        ),
        hasLength(1),
      );
      expect(
        factors.where(
          (factor) => factor.contains('50%') && factor.contains('10'),
        ),
        hasLength(1),
      );
      expect(factors.any((factor) => factor.contains('✓')), isTrue);
    });

    testWidgets('the detail page lists the findings that cost points',
        (tester) async {
      _useWindow(tester, _tallWindow);
      final start = DateTime.now().subtract(const Duration(minutes: 9));
      final scan = await _insertScan(
        id: 1601,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 40)),
      );
      await _insertDevice(
        id: 16001,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '23',
      );
      await _insertDevice(
        id: 16002,
        scanId: scan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.6',
        macAddress: '00:03:93:AA:BB:02',
        hostMake: 'Phone',
        deviceType: 'phone',
        openPorts: '443',
      );

      final devices = await _devices.getListForScan(scan.id);
      getIt<NetworkScoreBloc>().add(
        NetworkScoreEvent.refresh(
          scanAnalysis: NetworkScoreService.analyzeDevices(
            devices,
            l10n: _en,
          ),
        ),
      );
      final score = await _waitForScore(
        tester,
        (value) => value.vulnerabilities.factors
            .any((factor) => factor.contains('Telnet')),
      );
      expect(score.vulnerabilities.value, 65);

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: NetworkScoreDetailPage(initialScore: score),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.text('Vulnerabilities');
      await _revealInPage(
        tester,
        find
            .descendant(
              of: find.byType(NetworkScoreDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
        tile,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Telnet'), findsOneWidget);
      expect(find.textContaining('192.168.0.5'), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.text('-25'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);
    });

    testWidgets('a rescan without the risky service restores the score',
        (tester) async {
      final oldStart = DateTime.now().subtract(const Duration(minutes: 10));
      final oldScan = await _insertScan(
        id: 1701,
        gatewayIp: '192.168.0',
        startTime: oldStart,
        endTime: oldStart.add(const Duration(seconds: 30)),
      );
      await _insertDevice(
        id: 17001,
        scanId: oldScan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '23',
      );

      final service = getIt<NetworkScoreService>();
      final risky = await service.computeScore();
      expect(risky.vulnerabilities.value, 55);
      expect(
        risky.vulnerabilities.factors.any(
          (factor) => factor.contains('Telnet'),
        ),
        isTrue,
      );

      final newStart = DateTime.now().subtract(const Duration(minutes: 3));
      final newScan = await _insertScan(
        id: 1702,
        gatewayIp: '192.168.0',
        startTime: newStart,
        endTime: newStart.add(const Duration(seconds: 20)),
      );
      await _insertDevice(
        id: 17002,
        scanId: newScan.id,
        gatewayIp: '192.168.0',
        internetAddress: '192.168.0.5',
        macAddress: '00:03:93:AA:BB:01',
        hostMake: 'Storage Box',
        deviceType: 'nas',
        openPorts: '443',
      );

      final recovered = await service.computeScore();
      expect(recovered.vulnerabilities.value, 100);
      expect(
        recovered.vulnerabilities.factors.any(
          (factor) => factor.contains('Telnet'),
        ),
        isFalse,
      );
      expect(
        recovered.vulnerabilities.factors.any(
          (factor) => factor.contains('✓'),
        ),
        isTrue,
      );
    });
  });
}
