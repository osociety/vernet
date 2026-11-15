import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/services/network_connectivity_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  // The service reads the app language without a BuildContext, so the tests
  // pin it instead of inheriting whatever the machine running them speaks.
  setUp(() => LocaleProvider.active = const Locale('en'));
  tearDown(() => LocaleProvider.active = null);
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
            quality: WifiSignalQuality.excellent,
          ),
        );

        final status = service.checkDeviceToRouter(wifiInfo);

        expect(status.state, NetworkConnectionState.connected);
        expect(status.isConnected, isTrue);
        expect(status.label, l10nEn().netConnected);
        expect(status.type, NetworkConnectionType.deviceToRouter);
        final l10n = l10nEn();
        expect(status.details[l10n.netDetailDeviceIp], '192.168.1.50');
        expect(status.details[l10n.netDetailGatewayIp], '192.168.1.1');
        expect(status.details[l10n.netDetailInterface],
            contains(l10n.netInterfaceWifi));
        expect(
          status.details[l10n.netDetailAccessPointBssid],
          '00:11:22:33:44:55',
        );
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
        expect(status.details[l10nEn().netDetailInterface], contains('LAN'));
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
        expect(status.label, l10nEn().netDisconnected);
        expect(status.troubleshootingSteps, isNotEmpty);
      });
    });

    group('checkRouterToInternet', () {
      test(
          'returns disconnected immediately if device is not connected to router',
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
        expect(
          status.description,
          contains(l10nEn().netDescNoLocalLinkCheck),
        );
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
        expect(status.details[l10nEn().netDetailPingLatency], '22 ms');
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
    });
  });
}
