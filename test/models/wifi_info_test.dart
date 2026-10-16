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
