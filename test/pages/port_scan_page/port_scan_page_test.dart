import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';

void main() {
  group('normalizeTarget', () {
    test('strips square brackets from IPv6 address', () {
      expect(PortScanPage.normalizeTarget('[2001:db8::1]'), '2001:db8::1');
    });

    test('strips brackets from IPv6 loopback', () {
      expect(PortScanPage.normalizeTarget('[::1]'), '::1');
    });

    test('leaves bare IPv6 address unchanged', () {
      expect(PortScanPage.normalizeTarget('2001:db8::1'), '2001:db8::1');
    });

    test('leaves IPv4 address unchanged', () {
      expect(PortScanPage.normalizeTarget('192.168.1.1'), '192.168.1.1');
    });

    test('leaves domain name unchanged', () {
      expect(PortScanPage.normalizeTarget('google.com'), 'google.com');
    });

    test('trims surrounding whitespace', () {
      expect(PortScanPage.normalizeTarget('  192.168.1.1  '), '192.168.1.1');
    });

    test('trims whitespace around bracketed IPv6', () {
      expect(PortScanPage.normalizeTarget('  [::1]  '), '::1');
    });

    test('handles empty string', () {
      expect(PortScanPage.normalizeTarget(''), '');
    });

    test('handles string with only brackets', () {
      expect(PortScanPage.normalizeTarget('[]'), '');
    });
  });
}
