import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/utils/device_distribution.dart';

DeviceData device(String ip,
    {String currentDeviceIp = '192.168.1.10',
    String gatewayIp = '192.168.1.1'}) {
  return DeviceData(
    id: ip.hashCode,
    internetAddress: ip,
    hostMake: 'host-$ip',
    currentDeviceIp: currentDeviceIp,
    gatewayIp: gatewayIp,
    scanId: 1,
  );
}

void main() {
  group('DeviceDistribution.fromDevices', () {
    test('builds 254 blocks, first host id 1, last 254', () {
      final distribution =
          DeviceDistribution.fromDevices([device('192.168.1.42')]);

      expect(distribution.blocks, hasLength(254));
      expect(distribution.blocks.first.hostId, 1);
      expect(distribution.blocks.last.hostId, 254);
      expect(distribution.subnetPrefix, '192.168.1');
    });

    test('marks the blocks of found devices and only those', () {
      final distribution = DeviceDistribution.fromDevices([
        device('192.168.1.1'),
        device('192.168.1.42'),
        device('192.168.1.254'),
      ]);

      expect(distribution.blockFor(1).isFound, isTrue);
      expect(distribution.blockFor(42).isFound, isTrue);
      expect(distribution.blockFor(254).isFound, isTrue);
      expect(distribution.blockFor(2).isFound, isFalse);
      expect(distribution.blockFor(2).device, isNull);
      expect(distribution.foundCount, 3);
    });

    test('attaches the device to its block', () {
      final router = device('192.168.1.1');
      final distribution = DeviceDistribution.fromDevices([router]);

      expect(distribution.blockFor(1).device, same(router));
      expect(distribution.foundDevices, contains(router));
    });

    test('addressOf joins prefix and host id', () {
      final distribution = DeviceDistribution.fromDevices([device('10.0.0.7')]);

      expect(distribution.subnetPrefix, '10.0.0');
      expect(distribution.addressOf(7), '10.0.0.7');
      expect(distribution.addressOf(254), '10.0.0.254');
    });

    test('ignores addresses outside 1..254 and malformed ips', () {
      final distribution = DeviceDistribution.fromDevices([
        device('192.168.1.0'),
        device('192.168.1.255'),
        device('not-an-ip'),
        device('192.168.1.300'),
        device('192.168.1.9'),
      ]);

      expect(distribution.foundCount, 1);
      expect(distribution.blockFor(9).isFound, isTrue);
    });

    test('blockFor clamps out-of-range host ids to the edges', () {
      final distribution =
          DeviceDistribution.fromDevices([device('192.168.1.5')]);

      expect(distribution.blockFor(0).hostId, 1);
      expect(distribution.blockFor(999).hostId, 254);
      expect(distribution.blockFor(5).isFound, isTrue);
    });

    test('empty scan yields an empty prefix and 254 empty blocks', () {
      final distribution = DeviceDistribution.fromDevices(const []);

      expect(distribution.subnetPrefix, '');
      expect(distribution.blocks, hasLength(DeviceDistribution.blockCount));
      expect(distribution.foundCount, 0);
      expect(distribution.foundDevices, isEmpty);
    });

    test('uses the first parseable device address for the subnet prefix', () {
      final distribution = DeviceDistribution.fromDevices([
        device('garbage'),
        device('172.16.5.20'),
        device('172.16.5.30'),
      ]);

      expect(distribution.subnetPrefix, '172.16.5');
      expect(distribution.blockFor(20).isFound, isTrue);
      expect(distribution.blockFor(30).isFound, isTrue);
    });
  });
}
