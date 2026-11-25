import 'package:injectable/injectable.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/utils/device_util.dart';

/// Records the devices scans discover and answers whether they are trusted.
///
/// Trust belongs to the device, not to the scan row that found it: the same
/// phone keeps its decision after the next scan writes a new row for it. A
/// device that turns up under a MAC after an address-only sighting keeps its
/// row, and the decision on it, by moving to the MAC key.
@Injectable()
class DeviceTrustService {
  DeviceTrustService(this._repository);
  final KnownDeviceRepository _repository;

  Stream<List<KnownDeviceData>> watchAll() => _repository.watchAll();

  Future<List<KnownDeviceData>> getAll() => _repository.getAll();

  /// The registry row describing [device], or null when it has never been
  /// recorded. A MAC row wins over an address row for the same device.
  static KnownDeviceData? knownDeviceFor(
    List<KnownDeviceData> knownDevices,
    DeviceData device,
  ) {
    for (final key in DeviceUtil.deviceKeys(device)) {
      for (final row in knownDevices) {
        if (row.deviceKey == key) return row;
      }
    }
    return null;
  }

  static bool isTrusted(
    List<KnownDeviceData> knownDevices,
    DeviceData device,
  ) =>
      knownDeviceFor(knownDevices, device)?.trusted ?? false;

  /// Records [devices] from a finished scan and returns the untrusted arrivals.
  ///
  /// The first scan after this feature ships establishes the trusted baseline,
  /// so the network the user already lives on is not reported as intruders.
  /// After that, a device is returned only the first time it is seen; a
  /// device whose trust was revoked stays quiet because its row is kept.
  /// With [trustNewDevices] every arrival is trusted on sight, which keeps the
  /// registry current without ever reporting a device.
  Future<List<DeviceData>> evaluateScan({
    required List<DeviceData> devices,
    required bool trustNewDevices,
    int? scanId,
    DateTime? seenAt,
  }) async {
    if (devices.isEmpty) return const [];
    final stamp = seenAt ?? DateTime.now();
    final existing = await _repository.getAll();
    // Only the first scan in the app's life is the baseline; a registry the
    // user emptied by forgetting everything must not trust the next scan.
    final baseline = existing.isEmpty && !appSettings.trustBaselineEstablished;
    final knownKeys = {for (final row in existing) row.deviceKey};
    final newDevices = <DeviceData>[];

    for (final device in devices) {
      final macKey = DeviceUtil.macDeviceKey(device.macAddress);
      final addressKey = DeviceUtil.addressDeviceKey(device.internetAddress);
      String deviceKey;
      if (macKey != null && knownKeys.contains(macKey)) {
        deviceKey = macKey;
      } else if (knownKeys.contains(addressKey)) {
        if (macKey != null) {
          await _repository.migrateKey(
            addressKey,
            newKey: macKey,
            device: device,
            seenAt: stamp,
            scanId: scanId,
          );
          knownKeys
            ..remove(addressKey)
            ..add(macKey);
          deviceKey = macKey;
        } else {
          deviceKey = addressKey;
        }
      } else {
        deviceKey = macKey ?? addressKey;
        knownKeys.add(deviceKey);
        if (!baseline && !trustNewDevices) newDevices.add(device);
      }
      await _repository.saveSighting(
        device,
        deviceKey: deviceKey,
        trustedWhenNew: baseline || trustNewDevices,
        seenAt: stamp,
        scanId: scanId,
      );
    }
    if (!appSettings.trustBaselineEstablished) {
      await appSettings.setTrustBaselineEstablished(true);
    }
    return newDevices;
  }

  /// Records a finished scan and raises the alert for any untrusted arrivals.
  ///
  /// Callers hand over the whole result rather than the diff: the registry
  /// decides what is new, and it must see every device so the ones carried
  /// over from earlier scans are refreshed instead of reported again.
  Future<void> recordScan(List<DeviceData> devices, {int? scanId}) async {
    final untrusted = await evaluateScan(
      devices: devices,
      trustNewDevices: appSettings.autoTrustNewDevices,
      scanId: scanId,
    );
    if (untrusted.isEmpty || !appSettings.notifyUntrustedDevices) return;
    await NotificationService.showUntrustedDevicesAlert(
      untrusted.map(describeDevice).toList(),
    );
  }

  /// One device as the alert lists it: name, address and hardware address,
  /// skipping whatever the scan could not resolve.
  static String describeDevice(DeviceData device) {
    final name = DeviceUtil.getDeviceMake(device);
    final parts = [
      if (name != null && name.isNotEmpty) name,
      device.internetAddress,
      if (device.macAddress != null && device.macAddress!.isNotEmpty)
        device.macAddress!,
    ];
    return parts.join(' · ');
  }

  /// Marks [device] trusted or untrusted, creating its row when no scan has
  /// recorded it yet.
  Future<void> setTrusted(
    DeviceData device,
    bool trusted, {
    DateTime? seenAt,
  }) async {
    final stamp = seenAt ?? DateTime.now();
    final macKey = DeviceUtil.macDeviceKey(device.macAddress);
    final addressKey = DeviceUtil.addressDeviceKey(device.internetAddress);
    var key = macKey ?? addressKey;

    if (macKey == null || await _repository.getByKey(macKey) == null) {
      if (await _repository.getByKey(addressKey) != null) {
        if (macKey != null) {
          await _repository.migrateKey(
            addressKey,
            newKey: macKey,
            device: device,
            seenAt: stamp,
          );
          key = macKey;
        } else {
          key = addressKey;
        }
      }
    }

    await _repository.saveSighting(
      device,
      deviceKey: key,
      trustedWhenNew: trusted,
      seenAt: stamp,
    );
    await _repository.setTrusted(key, trusted, seenAt: stamp);
  }

  Future<void> setTrustedForKey(
    String deviceKey,
    bool trusted, {
    DateTime? seenAt,
  }) =>
      _repository.setTrusted(deviceKey, trusted, seenAt: seenAt);

  /// Removes the row, so the device is reported as new the next time it is
  /// seen. The caller confirms first: forgetting loses the decision.
  Future<void> forget(String deviceKey) => _repository.forget(deviceKey);

  Future<void> addTrustedMac(
    String mac, {
    String? label,
    DateTime? seenAt,
  }) =>
      _repository.addTrustedMac(mac, label: label, seenAt: seenAt);
}
