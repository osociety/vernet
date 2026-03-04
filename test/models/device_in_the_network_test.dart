import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/models/device_in_the_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceInTheNetwork', () {
    final testIp = InternetAddress.tryParse('192.168.1.100')!;
    final testPingData = const PingData();

    test('can be created with basic constructor', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Test Device'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      expect(device, isA<DeviceInTheNetwork>());
      expect(device.internetAddress, testIp);
      expect(device.currentDeviceIp, '192.168.1.1');
      expect(device.gatewayIp, '192.168.1.1');
      expect(device.iconData, Icons.devices);
    });

    test('can be created with custom icon', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Laptop'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
        iconData: Icons.computer,
      );

      expect(device.iconData, Icons.computer);
    });

    test('can store MAC address', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
        mac: 'aa:bb:cc:dd:ee:ff',
      );

      expect(device, isA<DeviceInTheNetwork>());
    });

    test('internetAddress can be converted to string', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      expect(device.internetAddress.address, '192.168.1.100');
    });

    test('hostId can be optional', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      expect(device.hostId, isNull);
    });

    test('hostId can be set', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
        hostId: '42',
      );

      expect(device.hostId, '42');
    });

    test('can access make as Future', () async {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Test Manufacturer'),
        pingData: testPingData,
        currentDeviceIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      final make = await device.make;
      expect(make, 'Test Manufacturer');
    });
  });
}
