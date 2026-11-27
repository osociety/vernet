import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_analysis/device_risk_service.dart';
import 'package:vernet/utils/device_util.dart';

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
  late DeviceRiskService service;
  var nextDeviceId = 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final database = _InMemoryDatabaseService(db);
    devices = DeviceRepository(database);
    scans = ScanRepository(database);
    service = DeviceRiskService(devices, scans);
    nextDeviceId = 1;
    for (var scan = 1; scan <= 6; scan++) {
      await scans.put(
        ScanData(
          id: scan,
          gatewayIp: '192.168.1',
          startTime: DateTime(2024, 1, scan, 10),
          endTime: DateTime(2024, 1, scan, 10, 0, 30),
          onGoing: false,
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  DeviceData storedDevice({
    required int scanId,
    String address = '192.168.1.20',
    String? mac = '00:03:93:AA:BB:01',
    String openPorts = '631',
  }) =>
      DeviceData(
        id: nextDeviceId++,
        scanId: scanId,
        internetAddress: address,
        macAddress: mac,
        vendorName: 'Acme',
        deviceType: 'Printer',
        openPorts: openPorts,
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
      );

  DeviceData queryDevice({String openPorts = '631'}) => DeviceData(
        id: 0,
        scanId: 1,
        internetAddress: '192.168.1.20',
        macAddress: '00:03:93:AA:BB:01',
        vendorName: 'Acme',
        deviceType: 'Printer',
        openPorts: openPorts,
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
      );

  test('a device seen in every scan stays at low risk', () async {
    for (var scan = 1; scan <= 6; scan++) {
      await devices.put(storedDevice(scanId: scan));
    }

    final result = await service.assessDevices([queryDevice()], l10n);

    final assessment = result[DeviceUtil.deviceKey(queryDevice())]!;
    expect(assessment.level, DeviceRiskLevel.low);
    expect(assessment.reasons, isEmpty);
  });

  test('a device absent from many scans is flagged as intermittent', () async {
    for (final scan in [1, 2, 6]) {
      await devices.put(storedDevice(scanId: scan));
    }

    final result = await service.assessDevices([queryDevice()], l10n);

    final assessment = result[DeviceUtil.deviceKey(queryDevice())]!;
    expect(assessment.level, DeviceRiskLevel.high);
    expect(assessment.reasons, contains(DeviceRiskReason.intermittentPresence));
  });

  test('a device seen once is not judged on history', () async {
    await devices.put(storedDevice(scanId: 1));

    final result = await service.assessDevices([queryDevice()], l10n);

    expect(
      result[DeviceUtil.deviceKey(queryDevice())]!.level,
      DeviceRiskLevel.low,
    );
  });

  test('counts sightings recorded under the address before the MAC', () async {
    // Scan 1 stored no MAC, scans 2 and 5 did. Counting only the MAC key would
    // report three misses instead of the two real ones.
    await devices.put(storedDevice(scanId: 1, mac: null));
    await devices.put(storedDevice(scanId: 2));
    await devices.put(storedDevice(scanId: 5));

    final result = await service.assessDevices([queryDevice()], l10n);

    final assessment = result[DeviceUtil.deviceKey(queryDevice())]!;
    expect(assessment.level, DeviceRiskLevel.low);
    expect(
      assessment.reasons,
      isNot(contains(DeviceRiskReason.intermittentPresence)),
    );
  });

  test('keeps the open-port findings in the tier', () async {
    for (var scan = 1; scan <= 6; scan++) {
      await devices.put(storedDevice(scanId: scan, openPorts: '23'));
    }

    final result = await service.assessDevices(
      [queryDevice(openPorts: '23')],
      l10n,
    );

    expect(
      result.values.single.reasons,
      contains(DeviceRiskReason.vulnerableService),
    );
  });
}
