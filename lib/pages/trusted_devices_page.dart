import 'package:flutter/material.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/device_detail_page/device_detail_page.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/device_trust_badge.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

enum _TrustFilter { all, trusted, untrusted }

enum _DeviceAction { trust, untrust, forget }

/// Lists every device the trust registry knows, trusted or not, so a decision
/// can be reviewed, revoked, or made ahead of time for a device's MAC address.
class TrustedDevicesPage extends StatefulWidget {
  const TrustedDevicesPage({super.key, this.service});

  final DeviceTrustService? service;

  @override
  State<TrustedDevicesPage> createState() => _TrustedDevicesPageState();
}

class _TrustedDevicesPageState extends State<TrustedDevicesPage> {
  late final DeviceTrustService _service;
  late final Stream<List<KnownDeviceData>> _knownDevices;
  _TrustFilter _filter = _TrustFilter.all;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? getIt<DeviceTrustService>();
    _knownDevices = _service.watchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trustedDevicesTitle),
        actions: [
          IconButton(
            key: WidgetKey.trustedDevicesAddManuallyButton.key,
            tooltip: context.l10n.trustedDevicesAddTitle,
            icon: const Icon(Icons.add),
            onPressed: _addByMac,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<KnownDeviceData>>(
          stream: _knownDevices,
          builder: (context, snapshot) {
            final known = snapshot.data ?? const <KnownDeviceData>[];
            final filtered = known.where(_matchesFilter).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip(
                        _TrustFilter.all,
                        context.l10n.trustedDevicesFilterAll,
                        known.length,
                        WidgetKey.trustedDevicesFilterAll,
                      ),
                      _filterChip(
                        _TrustFilter.trusted,
                        context.l10n.trustedDevicesFilterTrusted,
                        known.where((row) => row.trusted).length,
                        WidgetKey.trustedDevicesFilterTrusted,
                      ),
                      _filterChip(
                        _TrustFilter.untrusted,
                        context.l10n.trustedDevicesFilterUntrusted,
                        known.where((row) => !row.trusted).length,
                        WidgetKey.trustedDevicesFilterUntrusted,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildList(context, known, filtered),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(
    _TrustFilter filter,
    String label,
    int count,
    WidgetKey key,
  ) {
    return ChoiceChip(
      key: key.key,
      label: Text('$label ($count)'),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  bool _matchesFilter(KnownDeviceData row) {
    switch (_filter) {
      case _TrustFilter.all:
        return true;
      case _TrustFilter.trusted:
        return row.trusted;
      case _TrustFilter.untrusted:
        return !row.trusted;
    }
  }

  Widget _buildList(
    BuildContext context,
    List<KnownDeviceData> known,
    List<KnownDeviceData> filtered,
  ) {
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            known.isEmpty
                ? context.l10n.trustedDevicesEmpty
                : context.l10n.trustedDevicesFilterEmpty,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      key: WidgetKey.trustedDevicesList.key,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildRow(context, filtered[index]),
    );
  }

  Widget _buildRow(BuildContext context, KnownDeviceData row) {
    final hasAddress = row.lastAddress.isNotEmpty;
    return AdaptiveListTile(
      leading: DeviceTrustBadge(trusted: row.trusted, size: 22),
      title: Text(_displayName(row)),
      subtitle: Text(_subtitle(context, row)),
      onTap: hasAddress
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DeviceDetailPage(device: _toDevice(row)),
                ),
              )
          : null,
      trailing: PopupMenuButton<_DeviceAction>(
        onSelected: (action) => _onAction(row, action),
        itemBuilder: (context) => [
          if (row.trusted)
            PopupMenuItem(
              value: _DeviceAction.untrust,
              child: Text(context.l10n.trustedDevicesUntrustAction),
            )
          else
            PopupMenuItem(
              value: _DeviceAction.trust,
              child: Text(context.l10n.trustedDevicesTrustAction),
            ),
          PopupMenuItem(
            value: _DeviceAction.forget,
            child: Text(context.l10n.trustedDevicesForget),
          ),
        ],
      ),
    );
  }

  String _displayName(KnownDeviceData row) {
    final label = row.label;
    if (label != null && label.isNotEmpty) return label;
    final mac = row.macAddress;
    if (mac != null && mac.isNotEmpty) return mac;
    if (row.lastAddress.isNotEmpty) return row.lastAddress;
    return row.deviceKey;
  }

  String _subtitle(BuildContext context, KnownDeviceData row) {
    final parts = <String>[
      if (row.macAddress != null && row.macAddress!.isNotEmpty) row.macAddress!,
      if (row.lastAddress.isNotEmpty) row.lastAddress,
      if (row.lastAddress.isNotEmpty || row.lastScanId != null)
        context.l10n.trustedDevicesLastSeen(
          formatTimestamp(context.l10n, row.lastSeenAt),
        )
      else
        context.l10n.trustedDevicesNeverSeen,
    ];
    return parts.join(' · ');
  }

  DeviceData _toDevice(KnownDeviceData row) => DeviceData(
        id: row.lastScanId ?? row.firstSeenAt.millisecondsSinceEpoch,
        internetAddress: row.lastAddress,
        macAddress: row.macAddress,
        hostMake: row.label,
        currentDeviceIp: '',
        gatewayIp: '',
        scanId: row.lastScanId ?? 0,
      );

  Future<void> _onAction(KnownDeviceData row, _DeviceAction action) async {
    if (action == _DeviceAction.forget) {
      await _forget(row);
      return;
    }
    final trusted = action == _DeviceAction.trust;
    try {
      await _service.setTrustedForKey(row.deviceKey, trusted);
      if (!mounted) return;
      final name = _displayName(row);
      _showMessage(
        trusted
            ? context.l10n.deviceTrustMarkedTrusted(name)
            : context.l10n.deviceTrustMarkedUntrusted(name),
      );
    } catch (error) {
      debugPrint('Device trust update failed: $error');
      if (mounted) _showMessage(context.l10n.deviceTrustUpdateFailed);
    }
  }

  Future<void> _forget(KnownDeviceData row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.trustedDevicesForgetConfirmTitle),
        content: Text(
          context.l10n.trustedDevicesForgetConfirmBody(_displayName(row)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.trustedDevicesForget),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.forget(row.deviceKey);
      if (mounted) _showMessage(context.l10n.trustedDevicesForgotten);
    } catch (error) {
      debugPrint('Forgetting a device failed: $error');
      if (mounted) _showMessage(context.l10n.deviceTrustUpdateFailed);
    }
  }

  Future<void> _addByMac() async {
    final result = await showDialog<({String mac, String? name})>(
      context: context,
      builder: (context) => const _AddTrustedDeviceDialog(),
    );
    if (result == null) return;
    try {
      await _service.addTrustedMac(result.mac, label: result.name);
      if (mounted) _showMessage(context.l10n.trustedDevicesAdded);
    } catch (error) {
      debugPrint('Adding a trusted device failed: $error');
      if (!mounted) return;
      _showMessage(
        error is ArgumentError
            ? context.l10n.trustedDevicesMacInvalid
            : context.l10n.deviceTrustUpdateFailed,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Collects the two fields, and refuses to close until the MAC parses, so the
/// page never has to explain a rejected value after the user moved on.
class _AddTrustedDeviceDialog extends StatefulWidget {
  const _AddTrustedDeviceDialog();

  @override
  State<_AddTrustedDeviceDialog> createState() =>
      _AddTrustedDeviceDialogState();
}

class _AddTrustedDeviceDialogState extends State<_AddTrustedDeviceDialog> {
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _macController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final mac = _macController.text;
    if (!DeviceUtil.isValidMacAddress(mac)) {
      setState(() => _error = context.l10n.trustedDevicesMacInvalid);
      return;
    }
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      (mac: mac, name: name.isEmpty ? null : name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.trustedDevicesAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: WidgetKey.trustedDevicesMacField.key,
            controller: _macController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.trustedDevicesMacLabel,
              hintText: '00:1A:2B:3C:4D:5E',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: WidgetKey.trustedDevicesNameField.key,
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.trustedDevicesNameLabel,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          key: WidgetKey.trustedDevicesAddButton.key,
          onPressed: _submit,
          child: Text(context.l10n.trustedDevicesAddButton),
        ),
      ],
    );
  }
}
