import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/models/network_finding.dart';
import 'package:vernet/models/network_health_report.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/health_report_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_analysis/device_risk_service.dart';
import 'package:vernet/services/network_analysis/network_health_report_service.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late DeviceRepository devices;
  late ScanRepository scans;
  late HealthReportRepository reports;
  late NetworkHealthReportService service;
  var nextDeviceId = 1;

  ScanData scan(int id, {int day = 1}) => ScanData(
        id: id,
        gatewayIp: '192.168.0',
        startTime: DateTime(2024, 1, day, 10),
        endTime: DateTime(2024, 1, day, 10, 0, 30),
        onGoing: false,
      );

  DeviceData device({
    required int scanId,
    String address = '192.168.0.20',
    String? hostMake = 'Printer',
    String? type = 'Printer',
    String? vendor = 'Acme',
    String? mac = '00:03:93:AA:BB:01',
    String? openPorts,
  }) =>
      DeviceData(
        id: nextDeviceId++,
        scanId: scanId,
        internetAddress: address,
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0.1',
        macAddress: mac,
        vendorName: vendor,
        deviceType: type,
        hostMake: hostMake,
        openPorts: openPorts,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final database = _InMemoryDatabaseService(db);
    devices = DeviceRepository(database);
    scans = ScanRepository(database);
    reports = HealthReportRepository(database);
    service = NetworkHealthReportService(
      devices,
      scans,
      reports,
      DeviceRiskService(devices, scans),
    );
    nextDeviceId = 1;
    await scans.put(scan(1));
  });

  tearDown(() async {
    await db.close();
  });

  test('a clean scan earns an A and lists no finding', () async {
    final printer = device(scanId: 1, openPorts: '631');
    await devices.put(printer);

    final report = await service.buildFor(scan(1), [printer], l10n);

    expect(report.score, 100);
    expect(report.grade, HealthGrade.a);
    expect(report.critical, isEmpty);
    expect(report.warnings, isEmpty);
    expect(report.infos, isEmpty);
    expect(report.lowRiskDevices, 1);
    expect(report.mediumRiskDevices, 0);
    expect(report.highRiskDevices, 0);
    expect(report.trend, HealthTrendDirection.unknown);
    expect(report.previousScore, isNull);
  });

  test('a telnet device drops the grade and lands in the critical list',
      () async {
    final legacy = device(
      scanId: 1,
      address: '192.168.0.50',
      hostMake: 'Legacy box',
      type: 'Server',
      openPorts: '23',
    );
    await devices.put(legacy);

    final report = await service.buildFor(scan(1), [legacy], l10n);

    expect(report.score, 65);
    expect(report.grade, HealthGrade.d);
    expect(report.critical, hasLength(1));
    expect(report.critical.single.finding.code, NetworkFindingCode.telnet);
    expect(report.critical.single.finding.port, 23);
    expect(report.critical.single.deviceLabel, 'Legacy box');
    expect(report.critical.single.address, '192.168.0.50');
    expect(report.highRiskDevices, 1);
    expect(report.notableDevices, ['Legacy box']);
    expect(report.warnings, isEmpty);
  });

  test('a warning finding still lowers the score without a critical', () async {
    final fileServer = device(
      scanId: 1,
      hostMake: 'File server',
      type: 'Server',
      openPorts: '21',
    );
    await devices.put(fileServer);

    final report = await service.buildFor(scan(1), [fileServer], l10n);

    // 100 - 10 for the warning - 10 for the high tier it causes.
    expect(report.score, 80);
    expect(report.grade, HealthGrade.b);
    expect(report.critical, isEmpty);
    expect(report.warnings, hasLength(1));
  });

  test('the trend compares against the previous stored scan', () async {
    final printer = device(scanId: 1, openPorts: '631');
    await devices.put(printer);
    await service.save(await service.buildFor(scan(1), [printer], l10n));

    await scans.put(scan(2, day: 2));
    final legacy = device(
      scanId: 2,
      address: '192.168.0.50',
      hostMake: 'Legacy box',
      type: 'Server',
      openPorts: '23',
    );
    await devices.put(legacy);
    final worse = await service.buildFor(scan(2, day: 2), [legacy], l10n);
    expect(worse.previousScore, 100);
    expect(worse.trend, HealthTrendDirection.degrading);
    await service.save(worse);

    await scans.put(scan(3, day: 3));
    final clean = device(
      scanId: 3,
      address: '192.168.0.30',
      hostMake: 'Laptop',
      type: 'Linux/Unix Device',
      mac: '00:03:93:AA:BB:03',
      openPorts: '631',
    );
    await devices.put(clean);
    final better = await service.buildFor(scan(3, day: 3), [clean], l10n);
    expect(better.score, 100);
    expect(better.previousScore, 65);
    expect(better.trend, HealthTrendDirection.improving);
  });

  test('an info-only device still costs less than a warning', () async {
    final printer = device(scanId: 1, openPorts: '631');
    await devices.put(printer);
    final first = await service.buildFor(scan(1), [printer], l10n);
    // The info finding costs 3, and an info-only device is medium, which
    // costs another 3.
    final infoOnly = await service.buildFor(
      scan(1),
      [device(scanId: 1, openPorts: '80')],
      l10n,
    );
    expect(first.score, 100);
    expect(infoOnly.score, 94);
    expect(infoOnly.infos, hasLength(1));
    expect(infoOnly.mediumRiskDevices, 1);
  });

  test('moves under five points read as stable', () {
    expect(
      NetworkHealthReport.directionFor(97, 100),
      HealthTrendDirection.stable,
    );
    expect(
      NetworkHealthReport.directionFor(103, 100),
      HealthTrendDirection.stable,
    );
    expect(
      NetworkHealthReport.directionFor(100, null),
      HealthTrendDirection.unknown,
    );
  });

  test('saving the same scan twice keeps one snapshot', () async {
    final printer = device(scanId: 1, openPorts: '631');
    await devices.put(printer);
    final report = await service.buildFor(scan(1), [printer], l10n);
    await service.save(report);
    await service.save(report);

    final stored = await reports.getAll();
    expect(stored, hasLength(1));
    expect(stored.single.scanId, 1);
    expect(stored.single.score, 100);
    expect(stored.single.grade, 'a');
    expect(stored.single.lowRiskCount, 1);
  });
}
