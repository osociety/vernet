import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';

void main() {
  group('WifiInfo getters', () {
    test('ip returns fallback when null', () {
      final info = WifiInfo(null, null, null, true, '192.168.1.1', false,
          WifiNetworkMetrics.disconnected());
      expect(info.ip, 'x.x.x.x');
    });

    test('subnet derives from gateway', () {
      final info = WifiInfo('1.2.3.4', null, null, true, '10.0.0.1', false,
          WifiNetworkMetrics.disconnected());
      expect(info.subnet, '10.0.0');
    });

    test('scanSubnet falls back to the detected gateway', () {
      final info = WifiInfo('1.2.3.4', null, null, false, '192.168.1.1', false,
          WifiNetworkMetrics.disconnected());
      expect(info.scanSubnet, '192.168.1.1');
      expect(info.subnet, '192.168.1');
    });

    test('a custom scan subnet never becomes the gateway (#646)', () {
      final info = WifiInfo('192.168.1.10', null, null, false, '192.168.1.1',
          false, WifiNetworkMetrics.disconnected(),
          scanSubnet: '10.0.0.1');
      expect(info.gatewayIp, '192.168.1.1');
      expect(info.scanSubnet, '10.0.0.1');
      expect(info.subnet, '10.0.0');
    });

    test('an empty custom scan subnet leaves the gateway subnet in use', () {
      final info = WifiInfo('192.168.1.10', null, null, false, '192.168.1.1',
          false, WifiNetworkMetrics.disconnected(),
          scanSubnet: '');
      expect(info.scanSubnet, '192.168.1.1');
      expect(info.subnet, '192.168.1');
    });

    test('subnet does not throw when the scan subnet has no dot', () {
      final info = WifiInfo(
          '1', null, null, false, 'g', false, WifiNetworkMetrics.disconnected(),
          scanSubnet: 'localhost');
      expect(info.subnet, 'localhost');
    });

    test('name handles empty, quoted and normal values', () {
      final a = WifiInfo(
          '1', null, '', true, 'g', false, WifiNetworkMetrics.disconnected());
      expect(a.name, WifiInfo.noWifiName);

      final b = WifiInfo('1', null, '"foo"', false, 'g', false,
          WifiNetworkMetrics.disconnected());
      expect(b.name, 'foo');

      final c = WifiInfo('1', null, 'mywifi', false, 'g', false,
          WifiNetworkMetrics.disconnected());
      expect(c.name, 'mywifi');
    });

    test('bssid falls back to default when null', () {
      final info = WifiInfo(
          '1', null, null, true, 'g', false, WifiNetworkMetrics.disconnected());
      expect(info.bssid, WifiInfo.defaultBSSID.first);
    });
  });
}
