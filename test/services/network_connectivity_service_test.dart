import 'package:flutter_test/flutter_test.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/classes/odometer.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/services/network_connectivity_service.dart';

void main() {
  group('NetworkConnectivityService', () {
    group('checkDeviceToRouter', () {
      test('returns connected when device has a valid local IP and Wi-Fi', () {
        final service = NetworkConnectivityService();
        final wifiInfo = WifiInfo(
          '192.168.1.50',
          '00:11:22:33:44:55',
          'HomeNet',
          false,
          '192.168.1.1',
          true,
          const WifiNetworkMetrics(
            rawRssi: -55,
            normalizedLevel: 3,
            statusMessage: 'Good signal',
          ),
        );

        final status = service.checkDeviceToRouter(wifiInfo);

        expect(status.state, NetworkConnectionState.connected);
        expect(status.isConnected, isTrue);
        expect(status.label, 'Connected');
        expect(status.type, NetworkConnectionType.deviceToRouter);
        expect(status.details['Device IP'], '192.168.1.50');
        expect(status.details['Gateway IP'], '192.168.1.1');
        expect(status.details['Interface'], contains('Wi-Fi'));
        expect(status.details['Access Point (BSSID)'], '00:11:22:33:44:55');
      });

      test('identifies LAN / local interface when Wi-Fi is not active', () {
        final service = NetworkConnectivityService();
        final wifiInfo = WifiInfo(
          '10.0.0.5',
          WifiInfo.defaultBSSID.first,
          '',
          true,
          '10.0.0.1',
          false,
          WifiNetworkMetrics.disconnected(),
        );

        final status = service.checkDeviceToRouter(wifiInfo);

        expect(status.isConnected, isTrue);
        expect(status.details['Interface'], contains('LAN'));
      });

      test('returns disconnected when device has no IP address', () {
        final service = NetworkConnectivityService();
        final wifiInfo = WifiInfo(
          null,
          null,
          null,
          true,
          '',
          false,
          WifiNetworkMetrics.disconnected(),
        );

        final status = service.checkDeviceToRouter(wifiInfo);

        expect(status.state, NetworkConnectionState.disconnected);
        expect(status.isDisconnected, isTrue);
        expect(status.label, 'Disconnected');
        expect(status.troubleshootingSteps, isNotEmpty);
      });
    });

    group('checkRouterToInternet', () {
      test('returns disconnected immediately if device is not connected to router',
          () async {
        final service = NetworkConnectivityService(
          pingProbe: (host) async => const Duration(milliseconds: 15),
        );
        final wifiInfo = WifiInfo(
          null,
          null,
          null,
          true,
          '',
          false,
          WifiNetworkMetrics.disconnected(),
        );

        final status = await service.checkRouterToInternet(wifiInfo: wifiInfo);

        expect(status.state, NetworkConnectionState.disconnected);
        expect(status.troubleshootingSteps, isNotEmpty);
        expect(status.description, contains('disconnected from your local router'));
      });

      test('returns connected when ping probe succeeds', () async {
        final service = NetworkConnectivityService(
          pingProbe: (host) async => const Duration(milliseconds: 22),
          fallbackProbe: (host) async => false,
        );
        final wifiInfo = WifiInfo(
          '192.168.1.20',
          '00:11:22:33:44:55',
          'HomeNet',
          false,
          '192.168.1.1',
          true,
          WifiNetworkMetrics.disconnected(),
        );

        final status = await service.checkRouterToInternet(
          wifiInfo: wifiInfo,
          host: 'google.com',
        );

        expect(status.state, NetworkConnectionState.connected);
        expect(status.isConnected, isTrue);
        expect(status.latency, const Duration(milliseconds: 22));
        expect(status.details['Ping Latency'], '22 ms');
        expect(status.targetHost, 'google.com');
      });

      test('returns connected when ping fails but fallback probe succeeds',
          () async {
        final service = NetworkConnectivityService(
          pingProbe: (host) async => null,
          fallbackProbe: (host) async => true,
        );
        final wifiInfo = WifiInfo(
          '192.168.1.20',
          '00:11:22:33:44:55',
          'HomeNet',
          false,
          '192.168.1.1',
          true,
          WifiNetworkMetrics.disconnected(),
        );

        final status = await service.checkRouterToInternet(wifiInfo: wifiInfo);

        expect(status.state, NetworkConnectionState.connected);
        expect(status.isConnected, isTrue);
        expect(status.latency, isNull);
      });

      test('returns disconnected when both ping and fallback probe fail',
          () async {
        final service = NetworkConnectivityService(
          pingProbe: (host) async => null,
          fallbackProbe: (host) async => false,
        );
        final wifiInfo = WifiInfo(
          '192.168.1.20',
          '00:11:22:33:44:55',
          'HomeNet',
          false,
          '192.168.1.1',
          true,
          WifiNetworkMetrics.disconnected(),
        );

        final status = await service.checkRouterToInternet(wifiInfo: wifiInfo);

        expect(status.state, NetworkConnectionState.disconnected);
        expect(status.isDisconnected, isTrue);
        expect(status.troubleshootingSteps, isNotEmpty);
      });

      test('includes public IP and provider details when settings are provided',
          () async {
        final service = NetworkConnectivityService(
          pingProbe: (host) async => const Duration(milliseconds: 18),
        );
        final wifiInfo = WifiInfo(
          '192.168.1.20',
          '00:11:22:33:44:55',
          'HomeNet',
          false,
          '192.168.1.1',
          true,
          WifiNetworkMetrics.disconnected(),
        );
        final settings = Settings(
          Client(
            '203.0.113.1',
            37.77,
            -122.41,
            'Example Fiber',
            4.5,
            4.0,
            100,
            50,
            Coordinate(37.77, -122.41),
          ),
          Times(100, 100, 100, 50, 50, 50),
          Download(5000, '', '0', 4),
          Upload(5000, 100, 0, '0', 4, '0', '0', 1),
          ServerConfig(''),
          [],
          Odometer(0, 1),
        );

        final status = await service.checkRouterToInternet(
          wifiInfo: wifiInfo,
          ispSettings: settings,
        );

        expect(status.isConnected, isTrue);
        expect(status.details['Public IP'], '203.0.113.1');
        expect(status.details['Provider'], 'Example Fiber');
      });
    });
  });
}
