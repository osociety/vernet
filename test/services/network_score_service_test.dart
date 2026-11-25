import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
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

  /// One finished scan carrying [count] devices that all have a MAC and a
  /// name, so the unidentified-device deduction stays out of the way.
  Future<List<DeviceData>> seedScan(int count) async {
    await scanRepository.put(
      ScanData(
        id: 1,
        gatewayIp: '192.168.1',
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 10, 0, 30),
        onGoing: false,
      ),
    );
    final devices = [
      for (var i = 0; i < count; i++)
        DeviceData(
          id: i + 1,
          scanId: 1,
          internetAddress: '192.168.1.${10 + i}',
          currentDeviceIp: '192.168.1.5',
          gatewayIp: '192.168.1.1',
          macAddress: '00:03:93:AA:BB:${(i + 1).toString().padLeft(2, '0')}',
          hostMake: 'Device ${i + 1}',
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
}
