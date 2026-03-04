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

  test('DeviceRepository put/get/getList/countByScanId works', () async {
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

    final inserted = await deviceRepo.put(device);
    expect(inserted.internetAddress, device.internetAddress);

    final list = await deviceRepo.getList();
    expect(list, isNotEmpty);

    final fetched = await deviceRepo.getDevice(scan.id, device.internetAddress);
    expect(fetched, isNotNull);

    final count = await deviceRepo.countByScanId(scan.id);
    expect(count, greaterThanOrEqualTo(1));
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
    // getOnGoingScan may return the one we created
    expect(ongoing != null, isTrue);
  });
}
