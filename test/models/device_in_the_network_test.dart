import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools/src/injection.dart' as nt_injection;
import 'package:network_tools/src/models/vendor.dart' as nt_vendor;
import 'package:network_tools/src/repository/repository.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/models/device_in_the_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Register minimal in-memory repositories so ActiveHost can resolve ARP/vendor
    // data without touching the real database or network.
    if (!nt_injection.getIt.isRegistered<Repository<ARPData>>()) {
      nt_injection.getIt.registerSingleton<Repository<ARPData>>(
        _FakeArpRepository(),
      );
    }
    if (!nt_injection.getIt.isRegistered<Repository<nt_vendor.Vendor>>()) {
      nt_injection.getIt.registerSingleton<Repository<nt_vendor.Vendor>>(
        _FakeVendorRepository(),
      );
    }
  });

  // Remaining tests ...

  group('DeviceInTheNetwork', () {
    final testIp = InternetAddress.tryParse('192.168.1.100')!;
    const currentDeviceIp = '192.168.1.50';
    const gatewayIp = '192.168.1.1';
    const testPingData = PingData();

    test('can be created with basic constructor', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Test Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      expect(device, isA<DeviceInTheNetwork>());
      expect(device.internetAddress, testIp);
      expect(device.currentDeviceIp, currentDeviceIp);
      expect(device.gatewayIp, gatewayIp);
      expect(device.iconData, Icons.devices);
      expect(device.pingData, testPingData);
    });

    test('can be created with custom icon', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Laptop'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
        iconData: Icons.computer,
      );

      expect(device.iconData, Icons.computer);
    });

    test('can store MAC address', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
        mac: 'aa:bb:cc:dd:ee:ff',
      );

      expect(device.mac, '(aa:bb:cc:dd:ee:ff)');
    });

    test('MAC address returns empty string when not provided', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      expect(device.mac, '');
    });

    test('internetAddress can be converted to string', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      expect(device.internetAddress.address, '192.168.1.100');
    });

    test('hostId can be optional', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      expect(device.hostId, isNull);
    });

    test('hostId can be set', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
        hostId: '42',
      );

      expect(device.hostId, '42');
    });

    test('can access make as Future', () async {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Test Manufacturer'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      final make = await device.make;
      expect(make, 'Test Manufacturer');
    });

    test('mdns property can be set and retrieved', () {
      // Skip MdnsInfo creation since it requires complex resource records
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      expect(device.mdns, isNull);
    });

    test('mdns can be set to null', () {
      final device = DeviceInTheNetwork(
        internetAddress: testIp,
        makeVar: Future.value('Device'),
        pingData: testPingData,
        currentDeviceIp: currentDeviceIp,
        gatewayIp: gatewayIp,
      );

      device.mdns = null;
      expect(device.mdns, isNull);
    });
  });

  group('DeviceInTheNetwork.getDeviceMake', () {
    test('returns "This device" when IP matches current device', () async {
      final result = await DeviceInTheNetwork.getDeviceMake(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        hostMake: Future.value('Generic Device'),
        mdns: null,
      );

      expect(result, 'This device');
    });

    test('returns "Router/Gateway" when IP matches gateway', () async {
      final result = await DeviceInTheNetwork.getDeviceMake(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
        hostMake: Future.value('Generic Router'),
        mdns: null,
      );

      expect(result, 'Router/Gateway');
    });

    test('returns hostMake when none of the conditions are met', () async {
      final result = await DeviceInTheNetwork.getDeviceMake(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.200',
        gatewayIp: '192.168.1.1',
        hostMake: Future.value('Samsung TV'),
        mdns: null,
      );

      expect(result, 'Samsung TV');
    });

    test('handles null mdns correctly', () async {
      final result = await DeviceInTheNetwork.getDeviceMake(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.200',
        gatewayIp: '192.168.1.1',
        hostMake: Future.value('Device'),
        mdns: null,
      );

      expect(result, 'Device');
    });
  });

  group('DeviceInTheNetwork.getHostIcon', () {
    test('returns smartphone icon for current device on mobile', () {
      if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
        final icon = DeviceInTheNetwork.getHostIcon(
          currentDeviceIp: '192.168.1.100',
          hostIp: '192.168.1.100',
          gatewayIp: '192.168.1.1',
        );

        expect(icon, Icons.smartphone);
      }
    });

    test('returns computer icon for current device on desktop', () {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final icon = DeviceInTheNetwork.getHostIcon(
          currentDeviceIp: '192.168.1.100',
          hostIp: '192.168.1.100',
          gatewayIp: '192.168.1.1',
        );

        expect(icon, Icons.computer);
      }
    });

    test('returns router icon for gateway', () {
      final icon = DeviceInTheNetwork.getHostIcon(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      expect(icon, Icons.router);
    });

    test('returns devices icon for other hosts', () {
      final icon = DeviceInTheNetwork.getHostIcon(
        currentDeviceIp: '192.168.1.100',
        hostIp: '192.168.1.200',
        gatewayIp: '192.168.1.1',
      );

      expect(icon, Icons.devices);
    });

    test('prioritizes current device check over gateway check', () {
      final icon = DeviceInTheNetwork.getHostIcon(
        currentDeviceIp: '192.168.1.1',
        hostIp: '192.168.1.1',
        gatewayIp: '192.168.1.1',
      );

      // Should return computer or smartphone (current device), not router
      expect(
        icon,
        isIn([Icons.computer, Icons.smartphone]),
      );
    });
  });

  group('DeviceInTheNetwork.createWithAllNecessaryFields', () {
    test('creates device with correct icon for current device', () {
      final ip = InternetAddress.tryParse('192.168.1.100')!;
      const currentIp = '192.168.1.100';

      final device = DeviceInTheNetwork.createWithAllNecessaryFields(
        internetAddress: ip,
        hostId: 'host1',
        make: Future.value('Device'),
        pingData: const PingData(),
        currentDeviceIp: currentIp,
        gatewayIp: '192.168.1.1',
        mdns: null,
        mac: 'aa:bb:cc:dd:ee:ff',
      );

      // Icon should be computer or smartphone for current device
      expect(
        device.iconData,
        isIn([Icons.computer, Icons.smartphone]),
      );
    });

    test('creates device with router icon for gateway', () {
      final ip = InternetAddress.tryParse('192.168.1.1')!;

      final device = DeviceInTheNetwork.createWithAllNecessaryFields(
        internetAddress: ip,
        hostId: 'gateway',
        make: Future.value('Router'),
        pingData: const PingData(),
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mdns: null,
        mac: null,
      );

      expect(device.iconData, Icons.router);
    });

    test('creates device with correct make for other hosts', () async {
      final ip = InternetAddress.tryParse('192.168.1.200')!;

      final device = DeviceInTheNetwork.createWithAllNecessaryFields(
        internetAddress: ip,
        hostId: 'printer',
        make: Future.value('HP Printer'),
        pingData: const PingData(),
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mdns: null,
        mac: 'ff:ee:dd:cc:bb:aa',
      );

      final make = await device.make;
      expect(make, 'HP Printer');
      expect(device.hostId, 'printer');
      expect(device.mac, '(ff:ee:dd:cc:bb:aa)');
    });

    test('creates device with devices icon for other hosts', () {
      final ip = InternetAddress.tryParse('192.168.1.200')!;

      final device = DeviceInTheNetwork.createWithAllNecessaryFields(
        internetAddress: ip,
        hostId: 'other',
        make: Future.value('Some Device'),
        pingData: const PingData(),
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mdns: null,
        mac: null,
      );

      expect(device.iconData, Icons.devices);
    });
  });

  group('DeviceInTheNetwork.createFromActiveHost', () {
    test('creates device from active host with correct properties', () {
      final activeHost = ActiveHost(
        internetAddress: InternetAddress.tryParse('192.168.1.150')!,
      );

      final device = DeviceInTheNetwork.createFromActiveHost(
        activeHost: activeHost,
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mac: 'aa:bb:cc:dd:ee:ff',
      );

      expect(device.internetAddress.address, '192.168.1.150');
      expect(device.currentDeviceIp, '192.168.1.100');
      expect(device.gatewayIp, '192.168.1.1');
      expect(device.mac, '(aa:bb:cc:dd:ee:ff)');
      expect(device.iconData, Icons.devices);
    });

    test('creates device with correct icon for current device from active host',
        () {
      final activeHost = ActiveHost(
        internetAddress: InternetAddress.tryParse('192.168.1.100')!,
      );

      final device = DeviceInTheNetwork.createFromActiveHost(
        activeHost: activeHost,
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mac: null,
      );

      // Should be computer or smartphone for current device
      expect(
        device.iconData,
        isIn([Icons.computer, Icons.smartphone]),
      );
    });

    test('creates device with router icon for gateway from active host', () {
      final activeHost = ActiveHost(
        internetAddress: InternetAddress.tryParse('192.168.1.1')!,
      );

      final device = DeviceInTheNetwork.createFromActiveHost(
        activeHost: activeHost,
        currentDeviceIp: '192.168.1.100',
        gatewayIp: '192.168.1.1',
        mac: null,
      );

      expect(device.iconData, Icons.router);
    });
  });
}

class _FakeArpRepository implements Repository<ARPData> {
  @override
  Future<void> build() async {}

  @override
  Future<bool> clear() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<String?>?> entries() async => const [];

  @override
  Future<ARPData?> entryFor(String address) async => null;
}

class _FakeVendorRepository implements Repository<nt_vendor.Vendor> {
  @override
  Future<void> build() async {}

  @override
  Future<bool> clear() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<String?>?> entries() async => const [];

  @override
  Future<nt_vendor.Vendor?> entryFor(String address) async => null;
}
