import 'package:vernet/database/drift/drift_database.dart';

/// One cell of the device-distribution strip: the host id (last IPv4 octet, 1..254)
/// and the device found there, if any (#36).
class DistributionBlock {
  const DistributionBlock({required this.hostId, this.device});

  /// Last octet of the address, 1..254.
  final int hostId;

  /// The device found at this address, or null when the scan found nothing there.
  final DeviceData? device;

  bool get isFound => device != null;
}

/// Maps a scan result onto the 254 host addresses of the scanned subnet, so the UI can draw
/// one colored block per address — first block is .1, last is .254 (#36).
class DeviceDistribution {
  DeviceDistribution._({required this.subnetPrefix, required this.blocks});

  factory DeviceDistribution.fromDevices(List<DeviceData> devices) {
    final prefix = _subnetPrefixOf(devices);
    final byHostId = <int, DeviceData>{};
    for (final device in devices) {
      final hostId = _lastOctet(device.internetAddress);
      if (hostId != null && hostId >= firstHostId && hostId <= lastHostId) {
        byHostId[hostId] = device;
      }
    }
    return DeviceDistribution._(
      subnetPrefix: prefix ?? '',
      blocks: [
        for (var hostId = firstHostId; hostId <= lastHostId; hostId++)
          DistributionBlock(hostId: hostId, device: byHostId[hostId]),
      ],
    );
  }

  static const int firstHostId = 1;
  static const int lastHostId = 254;
  static const int blockCount = lastHostId - firstHostId + 1;

  /// The scanned subnet without the last octet, e.g. `192.168.1`.
  final String subnetPrefix;

  /// 254 blocks, index 0 is host id 1.
  final List<DistributionBlock> blocks;

  /// The block for a host id; ids outside 1..254 map to the nearest edge block.
  DistributionBlock blockFor(int hostId) {
    final clamped = hostId.clamp(firstHostId, lastHostId);
    return blocks[clamped - firstHostId];
  }

  /// The full address of a host id in the scanned subnet, e.g. `192.168.1.42`.
  String addressOf(int hostId) => '$subnetPrefix.$hostId';

  /// The devices the scan found, ordered by host id.
  List<DeviceData> get foundDevices => [
        for (final block in blocks)
          if (block.isFound) block.device!,
      ];

  /// How many of the 254 addresses have a device.
  int get foundCount => blocks.where((block) => block.isFound).length;

  static String? _subnetPrefixOf(List<DeviceData> devices) {
    for (final device in devices) {
      final prefix = _prefixOf(device.internetAddress);
      if (prefix != null) return prefix;
    }
    return null;
  }

  static String? _prefixOf(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static int? _lastOctet(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return int.tryParse(parts[3]);
  }
}
