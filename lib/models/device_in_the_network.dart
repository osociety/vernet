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
    required this.currentDeviceIp,
    required this.gatewayIp,
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
    required PingResponse? pingData,
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
      currentDeviceIp: currentDeviceIp,
      gatewayIp: gatewayIp,
      hostId: hostId,
      iconData: iconData,
      mdnsVar: mdns,
      mac: mac,
    );
  }

  /// Ip of the device
  final InternetAddress internetAddress;
  final String currentDeviceIp;
  final String gatewayIp;
  late Future<String?> make;
  String? _mac;

  final PingResponse? pingData;
  final IconData iconData;
  MdnsInfo? _mdns;

  MdnsInfo? get mdns {
    return _mdns;
  }

  String get mac => _mac == null ? '' : '($_mac)';

  set mdns(MdnsInfo? name) {
    _mdns = name;

    make = getDeviceMake(
      currentDeviceIp: '',
      hostIp: internetAddress.address,
      gatewayIp: '',
      hostMake: make,
      mdns: _mdns,
    );
  }

  /// Some name to show the user
  String? hostId;

  static bool _isLikelyNetworkService(String? name) {
    final normalizedName = (name ?? '').toLowerCase();
    return normalizedName.contains('dhcp') ||
        normalizedName.contains('dns') ||
        normalizedName.contains('bind') ||
        normalizedName.contains('dnsmasq') ||
        normalizedName.contains('named');
  }

  static Future<String?> getDeviceMake({
    required String currentDeviceIp,
    required String hostIp,
    required String gatewayIp,
    required Future<String?> hostMake,
    required MdnsInfo? mdns,
  }) async {
    final resolvedHostMake = await hostMake;
    if (currentDeviceIp == hostIp) {
      return 'This device';
    } else if (gatewayIp == hostIp && !_isLikelyNetworkService(resolvedHostMake)) {
      return 'Router/Gateway';
    } else if (mdns != null) {
      return mdns.mdnsDomainName;
    }
    return resolvedHostMake;
  }

  static IconData getHostIcon({
    required String currentDeviceIp,
    required String hostIp,
    required String gatewayIp,
    String? hostMake,
  }) {
    if (hostIp == currentDeviceIp) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return Icons.computer;
      }
      return Icons.smartphone;
    } else if (hostIp == gatewayIp && !_isLikelyNetworkService(hostMake)) {
      return Icons.router;
    }
    return Icons.devices;
  }
}
