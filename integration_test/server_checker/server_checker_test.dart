import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/pages/server_checker_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adds a TCP monitor and displays a live availability result',
      (tester) async {
    final server = await tester.runAsync(
      () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    expect(server, isNotNull);
    final connections = server!.listen((socket) => socket.destroy());
    addTearDown(() async {
      await connections.cancel();
      await server.close();
    });

    await tester.pumpWidget(
      const MaterialApp(home: ServerCheckerPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Local test server');
    await tester.enterText(fields.at(1), '127.0.0.1');
    await tester.tap(find.byType(DropdownButtonFormField<ServerCheckType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TCP').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '${server.port}');
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();

    // The name appears in both the monitor card and the editable field.
    expect(find.text('Local test server'), findsAtLeastNWidgets(1));
    await _waitForText(tester, find.textContaining('Reachable'));
    expect(
        find.textContaining('TCP port ${server.port} is open'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reports an unreachable TCP target and raises a down alert',
      (tester) async {
    final reservation = await tester.runAsync(
      () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    expect(reservation, isNotNull);
    final port = reservation!.port;
    await tester.runAsync(reservation.close);
    final alerts = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: ServerCheckerPage(
        onServerDown: (name) async => alerts.add(name),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Unavailable host');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await tester.tap(find.byType(DropdownButtonFormField<ServerCheckType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TCP').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '$port');
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();

    await _waitForText(tester, find.textContaining('Unreachable'));
    expect(find.text('Outages: 1'), findsOneWidget);
    expect(alerts, ['Unavailable host']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _waitForText(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}
