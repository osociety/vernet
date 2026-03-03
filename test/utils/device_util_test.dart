import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/utils/device_util.dart';

DeviceData _device({
  String internetAddress = '192.168.0.2',
  String currentIp = '192.168.0.10',
  String gatewayIp = '192.168.0.1',
  String? mdnsDomainName,
  String hostMake = 'Some Device',
}) {
  return DeviceData(
    id: 1,
    internetAddress: internetAddress,
    macAddress: '00:11:22:33:44:55',
    hostMake: hostMake,
    gatewayIp: gatewayIp,
    currentDeviceIp: currentIp,
    scanId: 1,
    mdnsDomainName: mdnsDomainName,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceUtil.getDeviceMake', () {
    test('returns "This device" when current device IP matches', () {
      final device = _device(
        internetAddress: '192.168.0.10',
      );

      expect(DeviceUtil.getDeviceMake(device), 'This device');
    });

    test('returns "Router/Gateway" when gateway IP matches', () {
      final device = _device(
        internetAddress: '192.168.0.1',
      );

      expect(DeviceUtil.getDeviceMake(device), 'Router/Gateway');
    });

    test('returns mDNS domain name when present', () {
      final device = _device(
        mdnsDomainName: 'test.local',
      );

      expect(DeviceUtil.getDeviceMake(device), 'test.local');
    });

    test('falls back to hostMake', () {
      final device = _device(
        hostMake: 'My Host',
      );

      expect(DeviceUtil.getDeviceMake(device), 'My Host');
    });
  });

  group('DeviceUtil.getIconData', () {
    test('returns desktop icon for current device on desktop platforms', () {
      final device = _device(
        internetAddress: '192.168.0.10',
      );

      // On CI / dev machine this will typically be true.
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        expect(DeviceUtil.getIconData(device), Icons.computer);
      }
    });

    test('returns router icon when internetAddress equals gatewayIp', () {
      final device = _device(
        internetAddress: '192.168.0.1',
      );

      expect(DeviceUtil.getIconData(device), Icons.router);
    });

    test('returns generic devices icon otherwise', () {
      final device = _device();

      expect(DeviceUtil.getIconData(device), Icons.devices);
    });
  });
}
