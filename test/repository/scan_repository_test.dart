import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/drift/scan_repository.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScanRepository scanRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final service = _InMemoryDatabaseService(db);
    scanRepo = ScanRepository(service);
  });

  tearDown(() async {
    await db.close();
  });

  test('ScanRepository put/get/getOnGoingScan works', () async {
    final scan = await scanRepo.put(
      ScanData(
        id: DateTime.now().millisecondsSinceEpoch,
        gatewayIp: '10.0.0.0',
        startTime: DateTime.now(),
        onGoing: true,
      ),
    );

    final fetched = await scanRepo.get(scan.id);
    expect(fetched, isNotNull);

    final ongoing = await scanRepo.getOnGoingScan();
    expect(ongoing != null, isTrue);
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
