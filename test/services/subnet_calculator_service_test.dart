import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/subnet_calculator_service.dart';

void main() {
  const service = SubnetCalculatorService();

  group('IPv4 subnet calculations', () {
    test('calculates a typical /24 subnet from a host address', () {
      final result = service.calculate('192.168.1.42/24');

      expect(result.ipVersion, 'IPv4');
      expect(result.cidr, '24');
      expect(result.networkAddress, '192.168.1.0');
      expect(result.subnetMask, '255.255.255.0');
      expect(result.broadcastAddress, '192.168.1.255');
      expect(result.firstAddress, '192.168.1.1');
      expect(result.lastAddress, '192.168.1.254');
      expect(result.addressCount, '256');
    });

    test('supports non-octet prefixes and non-default masks', () {
      final result = service.calculate('172.20.17.9/13');

      expect(result.networkAddress, '172.16.0.0');
      expect(result.subnetMask, '255.248.0.0');
      expect(result.broadcastAddress, '172.23.255.255');
      expect(result.firstAddress, '172.16.0.1');
      expect(result.lastAddress, '172.23.255.254');
      expect(result.addressCount, '524288');
    });

    test('handles /0 across the full IPv4 address space', () {
      final result = service.calculate('203.0.113.7/0');

      expect(result.networkAddress, '0.0.0.0');
      expect(result.subnetMask, '0.0.0.0');
      expect(result.broadcastAddress, '255.255.255.255');
      expect(result.firstAddress, '0.0.0.1');
      expect(result.lastAddress, '255.255.255.254');
      expect(result.addressCount, '4294967296');
    });

    test('handles /31 point-to-point ranges without dropping endpoints', () {
      final result = service.calculate('192.0.2.11/31');

      expect(result.networkAddress, '192.0.2.10');
      expect(result.broadcastAddress, '192.0.2.11');
      expect(result.firstAddress, '192.0.2.10');
      expect(result.lastAddress, '192.0.2.11');
      expect(result.addressCount, '2');
    });

    test('handles /32 as a single-address subnet', () {
      final result = service.calculate('192.0.2.11/32');

      expect(result.networkAddress, '192.0.2.11');
      expect(result.broadcastAddress, '192.0.2.11');
      expect(result.firstAddress, '192.0.2.11');
      expect(result.lastAddress, '192.0.2.11');
      expect(result.addressCount, '1');
    });
  });

  group('IPv6 subnet calculations', () {
    test('calculates a /64 network and address range', () {
      final result = service.calculate('2001:db8:abcd:12::1234/64');

      expect(result.ipVersion, 'IPv6');
      expect(result.cidr, '64');
      expect(result.networkAddress, '2001:db8:abcd:12::');
      expect(result.subnetMask, 'ffff:ffff:ffff:ffff::');
      expect(result.broadcastAddress, isNull);
      expect(result.firstAddress, '2001:db8:abcd:12::');
      expect(result.lastAddress, '2001:db8:abcd:12:ffff:ffff:ffff:ffff');
      expect(result.addressCount, '18446744073709551616');
    });

    test('supports non-nibble-aligned prefixes', () {
      final result = service.calculate('2001:db8::1234/73');

      expect(result.networkAddress, '2001:db8::');
      expect(result.subnetMask, 'ffff:ffff:ffff:ffff:ff80::');
      expect(result.lastAddress, '2001:db8::7f:ffff:ffff:ffff');
      expect(result.addressCount, '36028797018963968');
    });

    test('handles /0 and /128 boundaries', () {
      final allIpv6 = service.calculate('2001:db8::1/0');
      expect(allIpv6.networkAddress, '::');
      expect(allIpv6.subnetMask, '::');
      expect(allIpv6.lastAddress, 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff');
      expect(allIpv6.addressCount, '340282366920938463463374607431768211456');

      final single = service.calculate('2001:db8::1/128');
      expect(single.networkAddress, '2001:db8::1');
      expect(single.subnetMask, 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff');
      expect(single.firstAddress, '2001:db8::1');
      expect(single.lastAddress, '2001:db8::1');
      expect(single.addressCount, '1');
    });
  });

  group('input validation', () {
    test('trims surrounding whitespace', () {
      expect(
        service.calculate('  192.168.1.10/24  ').networkAddress,
        '192.168.1.0',
      );
    });

    for (final input in [
      '',
      '192.168.1.1',
      '/24',
      '192.168.1.1/',
      '192.168.1.1/nope',
      '192.168.1.1/24/3',
      '999.168.1.1/24',
      '2001:db8::1/129',
    ]) {
      test('rejects "$input"', () {
        expect(() => service.calculate(input), throwsFormatException);
      });
    }

    test('rejects IPv4 prefixes outside 0 through 32', () {
      expect(() => service.calculate('192.168.1.1/-1'), throwsFormatException);
      expect(() => service.calculate('192.168.1.1/33'), throwsFormatException);
    });

    test('rejects IPv6 prefixes below zero', () {
      expect(() => service.calculate('2001:db8::1/-1'), throwsFormatException);
    });
  });
}
