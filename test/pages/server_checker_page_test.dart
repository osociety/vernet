import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/services/server_monitor_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the empty state and add action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServerCheckerPage()));

    expect(find.text('Server checker'), findsOneWidget);
    expect(find.textContaining('Add a server to monitor'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
  });

  testWidgets('requires name and host before saving a monitor', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServerCheckerPage()));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));
    expect(find.text('Save and start'), findsOneWidget);
    expect(await ServerMonitorService().loadMonitors(), isEmpty);
  });

  testWidgets('validates TCP port range before saving', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServerCheckerPage()));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Local TCP');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await _selectType(tester, ServerCheckType.tcp);
    await tester.enterText(find.byType(TextFormField).at(2), '65536');
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
    expect(await ServerMonitorService().loadMonitors(), isEmpty);
  });

  testWidgets('cancel leaves monitor storage unchanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServerCheckerPage()));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Discarded');
    await tester.enterText(find.byType(TextFormField).at(1), 'example.com');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discarded'), findsNothing);
    expect(await ServerMonitorService().loadMonitors(), isEmpty);
  });

  testWidgets('adds HTTP monitor, records a healthy check, and persists config',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.scheme, 'http');
      expect(request.url.path, '/health');
      return http.Response('all systems healthy', 200);
    });
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(
      home:
          ServerCheckerPage(service: ServerMonitorService(httpClient: client)),
    ));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Web service');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'http://example.test/health',
    );
    await _selectType(tester, ServerCheckType.http);
    await tester.enterText(find.byType(TextFormField).at(2), 'healthy');
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Web service'), findsOneWidget);
    expect(find.textContaining('Reachable'), findsOneWidget);
    expect(find.text('Checks: 1'), findsOneWidget);
    expect(find.text('Outages: 0'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    final saved = (await ServerMonitorService().loadMonitors()).single;
    expect(saved.name, 'Web service');
    expect(saved.type, ServerCheckType.http);
    expect(saved.expectedText, 'healthy');
  });

  testWidgets('notifies once when checks go down and again after recovery',
      (tester) async {
    final responses = <int>[503, 503, 200, 503];
    final client =
        MockClient((_) async => http.Response('', responses.removeAt(0)));
    addTearDown(client.close);
    final alerts = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ServerCheckerPage(
        service: ServerMonitorService(httpClient: client),
        onServerDown: (name) async => alerts.add(name),
      ),
    ));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'API');
    await tester.enterText(find.byType(TextFormField).at(1), 'api.example');
    await _selectType(tester, ServerCheckType.http);
    await _selectInterval(tester, 15);
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(alerts, ['API']);

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(alerts, ['API']);

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reachable'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(alerts, ['API', 'API']);
    expect(find.text('Outages: 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resumes saved monitors and compares against prior state',
      (tester) async {
    final client = MockClient((_) async => http.Response('', 503));
    addTearDown(client.close);
    final service = ServerMonitorService(httpClient: client);
    const monitor = ServerMonitor(
      id: 'saved',
      name: 'Saved monitor',
      host: 'saved.example',
      type: ServerCheckType.http,
      intervalSeconds: 15,
    );
    await service.saveMonitor(monitor);
    await service.recordResult(
      monitor.id,
      ServerCheckResult(
        checkedAt: DateTime.utc(2026, 10, 11),
        isUp: true,
        latency: const Duration(milliseconds: 2),
      ),
    );
    final alerts = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: ServerCheckerPage(
        service: service,
        onServerDown: (name) async => alerts.add(name),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Saved monitor'), findsOneWidget);
    expect(find.textContaining('Unreachable'), findsOneWidget);
    expect(alerts, ['Saved monitor']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'pause stops polling, resume checks immediately, and delete clears data',
      (tester) async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('ok', 200);
    });
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(
      home:
          ServerCheckerPage(service: ServerMonitorService(httpClient: client)),
    ));
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lifecycle');
    await tester.enterText(find.byType(TextFormField).at(1), 'lifecycle.test');
    await _selectType(tester, ServerCheckType.http);
    await _selectInterval(tester, 15);
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Every 15s'), findsOneWidget);
    final savedMonitor = (await ServerMonitorService().loadMonitors()).single;

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Stop monitoring'), findsNothing);
    expect(find.byTooltip('Start monitoring'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(requests, 1);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(requests, 2);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Lifecycle'), findsNothing);
    expect(await ServerMonitorService().loadMonitors(), isEmpty);
    expect(await ServerMonitorService().loadHistory(savedMonitor.id), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _selectType(WidgetTester tester, ServerCheckType type) async {
  await tester.tap(find.byType(DropdownButtonFormField<ServerCheckType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type.name.toUpperCase()).last);
  await tester.pumpAndSettle();
}

Future<void> _selectInterval(WidgetTester tester, int seconds) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Every $seconds seconds').last);
  await tester.pumpAndSettle();
}
