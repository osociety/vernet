import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/server_monitor_service.dart';

class ServerCheckerPage extends StatefulWidget {
  const ServerCheckerPage({super.key, this.service, this.onServerDown});

  final ServerMonitorService? service;
  final Future<void> Function(String serverName)? onServerDown;

  @override
  State<ServerCheckerPage> createState() => _ServerCheckerPageState();
}

class _ServerCheckerPageState extends State<ServerCheckerPage> {
  late final ServerMonitorService _service;
  late final Future<void> Function(String serverName) _onServerDown;
  final Map<String, StreamSubscription<ServerCheckResult>> _subscriptions = {};
  final Map<String, List<ServerCheckResult>> _histories = {};
  final Map<String, ServerCheckResult> _latest = {};
  final Set<String> _running = {};
  List<ServerMonitor> _monitors = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ServerMonitorService();
    _onServerDown =
        widget.onServerDown ?? NotificationService.showServerDownAlert;
    _load();
  }

  Future<void> _load() async {
    final monitors = await _service.loadMonitors();
    if (!mounted) return;
    setState(() => _monitors = monitors);
    for (final monitor in monitors) {
      final history = await _service.loadHistory(monitor.id);
      if (!mounted) return;
      setState(() {
        _histories[monitor.id] = history;
        if (history.isNotEmpty) _latest[monitor.id] = history.last;
      });
      _start(monitor);
    }
  }

  Future<void> _addMonitor() async {
    final monitor = await showDialog<ServerMonitor>(
      context: context,
      builder: (_) => const _AddMonitorDialog(),
    );
    if (monitor == null) return;
    await _service.saveMonitor(monitor);
    if (!mounted) return;
    setState(() => _monitors = [..._monitors, monitor]);
    _start(monitor);
  }

  Future<void> _editMonitor(ServerMonitor monitor) async {
    final updated = await showDialog<ServerMonitor>(
      context: context,
      builder: (_) => _AddMonitorDialog(monitor: monitor),
    );
    if (updated == null) return;
    final wasRunning = _running.contains(monitor.id);
    _stop(monitor.id);
    await _service.saveMonitor(updated);
    if (!mounted) return;
    setState(() {
      _monitors = _monitors
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
    if (wasRunning) _start(updated);
  }

  void _start(ServerMonitor monitor) {
    if (_running.contains(monitor.id)) return;
    setState(() => _running.add(monitor.id));
    ServerCheckResult? previous = _latest[monitor.id];
    _subscriptions[monitor.id] =
        _service.monitor(monitor).listen((result) async {
      await _service.recordResult(monitor.id, result);
      if (previous?.isUp != false && !result.isUp) {
        await _onServerDown(monitor.name);
      }
      previous = result;
      if (!mounted) return;
      setState(() {
        _latest[monitor.id] = result;
        _histories[monitor.id] = [
          ...?_histories[monitor.id],
          result,
        ].take(10080).toList();
      });
    }, onError: (Object _) {
      if (mounted) setState(() => _running.remove(monitor.id));
    });
  }

  void _stop(String id) {
    final subscription = _subscriptions.remove(id);
    if (mounted) setState(() => _running.remove(id));
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<void> _delete(ServerMonitor monitor) async {
    _stop(monitor.id);
    await _service.deleteMonitor(monitor.id);
    if (!mounted) return;
    setState(() {
      _monitors.removeWhere((item) => item.id == monitor.id);
      _histories.remove(monitor.id);
      _latest.remove(monitor.id);
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Server checker')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addMonitor,
          icon: const Icon(Icons.add),
          label: const Text('Add server'),
        ),
        body: _monitors.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Add a server to monitor reachability, response time, and downtime.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: _monitors.length,
                itemBuilder: (context, index) {
                  final monitor = _monitors[index];
                  final history = _histories[monitor.id] ?? [];
                  final latest = _latest[monitor.id];
                  final uptime = history.isEmpty
                      ? null
                      : history.where((item) => item.isUp).length *
                          100 /
                          history.length;
                  final downtime = _downtime(history);
                  final outages = _outages(history);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(
                              latest == null
                                  ? Icons.help_outline
                                  : latest.isUp
                                      ? Icons.check_circle
                                      : Icons.error,
                              color: latest == null
                                  ? null
                                  : latest.isUp
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(monitor.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                      '${monitor.type.name.toUpperCase()} · ${monitor.host}'),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit server',
                              onPressed: () => _editMonitor(monitor),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: _running.contains(monitor.id)
                                  ? 'Stop monitoring'
                                  : 'Start monitoring',
                              onPressed: () => _running.contains(monitor.id)
                                  ? _stop(monitor.id)
                                  : _start(monitor),
                              icon: Icon(_running.contains(monitor.id)
                                  ? Icons.pause
                                  : Icons.play_arrow),
                            ),
                            IconButton(
                              tooltip: 'Delete server',
                              onPressed: () => _delete(monitor),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ]),
                          if (latest != null)
                            Text(
                              '${latest.isUp ? 'Reachable' : 'Unreachable'} · ${latest.message} · ${_formatLatency(latest.latency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: _AvailabilityGraph(results: history),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 18,
                            runSpacing: 4,
                            children: [
                              Text('Checks: ${history.length}'),
                              Text('Outages: $outages'),
                              Text(uptime == null
                                  ? 'Uptime: —'
                                  : 'Uptime: ${uptime.toStringAsFixed(1)}%'),
                              Text('Downtime: ${_formatDuration(downtime)}'),
                              Text('Every ${monitor.intervalSeconds}s'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );

  Duration _downtime(List<ServerCheckResult> history) {
    if (history.length < 2) return Duration.zero;
    var total = Duration.zero;
    for (var i = 1; i < history.length; i++) {
      if (!history[i - 1].isUp) {
        total += history[i].checkedAt.difference(history[i - 1].checkedAt);
      }
    }
    return total;
  }

  int _outages(List<ServerCheckResult> history) {
    var outages = 0;
    for (var i = 0; i < history.length; i++) {
      if (!history[i].isUp && (i == 0 || history[i - 1].isUp)) outages++;
    }
    return outages;
  }

  String _formatLatency(Duration? latency) =>
      latency == null ? '—' : '${latency.inMilliseconds} ms';

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _AvailabilityGraph extends StatelessWidget {
  const _AvailabilityGraph({required this.results});
  final List<ServerCheckResult> results;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _AvailabilityPainter(
          results,
          Theme.of(context).colorScheme,
        ),
      );
}

class _AvailabilityPainter extends CustomPainter {
  _AvailabilityPainter(this.results, this.colors);
  final List<ServerCheckResult> results;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;
    final visible =
        results.length > 120 ? results.sublist(results.length - 120) : results;
    final step = size.width / visible.length;
    final paint = Paint()..strokeWidth = math.max(2, step - 1);
    for (var i = 0; i < visible.length; i++) {
      paint.color = visible[i].isUp ? Colors.green : colors.error;
      final x = i * step + step / 2;
      canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), paint);
    }
  }

  @override
  bool shouldRepaint(_AvailabilityPainter oldDelegate) =>
      oldDelegate.results != results;
}

class _AddMonitorDialog extends StatefulWidget {
  const _AddMonitorDialog({this.monitor});

  final ServerMonitor? monitor;

  @override
  State<_AddMonitorDialog> createState() => _AddMonitorDialogState();
}

class _AddMonitorDialogState extends State<_AddMonitorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _text;
  late ServerCheckType _type;
  late int _interval;

  @override
  void initState() {
    super.initState();
    final monitor = widget.monitor;
    _name = TextEditingController(text: monitor?.name ?? '');
    _host = TextEditingController(text: monitor?.host ?? '');
    _port = TextEditingController(text: monitor?.port?.toString() ?? '');
    _text = TextEditingController(text: monitor?.expectedText ?? '');
    _type = monitor?.type ?? ServerCheckType.icmp;
    _interval = monitor?.intervalSeconds ?? 60;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _text.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add server'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: 'Host or URL',
                  hintText: 'example.com or 192.168.1.1',
                ),
                validator: _required,
              ),
              DropdownButtonFormField<ServerCheckType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Check type'),
                items: ServerCheckType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              if (_type == ServerCheckType.tcp)
                TextFormField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'TCP port'),
                  validator: (value) {
                    final port = int.tryParse(value ?? '');
                    return port == null || port < 1 || port > 65535
                        ? 'Enter a port from 1 to 65535'
                        : null;
                  },
                ),
              if (_type == ServerCheckType.http ||
                  _type == ServerCheckType.https)
                TextFormField(
                  controller: _text,
                  decoration: const InputDecoration(
                    labelText: 'Expected page text (optional)',
                  ),
                ),
              DropdownButtonFormField<int>(
                initialValue: _interval,
                decoration: const InputDecoration(labelText: 'Check interval'),
                items: const [15, 30, 60, 300]
                    .map((seconds) => DropdownMenuItem(
                          value: seconds,
                          child: Text(seconds < 60
                              ? 'Every $seconds seconds'
                              : 'Every ${seconds ~/ 60} minutes'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _interval = value!),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final host = _host.text.trim();
              Navigator.pop(
                context,
                ServerMonitor(
                  id: widget.monitor?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  name: _name.text.trim(),
                  host: host,
                  type: _type,
                  port: _type == ServerCheckType.tcp
                      ? int.parse(_port.text)
                      : null,
                  expectedText: _text.text,
                  intervalSeconds: _interval,
                ),
              );
            },
            child: Text(
                widget.monitor == null ? 'Save and start' : 'Save changes'),
          ),
        ],
      );
}
