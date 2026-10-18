import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';
import 'package:speed_test_dart/classes/settings.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/isp_page/isp_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/repository/wifi_repository.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/services/isp_lookup_service.dart';
import 'package:vernet/ui/speed_test_dialog.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _WifiDetailState createState() => _WifiDetailState();
}

class _WifiDetailState extends State<HomePage> {
  WifiInfo? _wifiInfo;
  Future<WifiInfo?>? _wifiInfoFuture;
  bool _isRefreshingWifi = false;
  bool _hasRunStartupScan = false;
  bool _hasCompletedStartupScan = false;
  bool scanRunning = false;
  Set<DeviceData> devices = {};
  SpeedTestDart tester = SpeedTestDart();
  final IspLookupService _ispLookupService = IspLookupService();
  late Future<Settings?> _ispSettingsFuture;

  Future<WifiInfo?> _getWifiInfo({bool force = false}) async {
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
    final bool isLocationOn = (Platform.isAndroid || Platform.isIOS) &&
        await Permission.location.serviceStatus.isEnabled;
    final metrics = await WifiRepository.fetchWifiMetrics();
    _wifiInfo = WifiInfo(wifiIP, wifiBSSID, wifiName, wifiName == null,
        gatewayIp, isLocationOn, metrics);

    if (appSettings.runScanOnStartup && wifiIP != null && !_hasRunStartupScan) {
      setState(() {
        _hasRunStartupScan = true;
        scanRunning = true;
      });
      getIt<DeviceScannerService>()
          .startNewScan(_wifiInfo!.subnet, wifiIP, gatewayIp)
          .listen((device) {
        if (mounted) {
          setState(() {
            devices.add(device);
          });
        }
      }).onDone(() async {
        if (mounted) {
          setState(() {
            scanRunning = false;
            _hasCompletedStartupScan = true;
          });
        }
        await NotificationService.showNotificationWithActions();
      });
    }

    return _wifiInfo;
  }

  Future<void> _refreshWifiInfo() async {
    if (_isRefreshingWifi) return;
    setState(() {
      devices.clear();
      _hasRunStartupScan = false;
      _hasCompletedStartupScan = false;
      _isRefreshingWifi = true;
    });
    try {
      _wifiInfoFuture = _getWifiInfo(force: true);
      await _wifiInfoFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingWifi = false;
        });
      }
    }
  }

  void _configureSelectNotificationSubject() {
    NotificationService.selectNotificationStream.stream.listen((
      String? payload,
    ) async {
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/hostscan', ModalRoute.withName('/'));
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshWifiInfo();
    _ispSettingsFuture = _loadIspSettings();
    _configureSelectNotificationSubject();
  }

  Future<Settings?> _loadIspSettings() async {
    if (!appSettings.inAppInternet) return null;
    final settings =
        await tester.getSettings(headers: {"User-Agent": "Mozilla/4.0"});
    if (settings.client.isp.trim().isEmpty ||
        settings.client.isp.toLowerCase() == 'unknown') {
      final isp = await _ispLookupService.lookup(settings.client.ip);
      if (isp != null) settings.client.isp = isp;
    }
    return settings;
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _ispSettingsFuture = _loadIspSettings();
    });
    await _refreshWifiInfo();
  }

  bool _isConnected(WifiInfo info) => info.ip != 'x.x.x.x';

  void _openHostScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HostScanPage()),
    );
  }

  Widget _buildWifiPanel(BuildContext context, WifiInfo info) {
    final colors = Theme.of(context).colorScheme;
    final level = info.metrics.normalizedLevel.clamp(0, 4);
    final connected = _isConnected(info);
    final signalColor = level >= 3 ? colors.primary : colors.tertiary;
    final signalDescription = info.metrics.rawRssi != null && level > 0
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
              _StatusPill(
                label: connected ? 'CONNECTED' : 'NOT CONNECTED',
                color: connected ? colors.primary : colors.error,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            info.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
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
                  child: _NetworkValue(label: 'DEVICE IP', value: info.ip)),
              const SizedBox(width: 12),
              Expanded(
                child: _NetworkValue(
                  label: 'GATEWAY',
                  value:
                      info.gatewayIp.isEmpty ? 'Unavailable' : info.gatewayIp,
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
          SizedBox(
            width: double.infinity,
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
                    : appSettings.runScanOnStartup &&
                            _hasRunStartupScan &&
                            _hasCompletedStartupScan
                        ? '${devices.length} devices found'
                        : 'Scan your network',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIspPanel(
    BuildContext context,
    AsyncSnapshot<Settings?> snapshot,
  ) {
    final colors = Theme.of(context).colorScheme;
    final settings = snapshot.data;

    return _OverviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PanelIcon(icon: Icons.public, color: colors.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'INTERNET SERVICE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _StatusPill(
                label: appSettings.inAppInternet ? 'PROVIDER LOOKUP' : 'PAUSED',
                color: appSettings.inAppInternet
                    ? colors.tertiary
                    : colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!appSettings.inAppInternet)
            const _IspMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Internet lookups are off',
              message:
                  'Turn on internet access in Settings to see provider details.',
            )
          else if (settings != null) ...[
            Text(
              settings.client.isp,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _NetworkValue(
                label: 'PUBLIC IP ADDRESS', value: settings.client.ip),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => SpeedTestDialog(
                        tester: tester,
                        servers: settings.servers,
                        odometerStart: settings.odometer.start / 100000000,
                      ),
                    );
                  },
                  icon: const Icon(Icons.speed),
                  label: const Text('Test internet speed'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            IspPage(tester: tester, settings: settings),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_outward),
                  label: const Text('Provider details'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              StringValue.speedTestServer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ] else if (snapshot.hasError)
            const _IspMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Provider details unavailable',
              message:
                  'Check your internet connection and refresh to try again.',
            )
          else
            const _IspMessage(
              icon: Icons.language,
              title: 'Finding your provider…',
              message: 'Looking up your public IP and ISP details.',
              showProgress: true,
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionPath(
    BuildContext context,
    WifiInfo wifiInfo,
    AsyncSnapshot<Settings?> ispSnapshot,
    bool isWide,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isp = ispSnapshot.data?.client.isp ??
        (appSettings.inAppInternet
            ? ispSnapshot.hasError
                ? 'Details unavailable'
                : 'Looking up provider…'
            : 'Lookup paused');
    final nodes = [
      _RouteData(Icons.devices, 'THIS DEVICE', wifiInfo.ip),
      _RouteData(
        Icons.router_outlined,
        'WI-FI ROUTER',
        wifiInfo.gatewayIp.isEmpty ? 'Unavailable' : wifiInfo.gatewayIp,
      ),
      _RouteData(Icons.cloud_outlined, 'INTERNET PROVIDER', isp),
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
          Row(
            children: [
              Icon(Icons.route, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'CONNECTION PATH',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
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
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 17, left: 6, right: 6),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(150),
                                colors.tertiary.withAlpha(150),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 18,
                        width: 2,
                        margin: const EdgeInsets.only(left: 21),
                        color: colors.outlineVariant,
                      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final isPhonePlatform = Platform.isAndroid || Platform.isIOS;
        final horizontalPath = !isPhonePlatform && constraints.maxWidth >= 480;
        final horizontalPadding = isWide ? 24.0 : 14.0;
        final verticalPadding = isWide ? 20.0 : 14.0;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: FutureBuilder<WifiInfo?>(
                  future: _wifiInfoFuture ?? _getWifiInfo(),
                  initialData: WifiInfo(
                    null,
                    null,
                    null,
                    true,
                    '',
                    false,
                    WifiNetworkMetrics.disconnected(),
                  ),
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
                    return FutureBuilder<Settings?>(
                      future: _ispSettingsFuture,
                      builder: (context, ispSnapshot) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isPhonePlatform || constraints.maxWidth < 600)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton.filledTonal(
                                      tooltip: 'Refresh network information',
                                      onPressed: _refreshDashboard,
                                      icon: _isRefreshingWifi
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh),
                                    ),
                                  ),
                                  Text(
                                    'NETWORK OVERVIEW',
                                    textAlign: TextAlign.center,
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
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'A live view of your Wi-Fi and internet connection.',
                                    textAlign: TextAlign.center,
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
                              )
                            else
                              Row(
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
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Refresh network information',
                                    onPressed: _refreshDashboard,
                                    icon: _isRefreshingWifi
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            _buildConnectionPath(
                              context,
                              wifiInfo,
                              ispSnapshot,
                              horizontalPath,
                            ),
                            const SizedBox(height: 20),
                            if (isWide)
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildWifiPanel(context, wifiInfo),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child:
                                          _buildIspPanel(context, ispSnapshot),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              _buildWifiPanel(context, wifiInfo),
                              const SizedBox(height: 12),
                              _buildIspPanel(context, ispSnapshot),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
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
  const _NetworkValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
              ),
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

class _IspMessage extends StatelessWidget {
  const _IspMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: colors.onSurfaceVariant),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        if (showProgress) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

class _RouteData {
  const _RouteData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
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
        Text(
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
