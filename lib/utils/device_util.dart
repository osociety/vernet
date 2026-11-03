import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vernet/database/drift/drift_database.dart';

class DeviceUtil {
  static bool _isLikelyNetworkService(String? name) {
    final normalizedName = (name ?? '').toLowerCase();
    return normalizedName.contains('dhcp') ||
        normalizedName.contains('dns') ||
        normalizedName.contains('bind') ||
        normalizedName.contains('dnsmasq') ||
        normalizedName.contains('named');
  }

  static String? getDeviceMake(DeviceData deviceData) {
    // Return the actual device name, not "This device" label.
    // The UI can use isCurrentDevice() to add a visual indicator.
    if (deviceData.gatewayIp == deviceData.internetAddress &&
        !_isLikelyNetworkService(deviceData.hostMake)) {
      return 'Router/Gateway';
    } else if (deviceData.mdnsDomainName != null) {
      return deviceData.mdnsDomainName;
    }
    return deviceData.hostMake;
  }

  /// Returns true if this device is the one running the app.
  static bool isCurrentDevice(DeviceData deviceData) {
    return deviceData.currentDeviceIp == deviceData.internetAddress;
  }

  static IconData getIconData(DeviceData deviceData) {
    if (deviceData.internetAddress == deviceData.currentDeviceIp) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icons.computer;
      }
      return Icons.smartphone;
    } else if (deviceData.internetAddress == deviceData.gatewayIp &&
        !_isLikelyNetworkService(deviceData.hostMake)) {
      return Icons.router;
    }
    return Icons.devices;
  }

  /// Octet-wise IPv4/IPv6 order, so 192.168.1.10 sorts after 192.168.1.2.
  /// Unparseable addresses fall back to string comparison.
  static int compareIpAddresses(String leftAddress, String rightAddress) {
    final left = InternetAddress.tryParse(leftAddress);
    final right = InternetAddress.tryParse(rightAddress);
    if (left == null || right == null) {
      return leftAddress.compareTo(rightAddress);
    }
    if (left.type != right.type) {
      return left.type == InternetAddressType.IPv4 ? -1 : 1;
    }

    final leftBytes = left.rawAddress;
    final rightBytes = right.rawAddress;
    for (var index = 0; index < leftBytes.length; index++) {
      final comparison = leftBytes[index].compareTo(rightBytes[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
