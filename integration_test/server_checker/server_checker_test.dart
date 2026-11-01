import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/server_monitor.dart';
import 'package:vernet/pages/server_checker_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/server_monitor_service.dart';
import 'package:vernet/values/globals.dart' as globals;

import '../settings/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() {
    globals.testingActive = true;
    SharedPreferences.setMockInitialValues({});
    TestUtils.configureAndroidChannelMocks();

    // Mock NetworkInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getWifiGatewayIP') {
          return '192.168.1.1';
        }
        return null;
      },
    );
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

  testWidgets('quick-add monitors from empty state', (tester) async {
    // Clear any existing monitors first
    final monitorService = ServerMonitorService();
    final existingMonitors = await monitorService.loadMonitors();
    for (final monitor in existingMonitors) {
      await monitorService.deleteMonitor(monitor.id);
    }

    await tester.pumpWidget(
      const MaterialApp(home: ServerCheckerPage()),
    );
    await tester.pumpAndSettle();

    // Should show Quick Add section - scroll to find it
    await tester.scrollUntilVisible(
      find.text('Quick Add'),
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Add'), findsOneWidget);
    expect(find.text('Add these monitors to track network reliability:'), findsOneWidget);

    // Should show router monitor option
    expect(find.text('Local Router'), findsOneWidget);

    // Should show internet monitor options
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Cloudflare'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    // Quick-add the router monitor - tap the add icon next to it
    final addIcons = find.byIcon(Icons.add_circle_outline);
    expect(addIcons, findsWidgets);
    await tester.tap(addIcons.first);
    await tester.pumpAndSettle();

    // Should show snackbar confirmation
    expect(find.textContaining('Local Router added'), findsOneWidget);

    // Wait for the page to transition to monitor list view
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify monitor was added by checking the service
    final monitors = await monitorService.loadMonitors();
    expect(monitors.length, 1);
    expect(monitors[0].name, 'Local Router');
    expect(monitors[0].type, ServerCheckType.icmp);

    // The page should now show the monitor list, not the quick-add section
    expect(find.text('Local Router'), findsOneWidget);

    // Clean up
    for (final monitor in monitors) {
      await monitorService.deleteMonitor(monitor.id);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(finder, findsWidgets);
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
