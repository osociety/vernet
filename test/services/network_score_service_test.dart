import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/models/network_scan_analysis.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/services/network_score_service.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScanRepository scanRepository;
  late DeviceRepository deviceRepository;
  late DeviceTrustService trustService;
  late NetworkScoreService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();

    db = AppDatabase(NativeDatabase.memory());
    final databaseService = _InMemoryDatabaseService(db);
    scanRepository = ScanRepository(databaseService);
    deviceRepository = DeviceRepository(databaseService);
    trustService = DeviceTrustService(KnownDeviceRepository(databaseService));
    service = NetworkScoreService(
      scanRepository: scanRepository,
      deviceRepository: deviceRepository,
      scoreRepository: NetworkScoreRepository(),
      deviceTrustService: trustService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  var nextDeviceId = 1;

  /// One finished scan carrying [count] devices that all have a MAC and a
  /// name, so the unidentified-device deduction stays out of the way.
  Future<List<DeviceData>> seedScan(
    int count, {
    int scanId = 1,
    DateTime? startTime,
    String? openPorts,
  }) async {
    final start = startTime ?? DateTime(2026, 1, 1, 10);
    await scanRepository.put(
      ScanData(
        id: scanId,
        gatewayIp: '192.168.1',
        startTime: start,
        endTime: start.add(const Duration(seconds: 30)),
        onGoing: false,
      ),
    );
    final devices = [
      for (var i = 0; i < count; i++)
        DeviceData(
          id: nextDeviceId++,
          scanId: scanId,
          internetAddress: '192.168.1.${10 + i}',
          currentDeviceIp: '192.168.1.5',
          gatewayIp: '192.168.1.1',
          macAddress: '00:03:93:AA:BB:${(i + 1).toString().padLeft(2, '0')}',
          hostMake: 'Device ${i + 1}',
          openPorts: openPorts,
        ),
    ];
    for (final device in devices) {
      await deviceRepository.put(device);
    }
    return devices;
  }

  test('deducts five points per untrusted device from security', () async {
    final devices = await seedScan(2);
    await trustService.setTrusted(devices.first, false);

    final score = await service.computeScore();

    expect(score.security.value, 95);
    expect(
      score.security.factors,
      contains('✗ 1 untrusted device(s) on network (-5 points)'),
    );
    expect(
      score.security.factors,
      contains(
        'Tip: Review them in Settings → Trusted devices, or mark them '
        'trusted from the scan results',
      ),
    );
  });

  test('caps the untrusted deduction at 25 points', () async {
    final devices = await seedScan(6);
    for (final device in devices) {
      await trustService.setTrusted(device, false);
    }

    final score = await service.computeScore();

    expect(score.security.value, 75);
    expect(
      score.security.factors,
      contains('✗ 6 untrusted device(s) on network (-25 points)'),
    );
  });

  test('trusted and never-seen devices cost nothing', () async {
    final devices = await seedScan(2);
    await trustService.setTrusted(devices.first, true);

    final score = await service.computeScore();

    expect(score.security.value, 100);
    expect(
      score.security.factors,
      isNot(contains(startsWith('✗ 0 untrusted'))),
    );
    expect(
      score.security.factors.where((factor) => factor.contains('untrusted')),
      isEmpty,
    );
  });

  group('vulnerabilities from scan findings', () {
    test('scores a clean scan at full marks', () async {
      await seedScan(2, openPorts: '443');

      final score = await service.computeScore();

      expect(score.vulnerabilities.value, 100);
      expect(
        score.vulnerabilities.factors,
        contains('✓ No risky services found among 2 exposed service(s)'),
      );
      expect(
        score.vulnerabilities.factors,
        contains('✓ Every device is identified and trusted'),
      );
    });

    test('drops for a critical finding and lists it in the breakdown',
        () async {
      await seedScan(1, openPorts: '23');

      final score = await service.computeScore();

      expect(score.vulnerabilities.value, 55);
      expect(
        score.vulnerabilities.factors,
        contains('✗ Telnet exposed on 192.168.1.10 (-25 points)'),
      );
      expect(
        score.vulnerabilities.factors,
        contains('~ 1 of 1 exposed service(s) are risky (100%) (-20 points)'),
      );
    });

    test('weighs service hygiene by the share of risky services', () async {
      await seedScan(1, openPorts: '23,443,22,53');

      final score = await service.computeScore();

      expect(score.vulnerabilities.value, 70);
      expect(
        score.vulnerabilities.factors,
        contains('~ 1 of 4 exposed service(s) are risky (25%) (-5 points)'),
      );
    });

    test('recovers when the next scan no longer exposes the service', () async {
      await seedScan(1, openPorts: '23');
      final flagged = await service.computeScore();
      expect(flagged.vulnerabilities.value, lessThan(100));

      await seedScan(
        1,
        scanId: 2,
        startTime: DateTime(2026, 1, 2, 10),
      );
      final resolved = await service.computeScore();

      expect(resolved.vulnerabilities.value, 100);
      expect(
        resolved.vulnerabilities.factors
            .where((factor) => factor.contains('Telnet')),
        isEmpty,
      );
    });

    test('scores the analysis handed in by the caller', () async {
      await seedScan(1, openPorts: '23');

      final score = await service.computeScore(
        scanAnalysis: const NetworkScanAnalysis(
          deviceCount: 1,
          unidentifiedDeviceCount: 0,
          untrustedDeviceCount: 0,
          exposedServiceCount: 0,
          findings: [],
        ),
      );

      expect(score.vulnerabilities.value, 100);
      expect(
        score.vulnerabilities.factors
            .where((factor) => factor.contains('Telnet')),
        isEmpty,
      );
    });

    test('names the device-trust counts behind the Security deduction',
        () async {
      final devices = await seedScan(2);
      await trustService.setTrusted(devices.first, false);

      final score = await service.computeScore();

      expect(score.security.value, 95);
      expect(
        score.vulnerabilities.factors,
        contains('~ Device trust: 1 untrusted, 0 unidentified device(s)'),
      );
    });

    test('says so when no scan has finished', () async {
      final score = await service.computeScore();

      expect(score.vulnerabilities.value, 50);
      expect(
        score.vulnerabilities.factors,
        contains('✗ No network scan found (-50 points)'),
      );
    });
  });
}
