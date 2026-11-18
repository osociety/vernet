import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vernet/models/wake_on_lan_target.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

class WakeOnLanPage extends StatefulWidget {
  const WakeOnLanPage({
    super.key,
    this.initialMacAddress = '',
    this.initialIpv4Address = '',
    this.initialLabel = '',
    this.service,
  });

  final String initialMacAddress;
  final String initialIpv4Address;
  final String initialLabel;
  final WakeOnLanService? service;

  @override
  State<WakeOnLanPage> createState() => _WakeOnLanPageState();
}

class _WakeOnLanPageState extends State<WakeOnLanPage> {
  late final WakeOnLanService _service;
  final _formKey = GlobalKey<FormState>();
  final _macController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9');
  final _passwordController = TextEditingController();
  final _labelController = TextEditingController();
  bool _sending = false;
  String? _status;
  bool _statusIsError = false;
  List<WakeOnLanTarget> _saved = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WakeOnLanService();
    _macController.text = widget.initialMacAddress;
    _ipController.text = widget.initialIpv4Address;
    _labelController.text = widget.initialLabel;
    _loadSaved();
    if (widget.initialIpv4Address.isEmpty) {
      _prefillBroadcast();
    }
  }

  Future<void> _loadSaved() async {
    final saved = await _service.loadSavedTargets();
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
    });
  }

  Future<void> _prefillBroadcast() async {
    try {
      final gateway = await NetworkInfo().getWifiGatewayIP();
      if (!mounted || _ipController.text.isNotEmpty) {
        return;
      }
      final broadcast =
          gateway == null ? null : WakeOnLanService.broadcastFromIpv4(gateway);
      setState(() {
        _ipController.text = broadcast ?? WakeOnLanService.defaultBroadcast;
      });
    } catch (_) {
      if (!mounted || _ipController.text.isNotEmpty) {
        return;
      }
      setState(() {
        _ipController.text = WakeOnLanService.defaultBroadcast;
      });
    }
  }

  @override
  void dispose() {
    _macController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  int get _port {
    return int.tryParse(_portController.text.trim()) ??
        WakeOnLanService.defaultPort;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _sending = true;
      _status = null;
      _statusIsError = false;
    });
    try {
      final result = await _service.wake(
        macAddress: _macController.text,
        ipv4Address: _ipController.text,
        port: _port,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _status = context.l10n.wakeOnLanSent(
          result.macAddress,
          result.ipv4Address,
          '${result.port}',
        );
      });
    } on WakeOnLanException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _status = e.message;
        _statusIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _status = context.l10n.wakeOnLanErrorSend;
        _statusIsError = true;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final saved = await _service.saveTarget(
        WakeOnLanTarget(
          label: _labelController.text,
          macAddress: _macController.text,
          ipv4Address: _ipController.text.trim().isEmpty
              ? WakeOnLanService.defaultBroadcast
              : _ipController.text.trim(),
          port: _port,
          password: _passwordController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = saved;
        _status = context.l10n.wakeOnLanSaved(saved.first.label);
        _statusIsError = false;
      });
    } on WakeOnLanException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.message;
        _statusIsError = true;
      });
    }
  }

  void _fillFrom(WakeOnLanTarget target) {
    setState(() {
      _labelController.text = target.label;
      _macController.text = target.macAddress;
      _ipController.text = target.ipv4Address;
      _portController.text = '${target.port}';
      _passwordController.text = target.password;
      _status = null;
    });
  }

  Future<void> _delete(WakeOnLanTarget target) async {
    final saved = await _service.deleteTarget(target.macAddress);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.wakeOnLanPageTitle),
      ),
      body: SafeArea(
          child: ListView(
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
                      key: WidgetKey.wakeOnLanLabelField.key,
                      controller: _labelController,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.wakeOnLanNameLabel,
                        hintText: l10n.wakeOnLanNameHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanMacField.key,
                      controller: _macController,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.wakeOnLanMacLabel,
                        hintText: 'AA:BB:CC:DD:EE:FF',
                      ),
                      validator: (value) {
                        final mac = WakeOnLanService.normalizeMac(value ?? '');
                        if (mac.replaceAll(':', '').length != 12) {
                          return l10n.wakeOnLanMacFormat;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanIpField.key,
                      controller: _ipController,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.wakeOnLanBroadcastLabel,
                        hintText: WakeOnLanService.defaultBroadcast,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanPortField.key,
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.wakeOnLanPortLabel,
                      ),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port < 0 || port > 65535) {
                          return l10n.wakeOnLanPortHint;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanPasswordField.key,
                      controller: _passwordController,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: l10n.wakeOnLanPasswordLabel,
                        hintText: '00:11:22:33:44:55',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          key: WidgetKey.wakeOnLanSendButton.key,
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.power_settings_new),
                          label: Text(
                            _sending
                                ? l10n.wakeOnLanSending
                                : l10n.wakeOnLanSend,
                          ),
                        ),
                        OutlinedButton.icon(
                          key: WidgetKey.wakeOnLanSaveButton.key,
                          onPressed: _save,
                          icon: const Icon(Icons.bookmark_add),
                          label: Text(l10n.wakeOnLanSave),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.wakeOnLanExplainer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                key: WidgetKey.wakeOnLanStatusText.key,
                _status!,
                style: _statusIsError
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ),
          if (_saved.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.wakeOnLanEmptyPlaceholder,
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._saved.map(_savedTile),
        ],
      )),
    );
  }

  Widget _savedTile(WakeOnLanTarget target) {
    final l10n = context.l10n;
    return Card(
      child: AdaptiveListTile(
        leading: const Icon(Icons.computer),
        title: Text(target.label),
        subtitle:
            Text('${target.macAddress}\n${target.ipv4Address}:${target.port}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.wakeOnLanWakeThis,
              icon: const Icon(Icons.power_settings_new),
              onPressed: () async {
                _fillFrom(target);
                await _send();
              },
            ),
            IconButton(
              tooltip: l10n.wakeOnLanRemove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(target),
            ),
          ],
        ),
        onTap: () => _fillFrom(target),
      ),
    );
  }
}
