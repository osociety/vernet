import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KnownDeviceRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repository = KnownDeviceRepository(_InMemoryDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  DeviceData device({
    int id = 1,
    String address = '192.168.0.5',
    String? mac = '00:03:93:AA:BB:CC',
    String? hostMake,
  }) =>
      DeviceData(
        id: id,
        internetAddress: address,
        macAddress: mac,
        hostMake: hostMake,
        currentDeviceIp: '192.168.0.100',
        gatewayIp: '192.168.0.1',
        scanId: 7,
      );

  test('saveSighting stores the normalized MAC and the vendor label', () async {
    await repository.saveSighting(
      device(hostMake: 'Living Room TV'),
      deviceKey: 'mac:00:03:93:aa:bb:cc',
      trustedWhenNew: true,
      seenAt: DateTime(2024, 5),
      scanId: 7,
    );

    final stored = await repository.getByKey('mac:00:03:93:aa:bb:cc');
    expect(stored, isNotNull);
    expect(stored!.macAddress, '00:03:93:aa:bb:cc');
    expect(stored.lastAddress, '192.168.0.5');
    expect(stored.label, 'Living Room TV');
    expect(stored.trusted, isTrue);
    expect(stored.lastScanId, 7);
  });

  test('saveSighting keeps the trust decision and first sighting', () async {
    await repository.saveSighting(
      device(),
      deviceKey: 'mac:00:03:93:aa:bb:cc',
      trustedWhenNew: true,
      seenAt: DateTime(2024, 5),
    );
    await repository.setTrusted('mac:00:03:93:aa:bb:cc', false);

    await repository.saveSighting(
      device(address: '192.168.0.9', hostMake: 'Renamed'),
      deviceKey: 'mac:00:03:93:aa:bb:cc',
      trustedWhenNew: true,
      seenAt: DateTime(2024, 5, 2),
    );

    final stored = await repository.getByKey('mac:00:03:93:aa:bb:cc');
    expect(stored!.trusted, isFalse);
    expect(stored.firstSeenAt, DateTime(2024, 5));
    expect(stored.lastSeenAt, DateTime(2024, 5, 2));
    expect(stored.lastAddress, '192.168.0.9');
    expect(stored.label, 'Renamed');
  });

  test('migrateKey moves the decision to the MAC key', () async {
    await repository.saveSighting(
      device(mac: null),
      deviceKey: 'ip:192.168.0.5',
      trustedWhenNew: false,
      seenAt: DateTime(2024, 5),
    );

    await repository.migrateKey(
      'ip:192.168.0.5',
      newKey: 'mac:00:03:93:aa:bb:cc',
      device: device(),
      seenAt: DateTime(2024, 5, 2),
    );

    expect(await repository.getByKey('ip:192.168.0.5'), isNull);
    final moved = await repository.getByKey('mac:00:03:93:aa:bb:cc');
    expect(moved, isNotNull);
    expect(moved!.trusted, isFalse);
    expect(moved.macAddress, '00:03:93:aa:bb:cc');
  });

  test('addTrustedMac rejects values that are not hardware addresses', () {
    expect(
      () => repository.addTrustedMac('not-a-mac'),
      throwsArgumentError,
    );
  });

  test('addTrustedMac stores a trusted row before any scan sees it', () async {
    await repository.addTrustedMac(
      '00-1A-2B-3C-4D-5E',
      label: 'Garage camera',
      seenAt: DateTime(2024, 5),
    );

    final stored = await repository.getByKey('mac:00:1a:2b:3c:4d:5e');
    expect(stored, isNotNull);
    expect(stored!.trusted, isTrue);
    expect(stored.label, 'Garage camera');
    expect(stored.lastAddress, '');
  });

  test('forget removes the row', () async {
    await repository.addTrustedMac('00:1A:2B:3C:4D:5E');
    await repository.forget('mac:00:1a:2b:3c:4d:5e');

    expect(await repository.getByKey('mac:00:1a:2b:3c:4d:5e'), isNull);
  });

  test('getAll orders the most recently seen device first', () async {
    await repository.addTrustedMac(
      '00:1A:2B:3C:4D:5E',
      seenAt: DateTime(2024, 5),
    );
    await repository.addTrustedMac(
      '00:1A:2B:3C:4D:5F',
      seenAt: DateTime(2024, 5, 3),
    );

    final all = await repository.getAll();
    expect(all.map((row) => row.macAddress), [
      '00:1a:2b:3c:4d:5f',
      '00:1a:2b:3c:4d:5e',
    ]);
  });
}
