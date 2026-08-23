import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/values/globals.dart' as globals;

import 'dns/lookup/lookup.dart' as lookup_test;
import 'dns/reverse_lookup/reverse_lookup.dart' as reverse_lookup;
import 'home_page/home_page.dart' as home_page_test;
import 'network_troubleshooting_test/ping_test/ping.dart' as ping_test;
import 'settings/settings.dart' as settings_test;
import 'settings/test_utils.dart';
import 'test_port.dart';
import 'wifi_test/wifi_test_runner.dart' as wifi_test_runner;

/// Single integration-test entry point. Nested suites omit the `_test.dart`
/// suffix so `flutter test integration_test` does not launch a separate app
/// per file (which fails on macOS with "Unable to start the app on the device").
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  globals.testingActive = true;
  NotificationService.skipPermissionRequests = true;
  late ServerSocket server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
  });

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

  wifi_test_runner.main();
  ping_test.main();
  lookup_test.main();
  reverse_lookup.main();
  settings_test.main();
  home_page_test.main();

  tearDownAll(() {
    server.close();
  });
}
