import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/services/server_monitor_service.dart';

void main() {
  late ServerMonitorService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ServerMonitorService();
  });

  group('ServerMonitorService persistence', () {
    test('saves, loads, and deletes monitors and check history', () async {
      const monitor = ServerMonitor(
        id: 'test-server',
        name: 'Local web server',
        host: '127.0.0.1',
        type: ServerCheckType.http,
        expectedText: 'healthy',
        intervalSeconds: 30,
      );
      final result = ServerCheckResult(
        checkedAt: DateTime.utc(2026, 10, 11),
        isUp: true,
        latency: const Duration(milliseconds: 12),
        message: 'HTTP 200',
      );

      await service.saveMonitor(monitor);
      await service.recordResult(monitor.id, result);

      final loadedMonitor = (await service.loadMonitors()).single;
      expect(loadedMonitor.toJson(), monitor.toJson());
      final loadedResult = (await service.loadHistory(monitor.id)).single;
      expect(loadedResult.checkedAt, result.checkedAt);
      expect(loadedResult.isUp, result.isUp);
      expect(loadedResult.latency, result.latency);
      expect(loadedResult.message, result.message);

      await service.deleteMonitor(monitor.id);
      expect(await service.loadMonitors(), isEmpty);
      expect(await service.loadHistory(monitor.id), isEmpty);
    });

    test('replaces a saved monitor with the same id', () async {
      const first = ServerMonitor(
        id: 'same-id',
        name: 'Old name',
        host: 'example.com',
        type: ServerCheckType.icmp,
      );
      const updated = ServerMonitor(
        id: 'same-id',
        name: 'New name',
        host: '127.0.0.1',
        type: ServerCheckType.tcp,
        port: 443,
      );

      await service.saveMonitor(first);
      await service.saveMonitor(updated);

      expect((await service.loadMonitors()).single.toJson(), updated.toJson());
    });

    test('ignores malformed saved monitor data', () async {
      SharedPreferences.setMockInitialValues({
        'serverMonitors.targets': '{not valid JSON',
      });

      expect(await service.loadMonitors(), isEmpty);
    });

    test('ignores malformed history data', () async {
      SharedPreferences.setMockInitialValues({
        'serverMonitors.history.bad': '[null, "invalid"]',
      });

      expect(await service.loadHistory('bad'), isEmpty);
    });

    test('keeps history bounded to the newest 10080 results', () async {
      final olderHistory = List<Map<String, Object?>>.generate(
        10080,
        (index) => {
          'checkedAt': DateTime.utc(2026)
              .add(Duration(minutes: index))
              .toIso8601String(),
          'isUp': true,
          'latencyMs': 1,
          'message': 'ok',
        },
      );
      SharedPreferences.setMockInitialValues({
        'serverMonitors.history.retention': jsonEncode(olderHistory),
      });
      final latest = ServerCheckResult(
        checkedAt: DateTime.utc(2026, 10, 11),
        isUp: false,
        latency: const Duration(milliseconds: 3),
        message: 'down',
      );

      await service.recordResult('retention', latest);

      final history = await service.loadHistory('retention');
      expect(history, hasLength(10080));
      expect(history.last.message, 'down');
      expect(
        history.first.checkedAt,
        DateTime.utc(2026).add(const Duration(minutes: 1)),
      );
    });
  });

  group('ServerMonitorService checks', () {
    test('ICMP reports a successful reply and latency', () async {
      service = ServerMonitorService(
        icmpProbe: (_) async => const Duration(milliseconds: 7),
      );

      final result = await service.check(const ServerMonitor(
        id: 'icmp',
        name: 'ICMP target',
        host: 'example.com',
        type: ServerCheckType.icmp,
      ));

      expect(result.isUp, isTrue);
      expect(result.latency, const Duration(milliseconds: 7));
      expect(result.message, 'ICMP reply received');
    });

    test('ICMP reports a missing reply as unreachable', () async {
      service = ServerMonitorService(icmpProbe: (_) async => null);

      final result = await service.check(const ServerMonitor(
        id: 'icmp-down',
        name: 'ICMP target',
        host: 'example.com',
        type: ServerCheckType.icmp,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, 'No ICMP reply');
    });

    test('ICMP probe errors become failed results', () async {
      service = ServerMonitorService(
        icmpProbe: (_) async => throw const SocketException('probe failed'),
      );

      final result = await service.check(const ServerMonitor(
        id: 'icmp-error',
        name: 'ICMP target',
        host: 'example.com',
        type: ServerCheckType.icmp,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, contains('probe failed'));
    });

    test('HTTPS uses an HTTPS URI and expected page text', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('secure and healthy', HttpStatus.ok);
      });
      service = ServerMonitorService(httpClient: client);
      addTearDown(client.close);

      final result = await service.check(const ServerMonitor(
        id: 'https',
        name: 'Secure web server',
        host: 'http://example.com/status',
        type: ServerCheckType.https,
        expectedText: 'healthy',
      ));

      expect(requestedUri?.scheme, 'https');
      expect(requestedUri?.path, '/status');
      expect(result.isUp, isTrue);
    });

    test('HTTP check does not downgrade/upshift based on a typed URL scheme',
        () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('ok', HttpStatus.ok);
      });
      final schemeService = ServerMonitorService(httpClient: client);
      addTearDown(client.close);

      final result = await schemeService.check(const ServerMonitor(
        id: 'http-scheme',
        name: 'HTTP monitor',
        host: 'https://example.com/status',
        type: ServerCheckType.http,
      ));

      expect(requestedUri?.scheme, 'http');
      expect(result.isUp, isTrue);
    });

    test('invalid HTTP URLs return a failed result', () async {
      final result = await service.check(const ServerMonitor(
        id: 'invalid-url',
        name: 'Invalid URL',
        host: 'http://',
        type: ServerCheckType.http,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, isNotEmpty);
    });

    test('HTTP status boundary is 200 through 399', () async {
      for (final statusCode in [200, 399, 400, 503]) {
        final client = MockClient((_) async => http.Response('', statusCode));
        final result = await ServerMonitorService(httpClient: client).check(
          ServerMonitor(
            id: 'status-$statusCode',
            name: 'Status test',
            host: 'status.example',
            type: ServerCheckType.http,
          ),
        );
        client.close();

        expect(result.isUp, statusCode >= 200 && statusCode < 400);
      }
    });

    test('HTTP timeout returns an unreachable result', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final timedService = ServerMonitorService(
        httpClient: client,
        httpTimeout: const Duration(milliseconds: 5),
      );
      addTearDown(client.close);

      final result = await timedService.check(const ServerMonitor(
        id: 'http-timeout',
        name: 'Slow server',
        host: 'slow.example',
        type: ServerCheckType.http,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, contains('TimeoutException'));
    });

    test('monitor checks immediately before its first polling delay', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('ok', HttpStatus.ok);
      });
      final monitorService = ServerMonitorService(httpClient: client);
      addTearDown(client.close);

      final result = await monitorService
          .monitor(const ServerMonitor(
            id: 'immediate',
            name: 'Immediate check',
            host: 'example.com',
            type: ServerCheckType.http,
          ))
          .first;

      expect(result.isUp, isTrue);
      expect(requests, 1);
    });

    test('HTTP succeeds when status and expected text match', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestDone = server.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('service is healthy')
          ..close();
      });
      addTearDown(() async {
        await requestDone.cancel();
        await server.close(force: true);
      });

      final result = await service.check(ServerMonitor(
        id: 'http',
        name: 'Local HTTP',
        host: 'http://127.0.0.1:${server.port}/status',
        type: ServerCheckType.http,
        expectedText: 'healthy',
      ));

      expect(result.isUp, isTrue);
      expect(result.message, 'HTTP 200');
      expect(result.latency, isNotNull);
    });

    test('HTTP is down when the expected text is missing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestDone = server.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('service is degraded')
          ..close();
      });
      addTearDown(() async {
        await requestDone.cancel();
        await server.close(force: true);
      });

      final result = await service.check(ServerMonitor(
        id: 'http-text-mismatch',
        name: 'Local HTTP',
        host: 'http://127.0.0.1:${server.port}/status',
        type: ServerCheckType.http,
        expectedText: 'healthy',
      ));

      expect(result.isUp, isFalse);
      expect(result.message, 'Expected text was not found');
    });

    test('HTTP treats non-success status codes as down', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestDone = server.listen((request) {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..close();
      });
      addTearDown(() async {
        await requestDone.cancel();
        await server.close(force: true);
      });

      final result = await service.check(ServerMonitor(
        id: 'http-error',
        name: 'Local HTTP',
        host: '127.0.0.1:${server.port}',
        type: ServerCheckType.http,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, 'HTTP 503');
    });

    test('TCP succeeds when the requested port accepts connections', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.listen((socket) => socket.destroy());
      addTearDown(() async {
        await accepted.cancel();
        await server.close();
      });

      final result = await service.check(ServerMonitor(
        id: 'tcp',
        name: 'Local TCP',
        host: '127.0.0.1',
        type: ServerCheckType.tcp,
        port: server.port,
      ));

      expect(result.isUp, isTrue);
      expect(result.message, 'TCP port ${server.port} is open');
    });

    test('closed TCP ports return a failed result rather than throwing',
        () async {
      final reservation =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reservation.port;
      await reservation.close();

      final result = await service.check(ServerMonitor(
        id: 'tcp-closed',
        name: 'Closed TCP',
        host: '127.0.0.1',
        type: ServerCheckType.tcp,
        port: port,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, isNotEmpty);
    });

    test('a missing TCP port returns a failed result rather than throwing',
        () async {
      final result = await service.check(const ServerMonitor(
        id: 'tcp-no-port',
        name: 'Incomplete TCP target',
        host: '127.0.0.1',
        type: ServerCheckType.tcp,
      ));

      expect(result.isUp, isFalse);
      expect(result.message, isNotEmpty);
    });
  });

  test('stored results use JSON compatible values', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = ServerCheckResult(
      checkedAt: DateTime.utc(2026, 10, 11),
      isUp: false,
      latency: const Duration(milliseconds: 5),
      message: 'down',
    );

    await service.recordResult('json', result);

    final raw = prefs.getString('serverMonitors.history.json');
    expect(jsonDecode(raw!) as List<dynamic>, hasLength(1));
  });
}
