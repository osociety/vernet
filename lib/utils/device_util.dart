import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vernet/database/drift/drift_database.dart';

class DeviceUtil {
  static String? getDeviceMake(DeviceData deviceData) {
    if (deviceData.currentDeviceIp == deviceData.internetAddress) {
      return 'This device';
    } else if (deviceData.gatewayIp == deviceData.internetAddress) {
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
    } else if (deviceData.internetAddress == deviceData.gatewayIp) {
      return Icons.router;
    }
    return Icons.devices;
  }
}
