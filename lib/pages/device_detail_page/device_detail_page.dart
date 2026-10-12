import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/port.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

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
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceMake = DeviceUtil.getDeviceMake(device);
    final iconData = DeviceUtil.getIconData(device);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.deviceDetailPageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Device identity header
          _buildHeaderCard(device, deviceMake, iconData, theme, colorScheme),
          const SizedBox(height: 12),

          // Network information card
          _buildNetworkInfoCard(device, theme, colorScheme),
          const SizedBox(height: 12),

          // Quick actions card
          _buildActionsCard(device, deviceMake, colorScheme),
          const SizedBox(height: 12),

          // Port scan results card
          _buildPortScanCard(theme, colorScheme),
        ],
      ),
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
                    deviceMake ?? 'Unknown device',
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
              tooltip: 'Copy IP address',
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(
                device.internetAddress,
                'IP address',
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
                'Network information',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            _buildInfoRow(
              context,
              icon: Icons.lan,
              label: 'IP address',
              value: device.internetAddress,
              onCopy: () => _copyToClipboard(
                device.internetAddress,
                'IP address',
              ),
            ),
            if (device.macAddress != null && device.macAddress!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.perm_device_information,
                label: 'MAC address',
                value: device.macAddress!,
                onCopy: () => _copyToClipboard(
                  device.macAddress!,
                  'MAC address',
                ),
              ),
            if (device.hostMake != null && device.hostMake!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.business,
                label: 'Vendor / Hostname',
                value: device.hostMake!,
              ),
            if (device.mdnsDomainName != null &&
                device.mdnsDomainName!.isNotEmpty)
              _buildInfoRow(
                context,
                icon: Icons.dns,
                label: 'mDNS name',
                value: device.mdnsDomainName!,
                onCopy: () => _copyToClipboard(
                  device.mdnsDomainName!,
                  'mDNS name',
                ),
              ),
            _buildInfoRow(
              context,
              icon: Icons.router,
              label: 'Gateway',
              value: device.gatewayIp,
            ),
          ],
        ),
      ),
    );
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
              tooltip: 'Copy $label',
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
              'Actions',
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
                  label: const Text('Full port scan'),
                ),
                ElevatedButton.icon(
                  key: WidgetKey.deviceDetailQuickScanButton.key,
                  onPressed: _portScanRunning ? null : _startQuickPortScan,
                  icon: const Icon(Icons.flash_on),
                  label: Text(
                    _portScanRunning ? 'Scanning...' : 'Quick scan',
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
                  label: const Text('Ping'),
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
                    label: const Text('Wake on LAN'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortScanCard(ThemeData theme, ColorScheme colorScheme) {
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
                      'Open ports',
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tap "Quick scan" to check for common open ports on this device.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (_portScanCompleted && _openPorts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No open ports found on common services.',
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
                      return AdaptiveListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: Text(
                          '${openPort.port}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.secondary,
                          ),
                        ),
                        title: Text(
                          port?.desc ?? 'Port ${openPort.port}',
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
                  'Found ${_openPorts.length} open '
                  'port${_openPorts.length == 1 ? '' : 's'}',
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
