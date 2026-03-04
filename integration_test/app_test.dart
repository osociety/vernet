import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;

import 'dns/lookup/lookup_test.dart' as lookup_test;
import 'dns/reverse_lookup/reverse_lookup.dart' as reverse_lookup;
import 'network_troubleshooting_test/ping_test/ping_test.dart' as ping_test;
import 'settings/settings_test.dart' as settings_test;
import 'wifi_test/wifi_test_runner.dart' as wifi_test_runner;

int port = 0;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  globals.testingActive = true;
  late ServerSocket server;

  setUpAll(() async {
    configureDependencies(Env.test);
    final appDocDirectory = await getApplicationDocumentsDirectory();
    await configureNetworkToolsFlutter(appDocDirectory.path);
    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    debugPrint("Opened port in this machine at $port");
  });
  group('app launch test', () {
    testWidgets('just test if app is able to launch and display homepage',
        (tester) async {
      globals.testingActive = true;
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));

      // Use a longer timeout to allow platform channels to respond
      // In CI environments, this might timeout quickly if WiFi info isn't available
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify that there are at least 3 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));
    });
  });
  wifi_test_runner.main();
  ping_test.main();
  lookup_test.main();
  reverse_lookup.main();
  settings_test.main();

  tearDownAll(() {
    server.close();
  });
}
