import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:speed_test_dart/classes/settings.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/wifi_info.dart';

typedef PingProbe = Future<Duration?> Function(String host);
typedef FallbackProbe = Future<bool> Function(String host);

class NetworkConnectivityService {
  NetworkConnectivityService({
    PingProbe? pingProbe,
    FallbackProbe? fallbackProbe,
    this.targetHost = 'google.com',
  })  : _pingProbe = pingProbe ?? _defaultPingProbe,
        _fallbackProbe = fallbackProbe ?? _defaultFallbackProbe;

  final PingProbe _pingProbe;
  final FallbackProbe _fallbackProbe;
  final String targetHost;

  static Future<Duration?> _defaultPingProbe(String host) async {
    try {
      final ping = Ping(host, count: 1, timeout: 3);
      final event = await ping.stream
          .firstWhere((e) => e is PingResponse || e is PingSummary)
          .timeout(const Duration(seconds: 4));

      if (event is PingResponse && event.time != null) {
        return event.time;
      }
      if (event is PingSummary && event.received > 0) {
        return event.stats?.min ?? const Duration(milliseconds: 20);
      }
    } catch (_) {
      // Ping failed or raw ICMP sockets restricted on platform
    }
    return null;
  }

  static Future<bool> _defaultFallbackProbe(String host) async {
    try {
      final lookup = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {}

    return false;
  }

  /// Diagnoses the local link between this device and the local router or interface.
  NetworkConnectionStatus checkDeviceToRouter(WifiInfo wifiInfo) {
    final hasValidIp = wifiInfo.ip.isNotEmpty && wifiInfo.ip != 'x.x.x.x';

    final isWifi =
        (wifiInfo.name != WifiInfo.noWifiName && wifiInfo.name.isNotEmpty) ||
            wifiInfo.metrics.normalizedLevel > 0;
    final interfaceName = isWifi
        ? (wifiInfo.name == WifiInfo.noWifiName
            ? 'Wi-Fi'
            : 'Wi-Fi (${wifiInfo.name})')
        : 'LAN / Local Interface';

    if (hasValidIp) {
      final details = <String, String>{
        'Device IP': wifiInfo.ip,
        'Gateway IP':
            wifiInfo.gatewayIp.isEmpty ? 'Unavailable' : wifiInfo.gatewayIp,
        'Interface': interfaceName,
      };

      if (wifiInfo.bssid != WifiInfo.defaultBSSID.first) {
        details['Access Point (BSSID)'] = wifiInfo.bssid;
      }
      if (wifiInfo.metrics.statusMessage.isNotEmpty &&
          wifiInfo.metrics.normalizedLevel > 0) {
        details['Signal Strength'] = wifiInfo.metrics.statusMessage;
      }

      return NetworkConnectionStatus(
        type: NetworkConnectionType.deviceToRouter,
        state: NetworkConnectionState.connected,
        title: 'Device Connected to Router',
        summary: 'Connected via $interfaceName',
        description:
            'Your device has a valid local IP address and is successfully communicating with your local router/gateway.',
        details: details,
        interfaceType: interfaceName,
      );
    }

    return const NetworkConnectionStatus(
      type: NetworkConnectionType.deviceToRouter,
      state: NetworkConnectionState.disconnected,
      title: 'Device Disconnected from Router',
      summary: 'No active connection to local network',
      description:
          'Your device does not have an active IP address or connection to a local network interface or Wi-Fi router.',
      troubleshootingSteps: [
        'Ensure Wi-Fi or Ethernet is turned on in your device settings.',
        'Verify you are connected to the correct Wi-Fi network and entered the right password.',
        'Check if your router or access point is powered on and within range.',
        'Restart your device network interface or reconnect to the network.',
      ],
      details: {
        'Device IP': 'Not assigned',
        'Gateway IP': 'Unavailable',
        'Interface': 'Disconnected',
      },
      interfaceType: 'None',
    );
  }

  /// Diagnoses the WAN link between the router and the broader internet.
  Future<NetworkConnectionStatus> checkRouterToInternet({
    WifiInfo? wifiInfo,
    Settings? ispSettings,
    String? host,
  }) async {
    final target = host ?? targetHost;

    if (wifiInfo != null && (wifiInfo.ip.isEmpty || wifiInfo.ip == 'x.x.x.x')) {
      return NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: 'Internet Unreachable (No Local Link)',
        summary: 'Device is not connected to router',
        description:
            'Because this device is disconnected from your local router or network interface, it cannot verify the internet connection.',
        troubleshootingSteps: const [
          'First connect your device to your local Wi-Fi or Ethernet network.',
          'Once connected to the router, test the internet connection again.',
        ],
        details: {
          'Target Host': target,
          'Local Status': 'Disconnected from local network',
        },
        targetHost: target,
      );
    }

    Duration? latency;
    bool isConnected = false;

    try {
      latency = await _pingProbe(target);
      if (latency != null) {
        isConnected = true;
      } else {
        isConnected = await _fallbackProbe(target);
      }
    } catch (_) {
      isConnected = false;
    }

    if (isConnected) {
      final details = <String, String>{
        'Test Target': target,
      };
      if (latency != null) {
        details['Ping Latency'] = '${latency.inMilliseconds} ms';
      }
      if (ispSettings != null) {
        details['Public IP'] = ispSettings.client.ip;
        details['Provider'] = ispSettings.client.isp;
      }

      return NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.connected,
        title: 'Router Connected to Internet',
        summary: latency != null
            ? 'Internet reachable (${latency.inMilliseconds} ms)'
            : 'Internet reachable',
        description:
            'Successfully reached internet servers ($target). Your router has an active WAN connection to your Internet Service Provider.',
        latency: latency,
        targetHost: target,
        details: details,
      );
    }

    final details = <String, String>{
      'Test Target': target,
      'Connection Status': 'Host unreachable / No response',
    };
    if (ispSettings != null) {
      details['Public IP'] = ispSettings.client.ip;
    }

    return NetworkConnectionStatus(
      type: NetworkConnectionType.routerToInternet,
      state: NetworkConnectionState.disconnected,
      title: 'Router Disconnected from Internet',
      summary: 'Unable to reach internet servers',
      description:
          'We were unable to reach internet servers ($target). Your device is connected to the router, but the router cannot access the internet.',
      troubleshootingSteps: const [
        'Check if the broadband, fiber, or DSL cable is securely plugged into your router WAN port.',
        'Restart or power-cycle your modem and Wi-Fi router (unplug power for 30 seconds).',
        'Verify that your Internet Service Provider (ISP) is not experiencing a service outage.',
        'Check if your router requires PPPoE login or has DNS configuration errors.',
      ],
      details: details,
      targetHost: target,
    );
  }
}
