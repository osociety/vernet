import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'device.g.dart';

@collection
class Device {
  Device({
    required this.internetAddress,
    required this.hostMake,
    required this.currentDeviceIp,
    required this.gatewayIp,
    required this.scanId,
    this.mdnsDomainName,
    this.macAddress,
  });
  final Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  final int scanId;
  @Index(type: IndexType.value)
  final String internetAddress;
  final String currentDeviceIp;
  final String gatewayIp;
  final String? macAddress;
  final String? hostMake;
  final String? mdnsDomainName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          internetAddress == other.internetAddress;

  @override
  int get hashCode => internetAddress.hashCode;

  @ignore
  String? get deviceMake {
    if (currentDeviceIp == internetAddress) {
      return 'This device';
    } else if (gatewayIp == internetAddress) {
      return 'Router/Gateway';
    } else if (mdnsDomainName != null) {
      return mdnsDomainName;
    }
    return hostMake;
  }

  @ignore
  IconData get iconData {
    if (internetAddress == currentDeviceIp) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icons.computer;
      }
      return Icons.smartphone;
    } else if (internetAddress == gatewayIp) {
      return Icons.router;
    }
    return Icons.devices;
  }
}
