import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:network_tools/network_tools.dart';

/// Contains all the information of a device in the network including
/// icon, open ports and in the future host name and mDNS name
class DeviceInTheNetwork {
  /// Create basic device with default (not the correct) icon
  DeviceInTheNetwork({
    required this.hostDeviceIp,
    required this.pingData,
    this.hostId,
    this.mac,
    this.hostName,
    this.mdnsInfo,
    this.vendor,
  });

  /// Create the object from active host with the correct field and icon
  factory DeviceInTheNetwork.createFromActiveHost({
    required ActiveHost activeHost,
  }) {
    return DeviceInTheNetwork(
      hostDeviceIp: activeHost.address,
      hostId: activeHost.hostId,
      pingData: activeHost.pingData,
      hostName: activeHost.hostName,
      mdnsInfo: activeHost.mdnsInfo,
    );
  }

  /// Ip of the device in that object
  final String hostDeviceIp;
  static const String defaultName = 'Generic Device';

  /// Mac address of the device
  String? mac;
  final PingData pingData;
  String? hostId;
  Future<String?>? hostName;
  Future<MdnsInfo?>? mdnsInfo;
  Future<String?>? vendor;

  Future<String> getDeviceName({
    String? hostIp,
    String? gatewayIp,
  }) async {
    if (hostIp == hostDeviceIp) {
      return 'This device';
    } else if (gatewayIp == hostDeviceIp) {
      return 'Router/Gateway';
    }

    if (hostName != null && await hostName != null) {
      return (await hostName!)!;
    }

    if (mdnsInfo != null && await mdnsInfo != null) {
      return (await mdnsInfo!)!.getOnlyTheStartOfMdnsName();
    }

    if (vendor != null && await vendor != null) {
      return (await vendor!)!;
    }

    return defaultName;
  }

  /// Getting the host icon, will choose between saved icon based on os,
  /// current device, is gateway IP and more.
  IconData getHostIcon({
    String? hostIp,
    String? gatewayIp,
  }) {
    if (hostIp == hostDeviceIp) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icons.computer;
      }
      return Icons.smartphone;
    } else if (gatewayIp == hostDeviceIp) {
      return Icons.router;
    }
    return Icons.devices;
  }
}
