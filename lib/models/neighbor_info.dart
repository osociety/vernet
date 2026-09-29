/// How a neighbor advertisement was obtained.
enum NeighborProtocol { cdp, lldp }

/// Identity of the switch that was queried.
class SwitchIdentity {
  const SwitchIdentity({
    required this.ip,
    this.sysName,
    this.sysDescr,
  });

  final String ip;
  final String? sysName;
  final String? sysDescr;

  String get displayName {
    final name = sysName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return ip;
  }
}

/// A CDP or LLDP neighbor: the remote device and the local switch port it uses.
class NeighborInfo {
  const NeighborInfo({
    required this.protocol,
    this.deviceId,
    this.sysName,
    this.managementIp,
    this.localPort,
    this.remotePort,
    this.platform,
    this.vlan,
    this.speedDuplex,
    this.capabilities,
  });

  final NeighborProtocol protocol;
  final String? deviceId;
  final String? sysName;
  final String? managementIp;
  final String? localPort;
  final String? remotePort;
  final String? platform;
  final String? vlan;
  final String? speedDuplex;
  final String? capabilities;

  String get hostname {
    final name = sysName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = deviceId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return 'Unknown device';
  }

  NeighborInfo copyWith({
    NeighborProtocol? protocol,
    String? deviceId,
    String? sysName,
    String? managementIp,
    String? localPort,
    String? remotePort,
    String? platform,
    String? vlan,
    String? speedDuplex,
    String? capabilities,
  }) {
    return NeighborInfo(
      protocol: protocol ?? this.protocol,
      deviceId: deviceId ?? this.deviceId,
      sysName: sysName ?? this.sysName,
      managementIp: managementIp ?? this.managementIp,
      localPort: localPort ?? this.localPort,
      remotePort: remotePort ?? this.remotePort,
      platform: platform ?? this.platform,
      vlan: vlan ?? this.vlan,
      speedDuplex: speedDuplex ?? this.speedDuplex,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

class NeighborDiscoveryResult {
  const NeighborDiscoveryResult({
    required this.switchInfo,
    required this.neighbors,
    this.warnings = const [],
  });

  final SwitchIdentity switchInfo;
  final List<NeighborInfo> neighbors;
  final List<String> warnings;
}
