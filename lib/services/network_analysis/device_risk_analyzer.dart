import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/models/network_finding.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';
import 'package:vernet/utils/device_util.dart';

/// Sorts devices into the risk tiers the device cards show.
///
/// Pure: callers pass the findings and the presence history they already have,
/// so the same assessment works on a live scan row and on a stored report row.
class DeviceRiskAnalyzer {
  const DeviceRiskAnalyzer._();

  /// Minimum number of scans a device had to miss before its history counts as
  /// intermittent, and the share of the span those misses have to reach.
  ///
  /// A device seen in two of four scans is flagged; one seen in three of five
  /// is not. Both thresholds exist so a device added halfway through the
  /// history or seen once does not look suspicious.
  static const int minimumMissedScans = 2;

  static DeviceRiskAssessment assess(
    DeviceData device, {
    required List<NetworkFinding> findings,
    bool appearsIntermittently = false,
  }) {
    final reasons = <DeviceRiskReason>{};
    var level = DeviceRiskLevel.low;

    void raise(DeviceRiskLevel candidate, DeviceRiskReason reason) {
      if (candidate.index > level.index) level = candidate;
      reasons.add(reason);
    }

    if (findings
        .any((finding) => finding.severity != NetworkFindingSeverity.info)) {
      raise(DeviceRiskLevel.high, DeviceRiskReason.vulnerableService);
    } else if (findings.isNotEmpty) {
      raise(DeviceRiskLevel.medium, DeviceRiskReason.unusualPorts);
    }

    if (_hasUnusualPorts(device.openPorts)) {
      raise(DeviceRiskLevel.medium, DeviceRiskReason.unusualPorts);
    }

    if (!hasKnownDeviceType(device)) {
      raise(DeviceRiskLevel.medium, DeviceRiskReason.unknownDeviceType);
    }

    if (hasUnrecognizedVendor(device)) {
      raise(DeviceRiskLevel.high, DeviceRiskReason.unknownVendor);
    }

    if (appearsIntermittently) {
      raise(DeviceRiskLevel.high, DeviceRiskReason.intermittentPresence);
    }

    return DeviceRiskAssessment(
      level: level,
      reasons: DeviceRiskReason.values
          .where((reason) => reasons.contains(reason))
          .toList(),
    );
  }

  /// Whether the scan or the port heuristics gave the device a type.
  ///
  /// The router, the gateway and the device running the app are known by
  /// position even when no port scan has inferred anything about them.
  static bool hasKnownDeviceType(DeviceData device) {
    if (DeviceUtil.isCurrentDevice(device)) return true;
    if (device.internetAddress == device.gatewayIp) return true;
    final type = device.deviceType?.trim().toLowerCase();
    return type != null &&
        type.isNotEmpty &&
        type != 'unknown' &&
        type != 'unknown device';
  }

  /// True when a globally administered MAC resolved no vendor.
  ///
  /// Locally administered addresses are left alone: phones and laptops rotate
  /// them on purpose, so an unmatched OUI says nothing about those devices.
  static bool hasUnrecognizedVendor(DeviceData device) {
    final mac = DeviceUtil.normalizedMacAddress(device.macAddress);
    if (mac == null) return false;
    final firstOctet = int.parse(mac.substring(0, 2), radix: 16);
    if (firstOctet & 0x02 != 0) return false;
    return (device.vendorName ?? '').trim().isEmpty;
  }

  /// Ports no local table can place read as unusual rather than standard.
  /// Alternate service numbers are named, and the analyzer reports them as
  /// info findings, so they arrive through the findings branch instead.
  static bool _hasUnusualPorts(String? openPorts) {
    for (final port in PortRiskAnalyzer.parsePorts(openPorts)) {
      final named = DeviceUtil.getPortDescription(port) != null ||
          PortRiskAnalyzer.alternatePorts.containsKey(port) ||
          PortRiskAnalyzer.rules.any((rule) => rule.port == port);
      if (!named) return true;
    }
    return false;
  }
}
