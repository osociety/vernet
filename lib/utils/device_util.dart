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
    if (deviceData.currentDeviceIp == deviceData.internetAddress) {
      return 'This device';
    } else if (deviceData.gatewayIp == deviceData.internetAddress &&
        !_isLikelyNetworkService(deviceData.hostMake)) {
      return 'Router/Gateway';
    } else if (deviceData.mdnsDomainName != null) {
      return deviceData.mdnsDomainName;
    }
    return deviceData.hostMake;
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
}
