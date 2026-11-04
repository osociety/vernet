import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/repository.dart';
import 'package:vernet/utils/device_util.dart';

@Injectable()
class DeviceRepository extends Repository<DeviceData> {
  DeviceRepository(this._database);
  final DatabaseService<AppDatabase> _database;

  Future<DeviceData?> get(int id) async {
    final database = await _database.open();
    return await (database!.select(database.device)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<DeviceData>> getList() async {
    final database = await _database.open();
    return await database!.select(database.device).get();
  }

  @override
  Future<DeviceData> put(DeviceData t) async {
    final database = await _database.open();
    final id =
        await database!.into(database.device).insert(t.toCompanion(true));
    return await (database.select(database.device)
          ..where((dd) => dd.id.equals(id)))
        .getSingle();
  }

  Future<void> update(DeviceData device) async {
    final database = await _database.open();
    await database!.update(database.device).replace(device);
  }

  Future<DeviceData?> getDevice(int scanId, String address) async {
    final database = await _database.open();
    return await (database!.select(database.device)
          ..where((dd) => dd.internetAddress.equals(address))
          ..where((dd) => dd.scanId.equals(scanId)))
        .getSingleOrNull();
  }

  /// Inserts a new device or updates an existing one with the same IP and scanId.
  /// Returns the inserted/updated device.
  Future<DeviceData> upsertByAddress(DeviceData device) async {
    final database = await _database.open();
    final existing = await getDevice(device.scanId, device.internetAddress);

    if (existing != null) {
      // Update existing device, preserving the original ID
      final updated = DeviceData(
        id: existing.id,
        internetAddress: device.internetAddress,
        macAddress: device.macAddress ?? existing.macAddress,
        hostMake: device.hostMake ?? existing.hostMake,
        mdnsDomainName: device.mdnsDomainName ?? existing.mdnsDomainName,
        currentDeviceIp: device.currentDeviceIp,
        gatewayIp: device.gatewayIp,
        scanId: device.scanId,
        deviceType: device.deviceType ?? existing.deviceType,
        openPorts: device.openPorts ?? existing.openPorts,
      );
      await database!.update(database.device).replace(updated);
      return updated;
    } else {
      // Insert new device
      final id = await database!
          .into(database.device)
          .insert(device.toCompanion(true));
      return await (database.select(database.device)
            ..where((dd) => dd.id.equals(id)))
          .getSingle();
    }
  }

  Future<Stream<List<DeviceData>>> watch(int scanId) async {
    final database = await _database.open();
    return (database!.select(database.device)
          ..where((dd) => dd.scanId.equals(scanId)))
        .watch()
        .map(_sortByIpAddress);
  }

  Future<List<DeviceData>> getListForScan(int scanId) async {
    final database = await _database.open();
    final devices = await (database!.select(database.device)
          ..where((dd) => dd.scanId.equals(scanId)))
        .get();
    return _sortByIpAddress(devices);
  }

  Future<int> countByScanId(int scanId) async {
    final database = await _database.open();
    // Use a proper count query on the scanId column and read it as an int.
    final row = await (database!.selectOnly(database.device)
          ..addColumns([
            countAll(filter: database.device.scanId.equals(scanId)),
          ])
          ..where(database.device.scanId.equals(scanId)))
        .getSingle();

    // Read the same count expression we added above.
    final int? count = row.read<int>(
      countAll(filter: database.device.scanId.equals(scanId)),
    );
    return count ?? 0;
  }

  /// Deletes all devices for a given scanId. Used to clean up before starting
  /// a new scan to ensure no duplicates from previous runs.
  Future<void> deleteByScanId(int scanId) async {
    final database = await _database.open();
    await (database!.delete(database.device)
          ..where((dd) => dd.scanId.equals(scanId)))
        .go();
  }
}

List<DeviceData> _sortByIpAddress(List<DeviceData> devices) {
  return List<DeviceData>.of(devices)
    ..sort(
      (a, b) => DeviceUtil.compareIpAddresses(
        a.internetAddress,
        b.internetAddress,
      ),
    );
}
