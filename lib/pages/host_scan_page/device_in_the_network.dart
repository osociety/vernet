import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Contains all the information of a device in the network including
/// icon, open ports and in the future host name and mDNS name
class DeviceInTheNetwork {
  /// Create basic device with default (not the correct) icon
  DeviceInTheNetwork({
    required this.internetAddress,
    required Future<String?> makeVar,
    required this.pingData,
    MdnsInfo? mdnsVar,
    String? mac,
    this.iconData = Icons.devices,
    this.hostId,
  }) {
    make = makeVar;
    _mdns = mdnsVar;
    _mac = mac;
  }

  /// Create the object from active host with the correct field and icon
  factory DeviceInTheNetwork.createFromActiveHost({
    required ActiveHost activeHost,
    required String currentDeviceIp,
    required String gatewayIp,
    required String? mac,
    MdnsInfo? mdns,
  }) {
    return DeviceInTheNetwork.createWithAllNecessaryFields(
      internetAddress: activeHost.internetAddress,
      hostId: activeHost.hostId,
      make: activeHost.deviceName,
      pingData: activeHost.pingData,
      currentDeviceIp: currentDeviceIp,
      gatewayIp: gatewayIp,
      mdns: mdns,
      mac: mac,
    );
  }

  /// Create the object with the correct field and icon
  factory DeviceInTheNetwork.createWithAllNecessaryFields({
    required InternetAddress internetAddress,
    required String hostId,
    required Future<String?> make,
    required PingData pingData,
    required String currentDeviceIp,
    required String gatewayIp,
    required MdnsInfo? mdns,
    required String? mac,
  }) {
    final IconData iconData = getHostIcon(
      currentDeviceIp: currentDeviceIp,
      hostIp: internetAddress.address,
      gatewayIp: gatewayIp,
    );

    final Future<String?> deviceMake = getDeviceMake(
      currentDeviceIp: currentDeviceIp,
      hostIp: internetAddress.address,
      gatewayIp: gatewayIp,
      hostMake: make,
      mdns: mdns,
    );

    return DeviceInTheNetwork(
      internetAddress: internetAddress,
      makeVar: deviceMake,
      pingData: pingData,
      hostId: hostId,
      iconData: iconData,
      mdnsVar: mdns,
      mac: mac,
    );
  }

  /// Ip of the device
  final InternetAddress internetAddress;
  late Future<String?> make;
  String? _mac;

  final PingData pingData;
  final IconData iconData;
  MdnsInfo? _mdns;

  MdnsInfo? get mdns {
    return _mdns;
  }

  String get mac => _mac == null ? '' : '($_mac)';

  set mdns(MdnsInfo? name) {
    _mdns = name;

    final Future<String?> deviceMake = getDeviceMake(
      currentDeviceIp: '',
      hostIp: internetAddress.address,
      gatewayIp: '',
      hostMake: make,
      mdns: _mdns,
    );
    make = deviceMake;
  }

  /// Some name to show the user
  String? hostId;

  static Future<String?> getDeviceMake({
    required String currentDeviceIp,
    required String hostIp,
    required String gatewayIp,
    required Future<String?> hostMake,
    required MdnsInfo? mdns,
  }) {
    if (currentDeviceIp == hostIp) {
      return Future.value('This device');
    } else if (gatewayIp == hostIp) {
      return Future.value('Router/Gateway');
    } else if (mdns != null) {
      return Future.value(mdns.mdnsDomainName);
    }
    return hostMake;
  }

  static IconData getHostIcon({
    required String currentDeviceIp,
    required String hostIp,
    required String gatewayIp,
  }) {
    if (hostIp == currentDeviceIp) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icons.computer;
      }
      return Icons.smartphone;
    } else if (hostIp == gatewayIp) {
      return Icons.router;
    }
    return Icons.devices;
  }
}
