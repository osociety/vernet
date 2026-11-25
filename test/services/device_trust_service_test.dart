import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/values/globals.dart' as globals;

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
  late DeviceTrustService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appSettings.resetForTesting();
    globals.testingActive = true;
    db = AppDatabase(NativeDatabase.memory());
    repository = KnownDeviceRepository(_InMemoryDatabaseService(db));
    service = DeviceTrustService(repository);
  });

  tearDown(() async {
    globals.testingActive = false;
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

  group('evaluateScan', () {
    test('trusts the first scan as the baseline and reports nothing', () async {
      final untrusted = await service.evaluateScan(
        devices: [
          device(),
          device(id: 2, address: '192.168.0.6', mac: '00:03:93:AA:BB:DD'),
        ],
        trustNewDevices: false,
      );

      expect(untrusted, isEmpty);
      final rows = await repository.getAll();
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.trusted), isTrue);
    });

    test('returns only the device that is new after the baseline', () async {
      await service.evaluateScan(
        devices: [device()],
        trustNewDevices: false,
      );

      final newDevice = device(
        id: 2,
        address: '192.168.0.6',
        mac: '00:03:93:AA:BB:DD',
        hostMake: 'Laptop',
      );
      final untrusted = await service.evaluateScan(
        devices: [device(), newDevice],
        trustNewDevices: false,
      );

      expect(untrusted.map((d) => d.internetAddress), ['192.168.0.6']);
      final stored = await repository.getByKey('mac:00:03:93:aa:bb:dd');
      expect(stored!.trusted, isFalse);
    });

    test('reports a new device only once', () async {
      await service.evaluateScan(
        devices: [device()],
        trustNewDevices: false,
      );
      final newDevice = device(id: 2, mac: '00:03:93:AA:BB:DD');

      expect(
        await service.evaluateScan(
          devices: [newDevice],
          trustNewDevices: false,
        ),
        hasLength(1),
      );
      expect(
        await service.evaluateScan(
          devices: [newDevice],
          trustNewDevices: false,
        ),
        isEmpty,
      );
    });

    test('trustNewDevices records arrivals as trusted and never reports',
        () async {
      await service.evaluateScan(
        devices: [device()],
        trustNewDevices: false,
      );

      final untrusted = await service.evaluateScan(
        devices: [device(id: 2, mac: '00:03:93:AA:BB:DD')],
        trustNewDevices: true,
      );

      expect(untrusted, isEmpty);
      final stored = await repository.getByKey('mac:00:03:93:aa:bb:dd');
      expect(stored!.trusted, isTrue);
    });

    test('moves an address-keyed row to the MAC without reporting it',
        () async {
      await service.evaluateScan(
        devices: [device(mac: null)],
        trustNewDevices: false,
      );
      await service.setTrusted(device(mac: null), false);

      final untrusted = await service.evaluateScan(
        devices: [device(id: 2)],
        trustNewDevices: false,
      );

      expect(untrusted, isEmpty);
      expect(await repository.getByKey('ip:192.168.0.5'), isNull);
      final moved = await repository.getByKey('mac:00:03:93:aa:bb:cc');
      expect(moved!.trusted, isFalse);
    });

    test('a revoked device stays quiet on later scans', () async {
      await service.evaluateScan(
        devices: [device()],
        trustNewDevices: false,
      );
      await service.setTrusted(device(), false);

      expect(
        await service.evaluateScan(
          devices: [device(id: 2)],
          trustNewDevices: false,
        ),
        isEmpty,
      );
      final stored = await repository.getByKey('mac:00:03:93:aa:bb:cc');
      expect(stored!.trusted, isFalse);
    });

    test('a manually trusted MAC is not reported when a scan finds it',
        () async {
      await service.evaluateScan(
        devices: [device(mac: '00:03:93:AA:BB:01')],
        trustNewDevices: false,
      );
      await service.addTrustedMac('00:03:93:AA:BB:CC');

      expect(
        await service.evaluateScan(
          devices: [device(id: 2)],
          trustNewDevices: false,
        ),
        isEmpty,
      );
      final stored = await repository.getByKey('mac:00:03:93:aa:bb:cc');
      expect(stored!.trusted, isTrue);
      expect(stored.lastAddress, '192.168.0.5');
    });
  });

  group('setTrusted', () {
    test('creates a row for a device the registry has never seen', () async {
      final unknown = device(id: 9);
      expect(
        DeviceTrustService.isTrusted(await repository.getAll(), unknown),
        isFalse,
      );

      await service.setTrusted(unknown, true);

      final rows = await repository.getAll();
      expect(DeviceTrustService.isTrusted(rows, unknown), isTrue);
      expect(
        DeviceTrustService.knownDeviceFor(rows, unknown)!.trusted,
        isTrue,
      );
    });

    test('forget makes the next scan treat the device as new', () async {
      await service.evaluateScan(
        devices: [device()],
        trustNewDevices: false,
      );

      await service.forget('mac:00:03:93:aa:bb:cc');

      expect(
        await service.evaluateScan(
          devices: [device(id: 2)],
          trustNewDevices: false,
        ),
        hasLength(1),
      );
    });
  });

  test('recordScan reads the auto-trust setting', () async {
    await service.evaluateScan(
      devices: [device()],
      trustNewDevices: false,
    );
    await appSettings.setAutoTrustNewDevices(true);

    await service.recordScan([device(id: 2, mac: '00:03:93:AA:BB:DD')]);

    final stored = await repository.getByKey('mac:00:03:93:aa:bb:dd');
    expect(stored!.trusted, isTrue);
  });

  test('describeDevice names the device with its address and MAC', () {
    expect(
      DeviceTrustService.describeDevice(
        device(hostMake: 'Living Room TV'),
      ),
      'Living Room TV · 192.168.0.5 · 00:03:93:AA:BB:CC',
    );
    expect(
      DeviceTrustService.describeDevice(device(mac: null)),
      '192.168.0.5',
    );
  });
}
