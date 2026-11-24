import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings', () {
    late AppSettings settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = AppSettings.instance;
      await settings.clearAll();
      await settings.load();
    });

    test('has correct default values', () {
      expect(settings.firstSubnet, 1);
      expect(settings.lastSubnet, 254);
      expect(settings.socketTimeout, 500);
      expect(settings.pingCount, 5);
      expect(settings.inAppInternet, isTrue);
      expect(settings.runScanOnStartup, isFalse);
      expect(settings.customSubnet, isEmpty);
      expect(settings.gatewayIP, isEmpty);
      expect(settings.scanTimeout, 2);
      expect(settings.scanConcurrency, AppSettings.recommendedScanConcurrency);
      expect(settings.pingMethod, ScanPingMethod.tcpFallback);
      expect(settings.mdnsEnabled, isTrue);
    });

    test('persists and reloads updated values', () async {
      await settings.setFirstSubnet(10);
      await settings.setLastSubnet(200);
      await settings.setSocketTimeout(250);
      await settings.setPingCount(7);
      await settings.setInAppInternet(true);
      await settings.setRunScanOnStartup(true);
      await settings.setCustomSubnet('192.168.1.0');
      await settings.setScanTimeout(5);
      await settings.setScanConcurrency(64);
      await settings.setPingMethod(ScanPingMethod.icmp);
      await settings.setMdnsEnabled(false);

      final reloaded = AppSettings.instance;
      await reloaded.load();

      expect(reloaded.firstSubnet, 10);
      expect(reloaded.lastSubnet, 200);
      expect(reloaded.socketTimeout, 250);
      expect(reloaded.pingCount, 7);
      expect(reloaded.inAppInternet, isTrue);
      expect(reloaded.runScanOnStartup, isTrue);
      expect(reloaded.customSubnet, '192.168.1.0');
      expect(reloaded.gatewayIP, '192.168.1');
      expect(reloaded.scanTimeout, 5);
      expect(reloaded.scanConcurrency, 64);
      expect(reloaded.pingMethod, ScanPingMethod.icmp);
      expect(reloaded.mdnsEnabled, isFalse);
    });

    test('trims spaces around a saved custom subnet', () async {
      await settings.setCustomSubnet('  10.0.0.1  ');

      expect(settings.customSubnet, '10.0.0.1');
      expect(settings.gatewayIP, '10.0.0');

      await settings.load();
      expect(settings.customSubnet, '10.0.0.1');
    });

    test('saves a whitespace-only custom subnet as empty', () async {
      await settings.setCustomSubnet('10.0.0.1');

      await settings.setCustomSubnet('   ');

      expect(settings.customSubnet, isEmpty);
    });

    test('calculates the scan range from the subnet mask', () {
      final range =
          settings.calculateHostRange('192.168.1.42', '255.255.255.0');

      expect(range.first, 1);
      expect(range.last, 254);

      final classBRange =
          settings.calculateHostRange('10.12.34.56', '255.255.0.0');
      expect(classBRange.first, 1);
      expect(classBRange.last, 254);

      final edgeRange =
          settings.calculateHostRange('172.16.0.1', '255.255.255.252');
      expect(edgeRange.first, 1);
      expect(edgeRange.last, 2);
    });

    test('gatewayIP does not throw when customSubnet contains no dot',
        () async {
      await settings.setCustomSubnet('localhost');
      expect(settings.gatewayIP, 'localhost');
    });
  });
}
