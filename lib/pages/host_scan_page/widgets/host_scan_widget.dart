import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';
import 'package:vernet/values/tooltip_messages.dart';

class HostScanWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HostScanBloc, HostScanState>(
      listenWhen: (previous, current) =>
          previous is! LoadSuccess && current is LoadSuccess,
      listener: (context, state) {
        if (state is LoadSuccess) {
          final deviceCount = state.activeHosts.length;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Scan complete - ${_deviceCountLabel(deviceCount)} found',
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        return state.map(
          initial: (_) => const Center(child: CircularProgressIndicator()),
          loadInProgress: (value) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(30),
                child: ValueListenableBuilder<double>(
                  valueListenable: context.read<HostScanBloc>().progress,
                  builder: (context, progress, _) {
                    final percent = progress.clamp(0, 100).toDouble();
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: percent > 0 ? percent / 100 : null,
                        ),
                        const SizedBox(
                          height: 30,
                        ),
                        Text(
                          appSettings.gatewayIP.isNotEmpty
                              ? 'Looking for devices connected through ${appSettings.gatewayIP}'
                              : StringValue.loadingDevicesMessage,
                          textAlign: TextAlign.center,
                        ),
                        if (percent > 0) ...[
                          const SizedBox(height: 8),
                          Text('${percent.round()}% scanned'),
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
          foundNewDevice: (FoundNewDevice value) {
            return _devicesWidget(context, value.activeHosts.toList(), true);
          },
          loadFailure: (value) {
            return const Text('We could not finish looking for devices');
          },
          loadSuccess: (value) {
            return _devicesWidget(context, value.activeHosts.toList(), false);
          },
          error: (Error value) {
            return const Text('Something went wrong while looking for devices');
          },
        );
      },
    );
  }

  Widget _devicesWidget(
    BuildContext context,
    List<DeviceData> activeHostList,
    bool loading,
  ) {
    return Flex(
      direction: Axis.vertical,
      children: [
        AdaptiveListTile(
          title: Text(
            loading
                ? 'Found ${activeHostList.length} connected devices so far'
                : 'Scan complete - '
                    '${_deviceCountLabel(activeHostList.length)} found',
            textAlign: TextAlign.center,
          ),
          trailing: loading
              ? const SizedBox()
              : IconButton(
                  key: WidgetKey.rescanIconButton.key,
                  onPressed: () {
                    context
                        .read<HostScanBloc>()
                        .add(const HostScanEvent.startNewScan());
                  },
                  icon: const Icon(Icons.replay),
                ),
        ),
        if (loading)
          ValueListenableBuilder<double>(
            valueListenable: context.read<HostScanBloc>().progress,
            builder: (context, progress, _) {
              final value = (progress / 100).clamp(0.0, 1.0);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value > 0 ? value : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      value > 0
                          ? 'Scanning ${(value * 100).round()}%'
                          : 'Starting scan...',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        Expanded(
          child: ListView.builder(
            itemCount: activeHostList.length,
            itemBuilder: (context, index) {
              final DeviceData host = activeHostList[index];
              final isCurrentDevice = DeviceUtil.isCurrentDevice(host);
              return AdaptiveListTile(
                //TODO: fix below errors
                leading: Icon(DeviceUtil.getIconData(host)),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        DeviceUtil.getDeviceMake(host) ?? 'Unknown device',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text(
                          'This device',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                subtitle: _buildSubtitle(host, context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceDetailPage(device: host),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (host.macAddress != null && host.macAddress!.isNotEmpty)
                      IconButton(
                        tooltip: TooltipMessages.wakeOnLan,
                        icon: const Icon(Icons.power_settings_new),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WakeOnLanPage(
                                initialMacAddress: host.macAddress!,
                                initialIpv4Address:
                                    WakeOnLanService.broadcastFromIpv4(
                                          host.internetAddress,
                                        ) ??
                                        WakeOnLanService.defaultBroadcast,
                                initialLabel:
                                    DeviceUtil.getDeviceMake(host) ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      key: isCurrentDevice
                          ? WidgetKey.thisDeviceTileIconButton.key
                          : null,
                      tooltip: TooltipMessages.currentDevicePortScan,
                      icon: const Icon(Icons.radar),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PortScanPage(
                              target: host.internetAddress,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onLongPress: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: host.internetAddress,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device address copied'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(DeviceData host, BuildContext context) {
    final base =
        '${host.internetAddress}${host.macAddress != null && host.macAddress!.isNotEmpty ? ', ${host.macAddress}' : ''}';
    final outlineColor = Theme.of(context).colorScheme.outline;

    if (host.openPorts == null || host.openPorts!.isEmpty) {
      return Text(
        base,
        style: TextStyle(fontSize: 12, color: outlineColor),
      );
    }

    final ports = host.openPorts!
        .split(',')
        .map((p) => int.tryParse(p.trim()))
        .whereType<int>()
        .toList()
      ..sort();

    final colorMap = {
      'web': Colors.blue,
      'network': Colors.green,
      'file': Colors.orange,
      'remote': Colors.red,
      'database': Colors.purple,
      'email': Colors.teal,
      'print': Colors.pink,
      'other': Colors.grey,
    };

    final spans = <InlineSpan>[
      TextSpan(text: base, style: TextStyle(fontSize: 12, color: outlineColor)),
      const TextSpan(text: ' · ', style: TextStyle(fontSize: 12)),
    ];

    for (var i = 0; i < ports.length; i++) {
      final port = ports[i];
      final description = DeviceUtil.getPortDescription(port);
      final category = DeviceUtil.getPortCategory(port);
      final color = colorMap[category] ?? Colors.grey;

      spans.add(
        TextSpan(
          text: description != null ? '$port $description' : '$port',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      if (i < ports.length - 1) {
        spans.add(
          TextSpan(
            text: ', ',
            style: TextStyle(fontSize: 12, color: outlineColor),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}

String _deviceCountLabel(int count) =>
    '$count ${count == 1 ? 'device' : 'devices'}';
