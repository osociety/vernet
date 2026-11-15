import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vernet/models/neighbor_info.dart';
import 'package:vernet/pages/network_troubleshoot/port_scan_page.dart';
import 'package:vernet/services/neighbor_discovery/neighbor_discovery_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

class NeighborDiscoveryPage extends StatefulWidget {
  const NeighborDiscoveryPage({
    super.key,
    this.initialSwitchIp = '',
    this.service,
  });

  final String initialSwitchIp;
  final NeighborDiscoveryService? service;

  @override
  State<NeighborDiscoveryPage> createState() => _NeighborDiscoveryPageState();
}

class _NeighborDiscoveryPageState extends State<NeighborDiscoveryPage> {
  late final NeighborDiscoveryService _service;
  final _switchController = TextEditingController();
  final _communityController = TextEditingController(text: 'public');
  final _cliController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cdp = true;
  bool _lldp = true;
  bool _loading = false;
  String? _error;
  NeighborDiscoveryResult? _snmpResult;
  List<NeighborInfo> _cliNeighbors = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NeighborDiscoveryService();
    _switchController.text = widget.initialSwitchIp;
    if (widget.initialSwitchIp.isEmpty) {
      _prefillGateway();
    }
  }

  Future<void> _prefillGateway() async {
    try {
      final gateway = await NetworkInfo().getWifiGatewayIP();
      if (!mounted || _switchController.text.isNotEmpty) {
        return;
      }
      if (gateway != null && gateway.isNotEmpty) {
        setState(() {
          _switchController.text = gateway;
        });
      }
    } catch (_) {
      // Gateway lookup is optional.
    }
  }

  @override
  void dispose() {
    _switchController.dispose();
    _communityController.dispose();
    _cliController.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _snmpResult = null;
      _cliNeighbors = [];
    });
    try {
      final result = await _service.discover(
        switchIp: _switchController.text.trim(),
        community: _communityController.text,
        queryCdp: _cdp,
        queryLldp: _lldp,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snmpResult = result;
        _loading = false;
        if (result.neighbors.isEmpty) {
          _error = context.l10n.neighborErrorNoResult;
        }
      });
    } on NeighborDiscoveryException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = context.l10n.neighborFailed;
      });
    }
  }

  void _parseCli() {
    final neighbors = _service.parseCli(_cliController.text);
    setState(() {
      _cliNeighbors = neighbors;
      _snmpResult = null;
      _error = neighbors.isEmpty ? context.l10n.neighborCliEmpty : null;
    });
  }

  List<NeighborInfo> get _neighbors =>
      _cliNeighbors.isNotEmpty ? _cliNeighbors : (_snmpResult?.neighbors ?? []);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.neighborDiscoveryPageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: WidgetKey.neighborSwitchIpField.key,
                      controller: _switchController,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.neighborSwitchAddressLabel,
                        hintText: '192.168.1.1',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.neighborErrorSwitchAddress;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.neighborCommunityField.key,
                      controller: _communityController,
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.neighborCommunityLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          key: WidgetKey.neighborCdpChip.key,
                          label: const Text('CDP'),
                          selected: _cdp,
                          onSelected: (value) => setState(() => _cdp = value),
                        ),
                        FilterChip(
                          key: WidgetKey.neighborLldpChip.key,
                          label: const Text('LLDP'),
                          selected: _lldp,
                          onSelected: (value) => setState(() => _lldp = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      key: WidgetKey.neighborDiscoverButton.key,
                      onPressed:
                          _loading || (!_cdp && !_lldp) ? null : _discover,
                      icon: const Icon(Icons.hub),
                      label: Text(
                        _loading ? l10n.neighborAsking : l10n.neighborFind,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.neighborExplainer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Card(
            child: ExpansionTile(
              key: WidgetKey.neighborCliTile.key,
              title: Text(l10n.neighborCliTitle),
              subtitle: Text(l10n.neighborCliSubtitle),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      TextField(
                        key: WidgetKey.neighborCliField.key,
                        controller: _cliController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          filled: true,
                          hintText: l10n.neighborCliHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          key: WidgetKey.neighborParseCliButton.key,
                          onPressed: _parseCli,
                          child: Text(l10n.neighborReadCli),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_snmpResult != null) _switchCard(_snmpResult!.switchInfo),
          if (_snmpResult != null && _snmpResult!.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                _snmpResult!.warnings.join('\n'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          if (_neighbors.isEmpty && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.neighborDiscoveryEmptyPlaceholder,
                textAlign: TextAlign.center,
              ),
            ),
          ..._neighbors.map(_neighborTile),
        ],
      ),
    );
  }

  Widget _switchCard(SwitchIdentity info) {
    return Card(
      child: AdaptiveListTile(
        leading: const Icon(Icons.lan),
        title: Text(info.displayName),
        subtitle: Text(
          [
            info.ip,
            if (info.sysDescr != null && info.sysDescr!.isNotEmpty)
              info.sysDescr!.split('\n').first,
          ].join('\n'),
        ),
      ),
    );
  }

  Widget _neighborTile(NeighborInfo neighbor) {
    final l10n = context.l10n;
    return Card(
      child: AdaptiveListTile(
        leading: Icon(
          neighbor.protocol == NeighborProtocol.cdp
              ? Icons.router
              : Icons.device_hub,
        ),
        title: Text(neighbor.hostname),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              neighbor.protocol == NeighborProtocol.cdp ? 'CDP' : 'LLDP',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (neighbor.managementIp != null)
              Text(l10n.neighborManagementIp(neighbor.managementIp!)),
            if (neighbor.localPort != null)
              Text(l10n.neighborSwitchPort(neighbor.localPort!)),
            if (neighbor.remotePort != null)
              Text(l10n.neighborRemoteInterface(neighbor.remotePort!)),
            if (neighbor.platform != null) Text(neighbor.platform!),
            if (neighbor.vlan != null) Text(l10n.neighborVlan(neighbor.vlan!)),
            if (neighbor.speedDuplex != null) Text(neighbor.speedDuplex!),
          ],
        ),
        trailing: neighbor.managementIp == null
            ? null
            : IconButton(
                tooltip: l10n.neighborPortScanTooltip,
                icon: const Icon(Icons.radar),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PortScanPage(
                        target: neighbor.managementIp!,
                      ),
                    ),
                  );
                },
              ),
        onLongPress: () {
          final text = [
            neighbor.hostname,
            if (neighbor.managementIp != null) neighbor.managementIp,
            if (neighbor.localPort != null)
              l10n.neighborPortClipboard(neighbor.localPort!),
          ].join(' ');
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.neighborCopied)),
          );
        },
      ),
    );
  }
}
