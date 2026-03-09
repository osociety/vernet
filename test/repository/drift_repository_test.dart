import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  // Ensure the services binding is initialized for shared_preferences etc.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeviceRepository deviceRepo;
  late ScanRepository scanRepo;

  setUp(() {
    // Prepare in-memory shared preferences so getCurrentScanId() won't crash.
    SharedPreferences.setMockInitialValues({});

    db = AppDatabase(NativeDatabase.memory());
    final service = _InMemoryDatabaseService(db);
    deviceRepo = DeviceRepository(service);
    scanRepo = ScanRepository(service);
  });

  tearDown(() async {
    await db.close();
  });

  group('DeviceRepository additional tests', () {
    test('get returns null for non-existent device', () async {
      final result = await deviceRepo.get(999999);
      expect(result, isNull);
    });

    test('getDevice returns null for non-existent device', () async {
      final scan = await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      final result = await deviceRepo.getDevice(scan.id, '192.168.0.999');
      expect(result, isNull);
    });

    test('watch returns stream of devices for scanId', () async {
      final scan = await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      final device = DeviceData(
        id: DateTime.now().millisecondsSinceEpoch,
        internetAddress: '192.168.0.2',
        macAddress: '00:11:22:33:44:55',
        hostMake: 'UnitTest',
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0.1',
        scanId: scan.id,
      );

      await deviceRepo.put(device);

      final stream = await deviceRepo.watch(scan.id);
      expect(stream, isA<Stream<List<DeviceData>>>());

      final emitted = await stream.first;
      expect(emitted, isNotEmpty);
      expect(emitted.first.internetAddress, '192.168.0.2');
    });

    test('countByScanId returns correct count', () async {
      final scan = await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      // Add multiple devices
      for (int i = 1; i <= 3; i++) {
        final device = DeviceData(
          id: DateTime.now().millisecondsSinceEpoch + i,
          internetAddress: '192.168.0.$i',
          macAddress: '00:11:22:33:44:5$i',
          hostMake: 'UnitTest',
          currentDeviceIp: '192.168.0.10',
          gatewayIp: '192.168.0.1',
          scanId: scan.id,
        );
        await deviceRepo.put(device);
      }

      final count = await deviceRepo.countByScanId(scan.id);
      expect(count, equals(3));
    });

    test('countByScanId returns 0 for non-existent scan', () async {
      final count = await deviceRepo.countByScanId(999999);
      expect(count, equals(0));
    });
  });

  group('ScanRepository additional tests', () {
    test('get returns null for non-existent scan', () async {
      final result = await scanRepo.get(999999);
      expect(result, isNull);
    });

    test('update modifies existing scan', () async {
      final originalScan = await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      final updatedScan = await scanRepo.update(
        ScanData(
          id: originalScan.id,
          gatewayIp: '192.168.0.0',
          startTime: originalScan.startTime,
          onGoing: false,
          endTime: DateTime.now(),
        ),
      );

      expect(updatedScan.onGoing, isFalse);
      expect(updatedScan.endTime, isNotNull);
    });

    test('getOnGoingScan returns null when no ongoing scans', () async {
      final result = await scanRepo.getOnGoingScan();
      expect(result, isNull);
    });

    test('getOnGoingScan returns ongoing scan', () async {
      await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      final result = await scanRepo.getOnGoingScan();
      expect(result, isNotNull);
      expect(result!.onGoing, isTrue);
    });

    test('watch returns stream for scan id', () async {
      final scan = await scanRepo.put(
        ScanData(
          id: DateTime.now().millisecondsSinceEpoch,
          gatewayIp: '192.168.0.0',
          startTime: DateTime.now(),
          onGoing: true,
        ),
      );

      final stream = await scanRepo.watch(scan.id);
      expect(stream, isA<Stream<List<ScanData>>>());

      final emitted = await stream.first;
      expect(emitted, isNotEmpty);
      expect(emitted.first.id, scan.id);
    });
  });
}
