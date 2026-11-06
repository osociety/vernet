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

    // Use device type for better icon selection
    final deviceType = deviceData.deviceType?.toLowerCase() ?? '';
    if (deviceType.contains('router')) return Icons.router;
    if (deviceType.contains('printer')) return Icons.print;
    if (deviceType.contains('windows')) return Icons.computer;
    if (deviceType.contains('nas')) return Icons.storage;
    if (deviceType.contains('server') || deviceType.contains('linux')) {
      return Icons.dns;
    }
    if (deviceType.contains('iot')) return Icons.devices_other;
    if (deviceType.contains('camera') || deviceType.contains('display')) {
      return Icons.videocam;
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

  /// Returns a human-readable description for a port number.
  static String? getPortDescription(int port) {
    switch (port) {
      case 20:
      case 21:
        return 'FTP';
      case 22:
        return 'SSH';
      case 23:
        return 'Telnet';
      case 25:
        return 'SMTP';
      case 53:
        return 'DNS';
      case 80:
        return 'HTTP';
      case 110:
        return 'POP3';
      case 143:
        return 'IMAP';
      case 161:
        return 'SNMP';
      case 443:
        return 'HTTPS';
      case 445:
        return 'SMB';
      case 587:
        return 'SMTP';
      case 631:
        return 'IPP';
      case 993:
        return 'IMAPS';
      case 995:
        return 'POP3S';
      case 3306:
        return 'MySQL';
      case 3389:
        return 'RDP';
      case 5432:
        return 'PostgreSQL';
      case 5900:
        return 'VNC';
      case 8080:
        return 'HTTP Alt';
      case 8443:
        return 'HTTPS Alt';
      case 9100:
        return 'JetDirect';
      default:
        return null;
    }
  }

  /// Returns a formatted string with port numbers and descriptions.
  /// Example: "53 (DNS), 80 (HTTP), 443 (HTTPS)"
  static String formatOpenPorts(String? openPorts) {
    if (openPorts == null || openPorts.isEmpty) return '';

    final ports = openPorts
        .split(',')
        .map((p) => int.tryParse(p.trim()))
        .whereType<int>()
        .toList();
    if (ports.isEmpty) return openPorts;

    return ports.map((port) {
      final description = getPortDescription(port);
      return description != null ? '$port ($description)' : '$port';
    }).join(', ');
  }

  /// Returns a color category for a port based on its service type.
  /// Categories: web, network, file, remote, database, email, print, other
  static String getPortCategory(int port) {
    switch (port) {
      case 80:
      case 443:
      case 8080:
      case 8443:
        return 'web';
      case 53:
      case 161:
        return 'network';
      case 20:
      case 21:
      case 445:
        return 'file';
      case 22:
      case 23:
      case 3389:
      case 5900:
        return 'remote';
      case 3306:
      case 5432:
        return 'database';
      case 25:
      case 110:
      case 143:
      case 587:
      case 993:
      case 995:
        return 'email';
      case 631:
      case 9100:
        return 'print';
      default:
        return 'other';
    }
  }
}
