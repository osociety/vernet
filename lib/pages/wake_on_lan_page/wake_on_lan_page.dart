import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vernet/models/wake_on_lan_target.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

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
      final broadcast = gateway == null
          ? null
          : WakeOnLanService.broadcastFromIpv4(gateway);
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
        _status =
            'Wake packet sent to ${result.macAddress} via ${result.ipv4Address}:${result.port}';
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
        _status = 'Could not send the wake packet.';
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
        _status = 'Saved ${saved.first.label}';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.wakeOnLanPageTitle),
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
                      key: WidgetKey.wakeOnLanLabelField.key,
                      controller: _labelController,
                      decoration: const InputDecoration(
                        filled: true,
                        labelText: 'Name (optional)',
                        hintText: 'Office PC',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanMacField.key,
                      controller: _macController,
                      decoration: const InputDecoration(
                        filled: true,
                        labelText: 'MAC address',
                        hintText: 'AA:BB:CC:DD:EE:FF',
                      ),
                      validator: (value) {
                        final mac = WakeOnLanService.normalizeMac(value ?? '');
                        if (mac.replaceAll(':', '').length != 12) {
                          return 'Enter a MAC address like AA:BB:CC:DD:EE:FF';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanIpField.key,
                      controller: _ipController,
                      decoration: const InputDecoration(
                        filled: true,
                        labelText: 'Broadcast address',
                        hintText: WakeOnLanService.defaultBroadcast,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanPortField.key,
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        filled: true,
                        labelText: 'UDP port',
                      ),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port < 0 || port > 65535) {
                          return 'Enter a port between 0 and 65535';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: WidgetKey.wakeOnLanPasswordField.key,
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        filled: true,
                        labelText: 'SecureON password (optional)',
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
                          label: Text(_sending ? 'Sending…' : 'Send wake packet'),
                        ),
                        OutlinedButton.icon(
                          key: WidgetKey.wakeOnLanSaveButton.key,
                          onPressed: _save,
                          icon: const Icon(Icons.bookmark_add),
                          label: const Text('Save device'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sends a Wake-on-LAN magic packet on your local network. The computer must have WoL enabled in firmware and in the OS.',
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
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                StringValue.wakeOnLanEmptyPlaceholder,
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._saved.map(_savedTile),
        ],
      ),
    );
  }

  Widget _savedTile(WakeOnLanTarget target) {
    return Card(
      child: AdaptiveListTile(
        leading: const Icon(Icons.computer),
        title: Text(target.label),
        subtitle: Text('${target.macAddress}\n${target.ipv4Address}:${target.port}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Wake this device',
              icon: const Icon(Icons.power_settings_new),
              onPressed: () async {
                _fillFrom(target);
                await _send();
              },
            ),
            IconButton(
              tooltip: 'Remove saved device',
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
