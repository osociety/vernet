import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/utils/app_strings.dart';
import 'package:vernet/values/globals.dart' as globals;

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
    final l10n = appStrings();
    final hasValidIp = wifiInfo.ip.isNotEmpty && wifiInfo.ip != 'x.x.x.x';

    final isWifi =
        (wifiInfo.name != WifiInfo.noWifiName && wifiInfo.name.isNotEmpty) ||
            wifiInfo.metrics.normalizedLevel > 0;
    final interfaceName = isWifi
        ? (wifiInfo.name == WifiInfo.noWifiName
            ? l10n.netInterfaceWifi
            : l10n.netInterfaceWifiNamed(wifiInfo.name))
        : l10n.netInterfaceLan;

    if (hasValidIp) {
      final details = <String, String>{
        l10n.netDetailDeviceIp: wifiInfo.ip,
        l10n.netDetailGatewayIp: wifiInfo.gatewayIp.isEmpty
            ? l10n.netUnavailable
            : wifiInfo.gatewayIp,
        l10n.netDetailInterface: interfaceName,
      };

      if (wifiInfo.bssid != WifiInfo.defaultBSSID.first) {
        details[l10n.netDetailAccessPointBssid] = wifiInfo.bssid;
      }
      if (wifiInfo.metrics.normalizedLevel > 0) {
        details[l10n.netDetailSignalStrength] =
            wifiInfo.metrics.quality.label(l10n);
      }

      return NetworkConnectionStatus(
        type: NetworkConnectionType.deviceToRouter,
        state: NetworkConnectionState.connected,
        title: l10n.netTitleDeviceConnected,
        summary: l10n.netSummaryConnectedVia(interfaceName),
        description: l10n.netDescDeviceConnected,
        details: details,
        interfaceType: interfaceName,
      );
    }

    return NetworkConnectionStatus(
      type: NetworkConnectionType.deviceToRouter,
      state: NetworkConnectionState.disconnected,
      title: l10n.netTitleDeviceDisconnected,
      summary: l10n.netSummaryNoActiveLocal,
      description: l10n.netDescDeviceDisconnected,
      troubleshootingSteps: [
        l10n.netStepWifiOrEthernetOn,
        l10n.netStepCorrectNetwork,
        l10n.netStepRouterPowered,
        l10n.netStepReconnectInterface,
      ],
      details: {
        l10n.netDetailDeviceIp: l10n.netValueNotAssigned,
        l10n.netDetailGatewayIp: l10n.netUnavailable,
        l10n.netDetailInterface: l10n.netDisconnected,
      },
      interfaceType: l10n.netInterfaceNone,
    );
  }

  /// Diagnoses the WAN link between the router and the broader internet.
  Future<NetworkConnectionStatus> checkRouterToInternet({
    WifiInfo? wifiInfo,
    String? host,
  }) async {
    final l10n = appStrings();
    final target = host ?? targetHost;

    if (wifiInfo != null && (wifiInfo.ip.isEmpty || wifiInfo.ip == 'x.x.x.x')) {
      return NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: l10n.netTitleInternetUnreachable,
        summary: l10n.netSummaryDeviceNotConnectedRouter,
        description: l10n.netDescNoLocalLinkCheck,
        troubleshootingSteps: [
          l10n.netStepFirstConnectLocal,
          l10n.netStepInternetCheckAgain,
        ],
        details: {
          l10n.netDetailTargetHost: target,
          l10n.netDetailLocalStatus: l10n.netValueDisconnectedFromLocal,
        },
        targetHost: target,
      );
    }

    // In test/integration-test mode skip real network probes so that
    // pumpAndSettle() can complete without timing out.
    if (globals.testingActive) {
      return NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: l10n.netTitleCheckSkippedTestMode,
        summary: l10n.netSummaryProbesDisabledTests,
        description: l10n.netDescProbesDisabledTests,
        details: {l10n.netDetailTargetHost: 'skipped'},
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
        l10n.netDetailTestTarget: target,
      };
      if (latency != null) {
        details[l10n.netDetailPingLatency] = '${latency.inMilliseconds} ms';
      }

      return NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.connected,
        title: l10n.netTitleRouterConnected,
        summary: latency != null
            ? l10n.netSummaryInternetReachableMs('${latency.inMilliseconds}')
            : l10n.netSummaryInternetReachable,
        description: l10n.netDescRouterConnected(target),
        latency: latency,
        targetHost: target,
        details: details,
      );
    }

    final details = <String, String>{
      l10n.netDetailTestTarget: target,
      l10n.netDetailConnectionStatus: l10n.netValueHostUnreachable,
    };

    return NetworkConnectionStatus(
      type: NetworkConnectionType.routerToInternet,
      state: NetworkConnectionState.disconnected,
      title: l10n.netTitleRouterDisconnected,
      summary: l10n.netSummaryUnableToReachServers,
      description: l10n.netDescRouterDisconnected(target),
      troubleshootingSteps: [
        l10n.netStepCheckWAN,
        l10n.netStepPowerCycle,
        l10n.netStepIspOutage,
        l10n.netStepPppoeDns,
      ],
      details: details,
      targetHost: target,
    );
  }
}
