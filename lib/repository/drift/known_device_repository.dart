import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/utils/device_util.dart';

/// Storage for the device trust registry.
///
/// The repository keeps the rows in their canonical key form, so callers can
/// pass the raw MAC a device reported and still match an earlier spelling.
@Injectable()
class KnownDeviceRepository {
  KnownDeviceRepository(this._database);
  final DatabaseService<AppDatabase> _database;

  Future<KnownDeviceData?> getByKey(String deviceKey) async {
    final database = await _database.open();
    return await (database!.select(database.knownDevice)
          ..where((row) => row.deviceKey.equals(deviceKey)))
        .getSingleOrNull();
  }

  Future<List<KnownDeviceData>> getAll() async {
    final database = await _database.open();
    return await (database!.select(database.knownDevice)
          ..orderBy([(row) => OrderingTerm.desc(row.lastSeenAt)]))
        .get();
  }

  Stream<List<KnownDeviceData>> watchAll() async* {
    final database = await _database.open();
    yield* (database!.select(database.knownDevice)
          ..orderBy([(row) => OrderingTerm.desc(row.lastSeenAt)]))
        .watch();
  }

  /// Records a sighting of [device] under [deviceKey].
  ///
  /// An existing row keeps its trust decision and first sighting; only the
  /// details a scan can refresh are replaced.
  Future<void> saveSighting(
    DeviceData device, {
    required String deviceKey,
    required bool trustedWhenNew,
    required DateTime seenAt,
    int? scanId,
  }) async {
    final database = await _database.open();
    final existing = await getByKey(deviceKey);
    final label = DeviceUtil.getDeviceMake(device) ?? existing?.label;
    await database!.into(database.knownDevice).insertOnConflictUpdate(
          KnownDeviceCompanion(
            deviceKey: Value(deviceKey),
            macAddress:
                Value(DeviceUtil.normalizedMacAddress(device.macAddress)),
            lastAddress: Value(device.internetAddress),
            label: Value(label),
            trusted: Value(existing?.trusted ?? trustedWhenNew),
            firstSeenAt: Value(existing?.firstSeenAt ?? seenAt),
            lastSeenAt: Value(seenAt),
            lastScanId: Value(scanId ?? existing?.lastScanId),
          ),
        );
  }

  Future<void> setTrusted(
    String deviceKey,
    bool trusted, {
    DateTime? seenAt,
  }) async {
    final database = await _database.open();
    await (database!.update(database.knownDevice)
          ..where((row) => row.deviceKey.equals(deviceKey)))
        .write(
      KnownDeviceCompanion(
        trusted: Value(trusted),
        lastSeenAt: seenAt == null ? const Value.absent() : Value(seenAt),
      ),
    );
  }

  /// Drops the row entirely, so the next scan that finds the device treats it
  /// as new instead of carrying over the old decision.
  Future<void> forget(String deviceKey) async {
    final database = await _database.open();
    await (database!.delete(database.knownDevice)
          ..where((row) => row.deviceKey.equals(deviceKey)))
        .go();
  }

  /// Moves a row from an address key to the MAC key the device now exposes.
  ///
  /// The delete and the insert land in one batch so a failure cannot leave the
  /// device with no row, which the next scan would then report as new.
  Future<void> migrateKey(
    String oldKey, {
    required String newKey,
    required DeviceData device,
    required DateTime seenAt,
    int? scanId,
  }) async {
    final database = await _database.open();
    final existing = await getByKey(oldKey);
    if (existing == null) return;
    final companion = KnownDeviceCompanion(
      deviceKey: Value(newKey),
      macAddress: Value(DeviceUtil.normalizedMacAddress(device.macAddress)),
      lastAddress: Value(device.internetAddress),
      label: Value(DeviceUtil.getDeviceMake(device) ?? existing.label),
      trusted: Value(existing.trusted),
      firstSeenAt: Value(existing.firstSeenAt),
      lastSeenAt: Value(seenAt),
      lastScanId: Value(scanId ?? existing.lastScanId),
    );
    await database!.batch((batch) {
      batch.deleteWhere(
        database.knownDevice,
        (row) => row.deviceKey.equals(oldKey),
      );
      batch.insert(database.knownDevice, companion);
    });
  }

  /// Adds a device by hardware address, before any scan has seen it.
  Future<void> addTrustedMac(
    String mac, {
    String? label,
    DateTime? seenAt,
  }) async {
    final normalized = DeviceUtil.normalizedMacAddress(mac);
    if (normalized == null) {
      throw ArgumentError.value(mac, 'mac', 'Not a MAC address');
    }
    final stamp = seenAt ?? DateTime.now();
    final key = 'mac:$normalized';
    final database = await _database.open();
    final existing = await getByKey(key);
    final trimmedLabel = label?.trim();
    await database!.into(database.knownDevice).insertOnConflictUpdate(
          KnownDeviceCompanion(
            deviceKey: Value(key),
            macAddress: Value(normalized),
            lastAddress: Value(existing?.lastAddress ?? ''),
            label: Value(
              trimmedLabel == null || trimmedLabel.isEmpty
                  ? existing?.label
                  : trimmedLabel,
            ),
            trusted: const Value(true),
            firstSeenAt: Value(existing?.firstSeenAt ?? stamp),
            lastSeenAt: Value(stamp),
            lastScanId: Value(existing?.lastScanId),
          ),
        );
  }
}
