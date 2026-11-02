import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_card.dart';
import 'package:vernet/pages/speed_test/speed_test_page.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/repository/wifi_repository.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/services/network_connectivity_service.dart';
import 'package:vernet/ui/adaptive/adaptive_circular_progress_bar.dart';
import 'package:vernet/ui/network_troubleshoot_dialog.dart';
import 'package:vernet/ui/timestamp_chip.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.connectivityService,
    this.wifiInfoLoader,
  });

  final NetworkConnectivityService? connectivityService;
  final Future<WifiInfo?> Function({bool force})? wifiInfoLoader;

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<HomePage> {
  WifiInfo? _wifiInfo;
  Future<WifiInfo?>? _wifiInfoFuture;
  late final NetworkConnectivityService _connectivityService;
  Future<NetworkConnectionStatus>? _internetStatusFuture;
  bool _isRefreshingWifi = false;
  bool _hasRunStartupScan = false;
  bool scanRunning = false;
  final Map<int, DeviceData> devices = {};
  Timer? _deviceRefreshTimer;
  late final NetworkScoreBloc _networkScoreBloc;
  DateTime? _lastConnectionCheck;

  /// Discovery emits a placeholder and then an updated row per host. Rebuilding
  /// the whole dashboard for each event drops frames, so coalesce the updates.
  void _scheduleDeviceRefresh() {
    _deviceRefreshTimer ??= Timer(const Duration(milliseconds: 250), () {
      _deviceRefreshTimer = null;
      if (mounted) setState(() {});
    });
  }

  Future<WifiInfo?> _getWifiInfo({bool force = false}) async {
    if (widget.wifiInfoLoader != null) {
      return _wifiInfo = await widget.wifiInfoLoader!(force: force);
    }
    if (_wifiInfo != null && !force) {
      return _wifiInfo;
    }
    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    final wifiIP = await NetworkInfo().getWifiIP();
    final wifiBSSID = await NetworkInfo().getWifiBSSID();
    final wifiName = await NetworkInfo().getWifiName();
    String? wifiGatewayIP;
    try {
      wifiGatewayIP = await NetworkInfo().getWifiGatewayIP();
    } catch (e) {
      debugPrint('Unimplemented error $e');
    }
    final gatewayIp = appSettings.customSubnet.isNotEmpty
        ? appSettings.customSubnet
        : (wifiGatewayIP ?? wifiIP) ?? '';
    final isCustomGateway = appSettings.customSubnet.isNotEmpty;
    final bool isLocationOn = (Platform.isAndroid || Platform.isIOS) &&
        await Permission.location.serviceStatus.isEnabled;
    final metrics = await WifiRepository.fetchWifiMetrics();
    final hasValidConnection =
        wifiIP != null && wifiIP != 'x.x.x.x' && wifiIP.isNotEmpty;
    _wifiInfo = WifiInfo(wifiIP, wifiBSSID, wifiName, !hasValidConnection,
        gatewayIp, isLocationOn, metrics,
        isCustomGateway: isCustomGateway);

    if (appSettings.runScanOnStartup && wifiIP != null && !_hasRunStartupScan) {
      setState(() {
        _hasRunStartupScan = true;
        scanRunning = true;
      });
      getIt<DeviceScannerService>()
          .startNewScan(_wifiInfo!.subnet, wifiIP, gatewayIp)
          .listen((device) {
        if (!mounted) return;
        devices[device.id] = device;
        _scheduleDeviceRefresh();
      }).onDone(() async {
        _deviceRefreshTimer?.cancel();
        _deviceRefreshTimer = null;
        if (mounted) {
          setState(() {
            scanRunning = false;
          });
        }
        await NotificationService.showNotificationWithActions(
          deviceCount: devices.length,
        );
      });
    }

    return _wifiInfo;
  }

  void _startNetworkPipeline({bool force = false}) {
    setState(() {
      if (force) {
        devices.clear();
        _hasRunStartupScan = false;
      }
      _wifiInfoFuture = _getWifiInfo(force: force);
      _internetStatusFuture = _loadInternetStatusAfterWifi(_wifiInfoFuture!);
    });
  }

  Future<void> _refreshWifiInfo() async {
    if (_isRefreshingWifi) return;
    setState(() {
      _isRefreshingWifi = true;
    });
    try {
      _startNetworkPipeline(force: true);
      await _wifiInfoFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingWifi = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _deviceRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _connectivityService =
        widget.connectivityService ?? NetworkConnectivityService();
    _networkScoreBloc = getIt<NetworkScoreBloc>()
      ..add(const NetworkScoreEvent.loadCached());
    _startNetworkPipeline();
  }

  Future<NetworkConnectionStatus> _loadInternetStatusAfterWifi(
    Future<WifiInfo?> wifiFuture,
  ) async {
    final wifiInfo = await wifiFuture;
    if (wifiInfo == null || !_isConnected(wifiInfo)) {
      if (mounted) {
        setState(() {
          _lastConnectionCheck = DateTime.now();
        });
      }
      return const NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: 'Internet Unreachable (No Local Link)',
        summary: 'Not connected to Wi-Fi / router',
        description:
            'Your device is not connected to any Wi-Fi router or local network interface. An active local network connection is required before internet connectivity can be checked.',
        troubleshootingSteps: [
          'Connect to a Wi-Fi network or plug in an Ethernet cable.',
          'Verify that Wi-Fi is enabled in your device settings.',
          'Once connected to the router, internet connectivity will be tested automatically.',
        ],
        details: {
          'Wi-Fi / Interface Status': 'Disconnected',
          'Internet Status': 'Unreachable',
        },
      );
    }

    // Only if Wi-Fi or interface is connected: check connection to internet service
    final status = await _connectivityService.checkRouterToInternet(
      wifiInfo: wifiInfo,
    );

    if (mounted) {
      setState(() {
        _lastConnectionCheck = DateTime.now();
      });
    }

    return status;
  }

  void _showStatusDialog(BuildContext context, NetworkConnectionStatus status) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => NetworkTroubleshootDialog(status: status),
    );
  }

  Future<void> _refreshDashboard() async {
    _scoreComputeScheduled = false;
    await _refreshWifiInfo();
  }

  bool _isConnected(WifiInfo info) => info.ip != 'x.x.x.x';

  void _openHostScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HostScanPage()),
    );
  }

  void _openScanHistory() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const ScanHistoryPage()),
    );
  }

  Widget _buildWifiPanel(BuildContext context, WifiInfo info,
      {bool isChecking = false}) {
    final colors = Theme.of(context).colorScheme;
    final level = info.metrics.normalizedLevel.clamp(0, 4);
    final connected = _isConnected(info);
    final signalColor = level >= 3 ? Colors.green : Colors.amber;
    final signalDescription = isChecking
        ? 'Measuring signal…'
        : info.metrics.rawRssi != null && level > 0
            ? '${info.metrics.statusMessage} · ${info.metrics.rawRssi} ${StringValue.signalStrengthUnit}'
            : connected
                ? info.metrics.statusMessage
                : 'Signal unavailable';

    return _OverviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PanelIcon(icon: Icons.wifi, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'WI-FI CONNECTION',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (scanRunning) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: AdaptiveCircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              _StatusPill(
                label: isChecking
                    ? 'CHECKING…'
                    : connected
                        ? 'CONNECTED'
                        : 'NOT CONNECTED',
                color: isChecking
                    ? colors.onSurfaceVariant
                    : connected
                        ? colors.primary
                        : colors.error,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SignalStrengthIndicator.sector(
                value: level <= 0 ? 0 : (level - 0.5) / 4,
                size: 30,
                barCount: 4,
                minValue: 0,
                maxValue: 1,
                activeColor: signalColor,
                inactiveColor: colors.outlineVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signal strength',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      signalDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NetworkValue(
                  label: 'DEVICE IP',
                  value: isChecking ? 'Checking…' : info.ip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NetworkValue(
                  label: 'GATEWAY',
                  value: isChecking
                      ? 'Checking…'
                      : (info.gatewayIp.isEmpty
                          ? 'Unavailable'
                          : info.gatewayIp),
                  badge: !isChecking &&
                          info.isCustomGateway &&
                          info.gatewayIp.isNotEmpty
                      ? const _CustomValueBadge()
                      : null,
                ),
              ),
            ],
          ),
          if (info.bssid != WifiInfo.defaultBSSID.first) ...[
            const SizedBox(height: 12),
            _NetworkValue(label: 'ACCESS POINT', value: info.bssid),
          ],
          if (!info.isLocationOn && (Platform.isAndroid || Platform.isIOS)) ...[
            const SizedBox(height: 12),
            Text(
              'Allow location access to show the Wi-Fi name.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: WidgetKey.scanForDevicesButton.key,
                  onPressed: _openHostScan,
                  icon: scanRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar),
                  label: Text(
                    scanRunning
                        ? 'Scanning your network…'
                        : appSettings.runScanOnStartup && devices.isNotEmpty
                            ? '${devices.length} devices found'
                            : 'Scan your network',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                key: WidgetKey.scanHistoryIconButton.key,
                tooltip: StringValue.previousScansTitle,
                onPressed: _openScanHistory,
                icon: const Icon(Icons.history),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTestPanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<SpeedSnapshot?>(
      future: NetworkScoreRepository().loadSpeedSnapshot(),
      builder: (context, snapshot) {
        final speedData = snapshot.data;
        final hasData = speedData != null && speedData.downloadMbps > 0;
        final testTimestamp = speedData?.timestamp;

        return _OverviewPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _PanelIcon(icon: Icons.speed, color: colors.tertiary),
                  Text(
                    'SPEED TEST',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (testTimestamp != null)
                    TimestampChip(timestamp: testTimestamp),
                ],
              ),
              const SizedBox(height: 14),
              if (hasData) ...[
                // Download speed
                Row(
                  children: [
                    Icon(
                      Icons.download,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Download',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${speedData.downloadMbps.toStringAsFixed(1)} Mbps',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Upload speed
                Row(
                  children: [
                    Icon(
                      Icons.upload,
                      size: 20,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${speedData.uploadMbps.toStringAsFixed(1)} Mbps',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.tertiary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Latency with color coding
                Row(
                  children: [
                    Icon(
                      Icons.network_ping,
                      size: 20,
                      color: _getLatencyColor(speedData.latencyMs, colors),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Latency',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${speedData.latencyMs.toStringAsFixed(0)} ms',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                _getLatencyColor(speedData.latencyMs, colors),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // M-Lab attribution
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Powered by M-Lab',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.download, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text('Download',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                        const Spacer(),
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                              sigmaX: 6, sigmaY: 6, tileMode: TileMode.clamp),
                          child: Text('00.0 Mbps',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.upload, size: 20, color: colors.tertiary),
                        const SizedBox(width: 8),
                        Text('Upload',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                        const Spacer(),
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                              sigmaX: 6, sigmaY: 6, tileMode: TileMode.clamp),
                          child: Text('0.0 Mbps',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.tertiary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.network_ping,
                            size: 20, color: colors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Latency',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                        const Spacer(),
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                              sigmaX: 6, sigmaY: 6, tileMode: TileMode.clamp),
                          child: Text('00 ms',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SpeedTestPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text(hasData ? 'Run New Test' : 'Start Speed Test'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLatencyColor(double latencyMs, ColorScheme colors) {
    if (latencyMs < 20) {
      return const Color(0xFF4CAF50); // Green - excellent
    } else if (latencyMs < 50) {
      return const Color(0xFF8BC34A); // Light green - good
    } else if (latencyMs < 100) {
      return const Color(0xFFFFC107); // Yellow/amber - fair
    } else if (latencyMs < 200) {
      return const Color(0xFFFF9800); // Orange - poor
    } else {
      return const Color(0xFFF44336); // Red - very poor
    }
  }

  Widget _buildConnectionPath(
    BuildContext context,
    WifiInfo wifiInfo,
    NetworkConnectionStatus? internetStatus,
    bool isWide, {
    bool isWifiChecking = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final nodes = [
      _RouteData(
        Icons.devices,
        'THIS DEVICE',
        isWifiChecking
            ? 'Checking…'
            : (wifiInfo.ip.isEmpty || wifiInfo.ip == 'x.x.x.x'
                ? 'Unavailable'
                : wifiInfo.ip),
      ),
      _RouteData(
        Icons.router_outlined,
        'WI-FI ROUTER',
        isWifiChecking
            ? 'Checking…'
            : (wifiInfo.gatewayIp.isEmpty ? 'Unavailable' : wifiInfo.gatewayIp),
        badge: !isWifiChecking &&
                wifiInfo.isCustomGateway &&
                wifiInfo.gatewayIp.isNotEmpty
            ? const _CustomValueBadge()
            : null,
      ),
      _RouteData(
        Icons.cloud_outlined,
        'INTERNET',
        isWifiChecking
            ? 'Checking…'
            : (internetStatus?.isConnected == true
                ? 'Connected'
                : internetStatus?.isChecking == true
                    ? 'Checking…'
                    : 'Disconnected'),
      ),
    ];

    final NetworkConnectionStatus deviceToRouterStatus;
    if (isWifiChecking) {
      deviceToRouterStatus = const NetworkConnectionStatus(
        type: NetworkConnectionType.deviceToRouter,
        state: NetworkConnectionState.checking,
        title: 'Checking Device to Router Link',
        summary: 'Checking Wi-Fi / interface…',
        description:
            'Detecting your local network interface and verifying the connection to your Wi-Fi router or gateway.',
      );
    } else {
      deviceToRouterStatus = _connectivityService.checkDeviceToRouter(wifiInfo);
    }

    final NetworkConnectionStatus routerToInternetStatus;
    if (deviceToRouterStatus.isChecking) {
      routerToInternetStatus = const NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.checking,
        title: 'Waiting for Wi-Fi Connection…',
        summary: 'Waiting for Wi-Fi / LAN connection…',
        description:
            'We must first establish a connection to your Wi-Fi router or local network interface before checking internet connectivity.',
      );
    } else if (deviceToRouterStatus.isDisconnected) {
      routerToInternetStatus = const NetworkConnectionStatus(
        type: NetworkConnectionType.routerToInternet,
        state: NetworkConnectionState.disconnected,
        title: 'Internet Unreachable (No Local Link)',
        summary: 'Not connected to Wi-Fi / router',
        description:
            'Your device is not connected to any Wi-Fi router or local network interface. An active local network connection is required before internet connectivity can be checked.',
        troubleshootingSteps: [
          'Connect to a Wi-Fi network or plug in an Ethernet cable.',
          'Verify that Wi-Fi is enabled in your device settings.',
          'Once connected to the router, internet connectivity will be tested automatically.',
        ],
        details: {
          'Wi-Fi / Interface Status': 'Disconnected',
          'Internet Status': 'Unreachable',
        },
      );
    } else {
      routerToInternetStatus = internetStatus ??
          const NetworkConnectionStatus(
            type: NetworkConnectionType.routerToInternet,
            state: NetworkConnectionState.checking,
            title: 'Checking Internet Connection…',
            summary: 'Checking connection to internet…',
            description:
                'Testing connection between your router and internet hosts.',
          );
    }

    final connectors = [
      _ConnectionSegmentData(
        key: WidgetKey.deviceToRouterConnector.key,
        status: deviceToRouterStatus,
      ),
      _ConnectionSegmentData(
        key: WidgetKey.routerToInternetConnector.key,
        status: routerToInternetStatus,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Icon(Icons.route, size: 18, color: colors.primary),
              Text(
                'CONNECTION PATH',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (_lastConnectionCheck != null)
                TimestampChip(timestamp: _lastConnectionCheck!),
            ],
          ),
          const SizedBox(height: 14),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < nodes.length; i++) ...[
                  Expanded(child: _RouteNode(data: nodes[i], centered: true)),
                  if (i < nodes.length - 1)
                    Expanded(
                      child: _HorizontalConnectionSegment(
                        key: connectors[i].key,
                        status: connectors[i].status,
                        onTap: () =>
                            _showStatusDialog(context, connectors[i].status),
                      ),
                    ),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < nodes.length; i++) ...[
                  _RouteNode(data: nodes[i]),
                  if (i < nodes.length - 1)
                    _VerticalConnectionSegment(
                      key: connectors[i].key,
                      status: connectors[i].status,
                      onTap: () =>
                          _showStatusDialog(context, connectors[i].status),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NetworkScoreBloc>.value(
      value: _networkScoreBloc,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final isPhonePlatform = Platform.isAndroid || Platform.isIOS;
          final isMobileLayout = isPhonePlatform || constraints.maxWidth < 600;
          final horizontalPath =
              !isPhonePlatform && constraints.maxWidth >= 480;
          final horizontalPadding = isWide ? 24.0 : 14.0;
          final verticalPadding = isWide ? 20.0 : 14.0;
          final topPadding = isMobileLayout ? 8.0 : verticalPadding;

          final content = RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: ListView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: topPadding,
                bottom: verticalPadding,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: FutureBuilder<WifiInfo?>(
                      future: _wifiInfoFuture ?? _getWifiInfo(),
                      builder: (context, wifiSnapshot) {
                        final wifiInfo = wifiSnapshot.data ??
                            WifiInfo(
                              null,
                              null,
                              null,
                              true,
                              '',
                              false,
                              WifiNetworkMetrics.disconnected(),
                            );
                        final isWifiChecking = _isRefreshingWifi ||
                            wifiSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            wifiSnapshot.data == null;

                        // Trigger score computation when data is available
                        if (!isWifiChecking && wifiSnapshot.hasData) {
                          _scheduleScoreCompute(
                            wifiInfo,
                            _internetStatusFuture,
                          );
                        }

                        return FutureBuilder<NetworkConnectionStatus>(
                          future: _internetStatusFuture,
                          builder: (context, internetSnapshot) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!isMobileLayout)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'NETWORK OVERVIEW',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    letterSpacing: 1.4,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Your network',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'A live view of your Wi-Fi and internet connection.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _refreshDashboard,
                                        icon: const Icon(Icons.refresh),
                                        tooltip: 'Refresh dashboard',
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                NetworkScoreCard(
                                  key: WidgetKey.networkScoreCard.key,
                                ),
                                const SizedBox(height: 16),
                                _buildConnectionPath(
                                  context,
                                  wifiInfo,
                                  internetSnapshot.data,
                                  horizontalPath,
                                  isWifiChecking: isWifiChecking,
                                ),
                                const SizedBox(height: 20),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildWifiPanel(
                                          context,
                                          wifiInfo,
                                          isChecking: isWifiChecking,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildSpeedTestPanel(context),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _buildWifiPanel(
                                        context,
                                        wifiInfo,
                                        isChecking: isWifiChecking,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildSpeedTestPanel(context),
                                    ],
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );

          return content;
        },
      ),
    );
  }

  bool _scoreComputeScheduled = false;

  void _scheduleScoreCompute(
    WifiInfo wifiInfo,
    Future<NetworkConnectionStatus>? internetStatusFuture,
  ) {
    // Only compute score once, but ensure it uses fresh data
    if (_scoreComputeScheduled) return;
    _scoreComputeScheduled = true;

    internetStatusFuture?.then((status) {
      if (mounted) {
        // Compute event will update the cache and compute the score
        _networkScoreBloc.add(NetworkScoreEvent.compute(
          wifiInfo: wifiInfo,
          connectivityStatus: status,
        ));
      }
    });
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withAlpha(120)),
      ),
      child: child,
    );
  }
}

class _PanelIcon extends StatelessWidget {
  const _PanelIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _NetworkValue extends StatelessWidget {
  const _NetworkValue({required this.label, required this.value, this.badge});

  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              badge!,
            ],
          ],
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CustomValueBadge extends StatelessWidget {
  const _CustomValueBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'CUSTOM',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onTertiaryContainer,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _RouteData {
  const _RouteData(this.icon, this.label, this.value, {this.badge});

  final IconData icon;
  final String label;
  final String value;
  final Widget? badge;
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.data, this.centered = false});

  final _RouteData data;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(data.icon, size: 15, color: colors.onPrimaryContainer),
    );
    final details = Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (data.badge != null) ...[
              const SizedBox(width: 6),
              data.badge!,
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );

    if (centered) {
      return Column(
        children: [
          icon,
          const SizedBox(height: 7),
          details,
        ],
      );
    }
    return Row(
      children: [
        icon,
        const SizedBox(width: 10),
        Expanded(child: details),
      ],
    );
  }
}

class _ConnectionSegmentData {
  const _ConnectionSegmentData({required this.key, required this.status});
  final Key key;
  final NetworkConnectionStatus status;
}

class _HorizontalConnectionSegment extends StatelessWidget {
  const _HorizontalConnectionSegment({
    super.key,
    required this.status,
    required this.onTap,
  });

  final NetworkConnectionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isConnected = status.isConnected;
    final isChecking = status.isChecking;

    final statusColor = isChecking
        ? colors.onSurfaceVariant
        : isConnected
            ? Colors.green
            : colors.error;

    final iconData = isChecking
        ? Icons.sync
        : isConnected
            ? Icons.check_circle
            : Icons.cancel;

    final label = status.label;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: 'Network status: $label. Tap to view details.',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 26,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: isChecking
                              ? colors.outlineVariant.withAlpha(120)
                              : isConnected
                                  ? Colors.green.withAlpha(150)
                                  : colors.error.withAlpha(150),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withAlpha(180),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isChecking
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: statusColor,
                                  ),
                                )
                              : Icon(
                                  iconData,
                                  size: 16,
                                  color: statusColor,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalConnectionSegment extends StatelessWidget {
  const _VerticalConnectionSegment({
    super.key,
    required this.status,
    required this.onTap,
  });

  final NetworkConnectionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isConnected = status.isConnected;
    final isChecking = status.isChecking;

    final statusColor = isChecking
        ? colors.onSurfaceVariant
        : isConnected
            ? Colors.green
            : colors.error;

    final iconData = isChecking
        ? Icons.sync
        : isConnected
            ? Icons.check_circle
            : Icons.cancel;

    final label = status.label;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: 'Network status: $label. Tap to view details.',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: isChecking
                              ? colors.outlineVariant.withAlpha(120)
                              : isConnected
                                  ? Colors.green.withAlpha(150)
                                  : colors.error.withAlpha(150),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withAlpha(180),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isChecking
                              ? SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: statusColor,
                                  ),
                                )
                              : Icon(
                                  iconData,
                                  size: 14,
                                  color: statusColor,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: colors.onSurfaceVariant.withAlpha(160),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
