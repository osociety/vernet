import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/port.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

/// A detail page that displays comprehensive information about a discovered
/// network device and provides quick actions (port scan, ping, Wake-on-LAN).
class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({
    super.key,
    required this.device,
    this.autoScan = false,
  });

  final DeviceData device;
  final bool autoScan;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final Set<OpenPort> _openPorts = {};
  bool _portScanRunning = false;
  bool _portScanCompleted = false;
  StreamSubscription<ActiveHost>? _portScanSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.autoScan) {
      Future.delayed(Durations.short2, _startQuickPortScan);
    }
  }

  @override
  void dispose() {
    _portScanSubscription?.cancel();
    super.dispose();
  }

  void _startQuickPortScan() {
    setState(() {
      _openPorts.clear();
      _portScanRunning = true;
      _portScanCompleted = false;
    });

    _portScanSubscription = PortScannerService.instance
        .customDiscover(
      widget.device.internetAddress,
      timeout: Duration(milliseconds: appSettings.socketTimeout),
      async: true,
    )
        .listen(
      (host) {
        if (host.openPorts.isNotEmpty) {
          setState(() {
            _openPorts.addAll(host.openPorts);
          });
        }
      },
      onDone: () {
        setState(() {
          _portScanRunning = false;
          _portScanCompleted = true;
        });
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.deviceDetailCopied(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceMake =
        DeviceUtil.makeLabel(context.l10n, DeviceUtil.getDeviceMake(device));
    final iconData = DeviceUtil.getIconData(device);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.deviceDetailPageTitle),
      ),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Device identity header
          _buildHeaderCard(device, deviceMake, iconData, theme, colorScheme),
          const SizedBox(height: 12),

          // Network information card
          _buildNetworkInfoCard(device, theme, colorScheme),
          const SizedBox(height: 12),

          // Open ports card
          if (device.openPorts != null && device.openPorts!.isNotEmpty)
            _buildOpenPortsCard(device, theme, colorScheme),
          if (device.openPorts != null && device.openPorts!.isNotEmpty)
            const SizedBox(height: 12),

          // Quick actions card
          _buildActionsCard(device, deviceMake, colorScheme),
          const SizedBox(height: 12),

          // Port scan results card
          _buildPortScanCard(theme, colorScheme),
        ],
      )),
    );
  }

  Widget _buildHeaderCard(
    DeviceData device,
    String? deviceMake,
    IconData iconData,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                iconData,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key: WidgetKey.deviceDetailName.key,
                    deviceMake ?? context.l10n.deviceDetailUnknownDevice,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    key: WidgetKey.deviceDetailIp.key,
                    device.internetAddress,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.deviceDetailCopyIp,
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(
                device.internetAddress,
                context.l10n.deviceDetailIpAddress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfoCard(
    DeviceData device,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.deviceDetailNetworkInfo,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            _buildInfoRow(
              context,
              icon: Icons.lan,
              label: context.l10n.deviceDetailIpAddress,
              value: device.internetAddress,
              onCopy: () => _copyToClipboard(
                device.internetAddress,
                context.l10n.deviceDetailIpAddress,
              ),
            ),
            if (device.macAddress != null && device.macAddress!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.perm_device_information,
                label: context.l10n.deviceDetailMacAddress,
                value: device.macAddress!,
                onCopy: () => _copyToClipboard(
                  device.macAddress!,
                  context.l10n.deviceDetailMacAddress,
                ),
              ),
            if (device.vendorName != null && device.vendorName!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.business,
                label: context.l10n.deviceDetailVendor,
                value: device.vendorName!,
              ),
            if (device.hostMake != null && device.hostMake!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.label,
                label: context.l10n.deviceDetailHostname,
                value: device.hostMake!,
              ),
            if (device.deviceType != null && device.deviceType!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.category,
                label: context.l10n.deviceDetailDeviceType,
                value: DeviceUtil.typeLabel(context.l10n, device.deviceType!),
              ),
            if (device.mdnsDomainName != null &&
                device.mdnsDomainName!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.dns,
                label: context.l10n.deviceDetailMdnsName,
                value: device.mdnsDomainName!,
                onCopy: () => _copyToClipboard(
                  device.mdnsDomainName!,
                  context.l10n.deviceDetailMdnsName,
                ),
              ),
            _buildInfoRow(
              context,
              icon: Icons.router,
              label: context.l10n.deviceDetailGateway,
              value: device.gatewayIp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenPortsCard(
    DeviceData device,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final ports = device.openPorts!
        .split(',')
        .where((p) => p.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.deviceDetailOpenPortsCount('${ports.length}'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...ports.map((port) => _buildPortRow(context, port)),
          ],
        ),
      ),
    );
  }

  /// The side of the square that `CupertinoListTile` fits its `leading` into.
  ///
  /// `ListTile` sizes that slot from the widget itself and ignores this, so the
  /// Material branch is untouched. Measuring the text instead of picking a
  /// constant is what keeps a five-digit port legible at a large text scale,
  /// which is what clipped it at three digits before.
  double _leadingBoxWidth(
    BuildContext context,
    TextStyle? style,
    String text,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  Widget _buildPortRow(BuildContext context, int port) {
    final description = _portDescription(context.l10n, port);
    return AdaptiveListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.circle, size: 8),
      title: Text('$port'),
      subtitle: Text(description),
    );
  }

  String _portDescription(AppLocalizations l10n, int port) {
    return switch (port) {
      20 || 21 => l10n.portDescFtp,
      22 => l10n.portDescSsh,
      23 => l10n.portDescTelnet,
      25 => l10n.portDescSmtp,
      53 => l10n.portDescDns,
      80 => l10n.portDescHttp,
      110 => l10n.portDescPop3,
      143 => l10n.portDescImap,
      161 => l10n.portDescSnmp,
      443 => l10n.portDescHttps,
      445 => l10n.portDescSmb,
      587 => l10n.portDescSmtpSubmission,
      631 => l10n.portDescIpp,
      993 => l10n.portDescImaps,
      995 => l10n.portDescPop3s,
      3306 => l10n.portDescMysql,
      3389 => l10n.portDescRdp,
      5432 => l10n.portDescPostgres,
      5900 => l10n.portDescVnc,
      8080 => l10n.portDescHttpAlt,
      8443 => l10n.portDescHttpsAlt,
      9100 => l10n.portDescJetDirect,
      _ =>
        DeviceUtil.getPortDescription(port) ?? l10n.deviceDetailUnknownService,
    };
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return AdaptiveListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20),
      title: Text(label),
      subtitle: SelectableText(value),
      trailing: onCopy != null
          ? IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopy,
              tooltip: context.l10n.deviceDetailCopyLabel(label),
            )
          : null,
    );
  }

  Widget _buildActionsCard(
    DeviceData device,
    String? deviceMake,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.deviceDetailActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  key: WidgetKey.deviceDetailPortScanButton.key,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PortScanPage(
                          target: device.internetAddress,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.radar),
                  label: Text(context.l10n.deviceDetailFullScan),
                ),
                ElevatedButton.icon(
                  key: WidgetKey.deviceDetailQuickScanButton.key,
                  onPressed: _portScanRunning ? null : _startQuickPortScan,
                  icon: const Icon(Icons.flash_on),
                  label: Text(
                    _portScanRunning
                        ? context.l10n.deviceDetailScanning
                        : context.l10n.deviceDetailQuickScan,
                  ),
                ),
                ElevatedButton.icon(
                  key: WidgetKey.deviceDetailPingButton.key,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PingPage(
                          target: device.internetAddress,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.trending_up),
                  label: Text(context.l10n.deviceDetailPing),
                ),
                if (device.macAddress != null && device.macAddress!.isNotEmpty)
                  ElevatedButton.icon(
                    key: WidgetKey.deviceDetailWolButton.key,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WakeOnLanPage(
                            initialMacAddress: device.macAddress!,
                            initialIpv4Address:
                                WakeOnLanService.broadcastFromIpv4(
                                      device.internetAddress,
                                    ) ??
                                    WakeOnLanService.defaultBroadcast,
                            initialLabel: deviceMake ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(context.l10n.deviceDetailWakeOnLan),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _foundPortsLabel(AppLocalizations l10n, int count) => count == 1
      ? l10n.deviceDetailFoundPortsOne
      : l10n.deviceDetailFoundPortsMany('$count');

  Widget _buildPortScanCard(ThemeData theme, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.deviceDetailOpenPorts,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (_portScanRunning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!_portScanCompleted && _openPorts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.deviceDetailQuickScanHint,
                  textAlign: TextAlign.center,
                ),
              )
            else if (_portScanCompleted && _openPorts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.deviceDetailNoOpenPorts,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              )
            else
              FutureBuilder<Map<String, Port>>(
                future: PortDescLoader('assets/ports_lists.json').load(),
                builder: (context, snapshot) {
                  final allPorts = snapshot.data ?? <String, Port>{};
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _openPorts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final openPort = _openPorts.toList()[index];
                      final port = allPorts[openPort.port.toString()];
                      final portStyle = theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.secondary,
                      );
                      return AdaptiveListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leadingSize: _leadingBoxWidth(
                          context,
                          portStyle,
                          '${openPort.port}',
                        ),
                        leading: Text('${openPort.port}', style: portStyle),
                        title: Text(
                          port?.desc ??
                              l10n.deviceDetailPortNumber('${openPort.port}'),
                        ),
                        subtitle: port != null
                            ? Row(
                                children: [
                                  if (port.isTCP) const Text('TCP  '),
                                  if (port.isUDP) const Text('UDP  '),
                                  Text(port.status),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            if (_portScanCompleted && _openPorts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _foundPortsLabel(l10n, _openPorts.length),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
