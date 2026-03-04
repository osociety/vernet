import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';

void main() {
  globals.testingActive = true;
  late ServerSocket server;
  int port = 0;
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
  
  group('Run device scan on startup', () {
    testWidgets('if settings for startup is on, then it should run',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.tapByWidgetKey(
        WidgetKey.runOnAppStartupSwitch,
        tester,
        find,
      );

      await TestUtils.tapHomeButton(tester, find);

      // pump with a longer timeout to rebuild HomePage after navigation
      // and allow platform channels to respond
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(WidgetKey.runScanOnStartup.key), findsOne);
    });
  });

  tearDownAll(() {
    server.close();
  });
}
