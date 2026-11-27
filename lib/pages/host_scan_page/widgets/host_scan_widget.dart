import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/device_risk.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/widgets/scan_history_button.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/services/network_analysis/device_risk_analyzer.dart';
import 'package:vernet/services/network_analysis/device_risk_service.dart';
import 'package:vernet/services/network_analysis/port_risk_analyzer.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/store/inline_adaptive_banner.dart';
import 'package:vernet/store/store_ad_slot.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/shell_chrome.dart';
import 'package:vernet/ui/device_risk_chip.dart';
import 'package:vernet/ui/device_trust_badge.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';

class HostScanWidget extends StatefulWidget {
  @override
  State<HostScanWidget> createState() => _HostScanWidgetState();
}

class _HostScanWidgetState extends State<HostScanWidget> {
  DeviceTrustService? _trustService;
  DeviceRiskService? _riskService;
  Stream<List<KnownDeviceData>>? _knownDevices;
  Map<String, DeviceRiskAssessment> _riskAssessments = const {};

  @override
  void initState() {
    super.initState();
    // Widget tests mount the page without the DI graph; the list then simply
    // renders without badges instead of failing to build.
    if (getIt.isRegistered<DeviceTrustService>()) {
      _trustService = getIt<DeviceTrustService>();
      _knownDevices = _trustService!.watchAll();
    }
    if (getIt.isRegistered<DeviceRiskService>()) {
      _riskService = getIt<DeviceRiskService>();
    }
  }

  /// Loads the history-aware tiers once a scan finishes. Rows fall back to the
  /// single-device assessment until this lands, which has every signal except
  /// whether the device keeps disappearing between scans.
  Future<void> _loadRiskAssessments(List<DeviceData> hosts) async {
    final service = _riskService;
    if (service == null || hosts.isEmpty) return;
    final assessments = await service.assessDevices(hosts, context.l10n);
    if (!mounted) return;
    setState(() => _riskAssessments = assessments);
  }

  DeviceRiskAssessment _riskOf(DeviceData host) =>
      _riskAssessments[DeviceUtil.deviceKey(host)] ??
      DeviceRiskAnalyzer.assess(
        host,
        findings: PortRiskAnalyzer.analyze(
          PortRiskAnalyzer.parsePorts(host.openPorts),
          l10n: context.l10n,
          deviceAddress: host.internetAddress,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final knownDevices = _knownDevices;
    if (knownDevices == null) return _buildScan(context, const []);
    return StreamBuilder<List<KnownDeviceData>>(
      stream: knownDevices,
      builder: (context, snapshot) =>
          _buildScan(context, snapshot.data ?? const []),
    );
  }

  Widget _buildScan(BuildContext context, List<KnownDeviceData> knownDevices) {
    return BlocConsumer<HostScanBloc, HostScanState>(
      listenWhen: (previous, current) =>
          previous is! LoadSuccess && current is LoadSuccess,
      listener: (context, state) {
        if (state is LoadSuccess) {
          final deviceCount = state.activeHosts.length;
          unawaited(_loadRiskAssessments(state.activeHosts.toList()));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(_scanCompleteLabel(context.l10n, deviceCount)),
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
                              ? context.l10n.scanThroughGateway(
                                  appSettings.gatewayIP,
                                )
                              : context.l10n.loadingDevicesMessage,
                          textAlign: TextAlign.center,
                        ),
                        if (percent > 0) ...[
                          const SizedBox(height: 8),
                          Text(context.l10n.scanPercentDone(
                            '${percent.round()}',
                          )),
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
          foundNewDevice: (FoundNewDevice value) {
            return _devicesWidget(
              context,
              value.activeHosts.toList(),
              true,
              knownDevices,
            );
          },
          loadFailure: (value) {
            return Text(context.l10n.scanCouldNotFinish);
          },
          loadSuccess: (value) {
            return _devicesWidget(
              context,
              value.activeHosts.toList(),
              false,
              knownDevices,
            );
          },
          error: (Error value) {
            return Text(context.l10n.scanWentWrong);
          },
        );
      },
    );
  }

  Widget _devicesWidget(
    BuildContext context,
    List<DeviceData> activeHostList,
    bool loading,
    List<KnownDeviceData> knownDevices,
  ) {
    return Flex(
      direction: Axis.vertical,
      children: [
        AdaptiveListTile(
          title: Text(
            loading
                ? _foundSoFarLabel(context.l10n, activeHostList.length)
                : _scanCompleteLabel(context.l10n, activeHostList.length),
            textAlign: TextAlign.center,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // On a phone the shell's bar has no action slot for this page,
              // so history rides along with the scan controls.
              if (ShellChrome.providesAppBar(context))
                const ScanHistoryButton(),
              if (!loading)
                IconButton(
                  key: WidgetKey.rescanIconButton.key,
                  onPressed: () {
                    context
                        .read<HostScanBloc>()
                        .add(const HostScanEvent.startNewScan());
                  },
                  icon: const Icon(Icons.replay),
                ),
            ],
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
                          ? context.l10n.scanProgressPercent(
                              '${(value * 100).round()}',
                            )
                          : context.l10n.scanStarting,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        Expanded(
          child: ListView.builder(
            itemCount: activeHostList.length + kStoreBannerRows,
            itemBuilder: (context, index) {
              if (index < kStoreBannerRows) {
                return const InlineAdaptiveBanner(slot: StoreAdSlot.hostScan);
              }
              final DeviceData host = activeHostList[index - kStoreBannerRows];
              final isCurrentDevice = DeviceUtil.isCurrentDevice(host);
              final knownDevice =
                  DeviceTrustService.knownDeviceFor(knownDevices, host);
              final risk = _riskOf(host);
              return AdaptiveListTile(
                //TODO: fix below errors
                leading: Icon(DeviceUtil.getIconData(host)),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        DeviceUtil.makeLabel(
                              context.l10n,
                              DeviceUtil.getDeviceMake(host),
                            ) ??
                            context.l10n.unknownDevice,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          context.l10n.scanThisDevice,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    const SizedBox(width: 8),
                    DeviceRiskChip(level: risk.level, reasons: risk.reasons),
                    if (knownDevice != null) ...[
                      const SizedBox(width: 8),
                      DeviceTrustBadge(trusted: knownDevice.trusted),
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
                        tooltip: context.l10n.wakeOnLanTooltip,
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
                                initialLabel: DeviceUtil.makeLabel(
                                      context.l10n,
                                      DeviceUtil.getDeviceMake(host),
                                    ) ??
                                    '',
                              ),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      key: isCurrentDevice
                          ? WidgetKey.thisDeviceTileIconButton.key
                          : null,
                      tooltip: context.l10n.devicePortScanTooltip,
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
                onLongPress: _trustService == null
                    ? null
                    : () => _toggleTrust(
                          host,
                          knownDevice?.trusted ?? false,
                        ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Long-press flips the device's trust; the badge beside the name shows the
  /// result once the registry streams the new row back.
  Future<void> _toggleTrust(DeviceData host, bool trusted) async {
    final service = _trustService;
    if (service == null) return;
    final name = DeviceUtil.makeLabel(
          context.l10n,
          DeviceUtil.getDeviceMake(host),
        ) ??
        context.l10n.unknownDevice;
    try {
      await service.setTrusted(host, !trusted);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              trusted
                  ? context.l10n.deviceTrustMarkedUntrusted(name)
                  : context.l10n.deviceTrustMarkedTrusted(name),
            ),
          ),
        );
    } catch (error) {
      debugPrint('Device trust update failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.deviceTrustUpdateFailed)),
        );
    }
  }

  Widget _buildSubtitle(DeviceData host, BuildContext context) {
    final vendorName = host.vendorName;
    final base = '${host.internetAddress}'
        '${host.macAddress != null && host.macAddress!.isNotEmpty ? ', ${host.macAddress}' : ''}'
        '${vendorName != null && vendorName.isNotEmpty ? ' · $vendorName' : ''}';
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

/// "1 devices found" reads wrong in every language, so the singular case has
/// its own string instead of an interpolated count.
String _scanCompleteLabel(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.scanCompleteOne : l10n.scanCompleteMany('$count');

String _foundSoFarLabel(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.scanFoundSoFarOne : l10n.scanFoundSoFar('$count');
