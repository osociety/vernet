import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/server_monitor.dart';

typedef IcmpProbe = Future<Duration?> Function(String host);

class ServerMonitorService {
  ServerMonitorService({
    http.Client? httpClient,
    IcmpProbe? icmpProbe,
    this.httpTimeout = const Duration(seconds: 10),
  })  : _httpClient = httpClient ?? _defaultHttpClient,
        _icmpProbe = icmpProbe ?? _ping;

  static final http.Client _defaultHttpClient = http.Client();
  static const _targetsKey = 'serverMonitors.targets';
  static const _historyKey = 'serverMonitors.history.';

  final http.Client _httpClient;
  final IcmpProbe _icmpProbe;
  final Duration httpTimeout;

  Future<List<ServerMonitor>> loadMonitors() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_targetsKey);
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .map((item) => ServerMonitor.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveMonitor(ServerMonitor monitor) async {
    final monitors = await loadMonitors();
    monitors.removeWhere((item) => item.id == monitor.id);
    monitors.add(monitor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _targetsKey,
      jsonEncode(monitors.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteMonitor(String id) async {
    final monitors = await loadMonitors();
    monitors.removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _targetsKey,
      jsonEncode(monitors.map((item) => item.toJson()).toList()),
    );
    await prefs.remove('$_historyKey$id');
  }

  Future<List<ServerCheckResult>> loadHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_historyKey$id');
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .map((item) => ServerCheckResult.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> recordResult(String id, ServerCheckResult result) async {
    final history = await loadHistory(id);
    history.add(result);
    // Keep roughly one week of one-minute checks without unbounded storage.
    if (history.length > 10080) {
      history.removeRange(0, history.length - 10080);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_historyKey$id',
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
  }

  Stream<ServerCheckResult> monitor(ServerMonitor monitor) {
    late final StreamController<ServerCheckResult> controller;
    Timer? timer;
    var checking = false;
    var cancelled = false;

    Future<void> checkOnce() async {
      if (checking || cancelled) return;
      checking = true;
      try {
        final result = await check(monitor);
        if (!cancelled) controller.add(result);
      } finally {
        checking = false;
      }
    }

    controller = StreamController<ServerCheckResult>(
      onListen: () {
        unawaited(checkOnce());
        final seconds =
            monitor.intervalSeconds < 1 ? 1 : monitor.intervalSeconds;
        timer = Timer.periodic(Duration(seconds: seconds), (_) {
          unawaited(checkOnce());
        });
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  Future<ServerCheckResult> check(ServerMonitor monitor) async {
    final started = DateTime.now();
    try {
      switch (monitor.type) {
        case ServerCheckType.icmp:
          final duration = await _icmpProbe(monitor.host);
          return ServerCheckResult(
            checkedAt: started,
            isUp: duration != null,
            latency: duration ?? DateTime.now().difference(started),
            message: duration == null ? 'No ICMP reply' : 'ICMP reply received',
          );
        case ServerCheckType.tcp:
          final socket = await Socket.connect(
            monitor.host,
            monitor.port!,
            timeout: const Duration(seconds: 5),
          );
          socket.destroy();
          return ServerCheckResult(
            checkedAt: started,
            isUp: true,
            latency: DateTime.now().difference(started),
            message: 'TCP port ${monitor.port} is open',
          );
        case ServerCheckType.http:
        case ServerCheckType.https:
          final scheme =
              monitor.type == ServerCheckType.https ? 'https' : 'http';
          final rawHost = monitor.host.contains('://')
              ? monitor.host
              : '$scheme://${monitor.host}';
          final uri = Uri.parse(rawHost).replace(scheme: scheme);
          final response = await _httpClient.get(uri).timeout(httpTimeout);
          final expectedText = monitor.expectedText;
          final textMatches =
              expectedText.isEmpty || response.body.contains(expectedText);
          final isUp = response.statusCode >= 200 &&
              response.statusCode < 400 &&
              textMatches;
          return ServerCheckResult(
            checkedAt: started,
            isUp: isUp,
            latency: DateTime.now().difference(started),
            message: !textMatches
                ? 'Expected text was not found'
                : 'HTTP ${response.statusCode}',
          );
      }
    } on Object catch (error) {
      return ServerCheckResult(
        checkedAt: started,
        isUp: false,
        latency: DateTime.now().difference(started),
        message: error.toString(),
      );
    }
  }

  static Future<Duration?> _ping(String host) async {
    final ping = Ping(host, count: 1, timeout: 3);
    final event = await ping.stream
        .firstWhere((event) => event is PingResponse)
        .timeout(const Duration(seconds: 5)) as PingResponse;
    return event.time;
  }
}
