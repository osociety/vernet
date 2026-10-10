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
    });

    test('persists and reloads updated values', () async {
      await settings.setFirstSubnet(10);
      await settings.setLastSubnet(200);
      await settings.setSocketTimeout(250);
      await settings.setPingCount(7);
      await settings.setInAppInternet(true);
      await settings.setRunScanOnStartup(true);
      await settings.setCustomSubnet('192.168.1.0');

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
  });
}
