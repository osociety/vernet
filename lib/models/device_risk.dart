/// How risky a discovered device looks, from its identity and open ports.
enum DeviceRiskLevel { low, medium, high }

/// Why [DeviceRiskAssessment.level] is not low, worst reason first.
enum DeviceRiskReason {
  /// A critical or warning finding: a service with known weaknesses.
  vulnerableService,

  /// The MAC is globally administered but no vendor matched its OUI.
  unknownVendor,

  /// The device was absent from many scans while it was known.
  intermittentPresence,

  /// Neither the scan nor the port heuristics inferred a device type.
  unknownDeviceType,

  /// An alternate port number or one the local tables cannot name.
  unusualPorts,
}

class DeviceRiskAssessment {
  const DeviceRiskAssessment({required this.level, required this.reasons});

  final DeviceRiskLevel level;
  final List<DeviceRiskReason> reasons;

  bool get isLow => level == DeviceRiskLevel.low;
}
