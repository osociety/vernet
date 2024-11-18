import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';

void main() {
  late ServerSocket server;
  int port = 0;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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

  group('host scanner end-to-end test', () {
    testWidgets('just test if app is able to launch and display homepage',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));
    });

    testWidgets('tap on the scan for devices button, verify device found',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));

      // Finds the scan for devices button to tap on.
      final devicesButton = find.byKey(WidgetKey.scanForDevicesButton.key);

      // Emulate a tap on the button.
      await tester.tap(devicesButton);
      await tester.pump();
      expect(find.byType(AdaptiveListTile), findsAny);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.pump();
      expect(find.byType(AdaptiveListTile), findsAtLeast(2));

      final routerIconButton =
          find.byKey(WidgetKey.thisDeviceTileIconButton.key);

      await tester.tap(routerIconButton);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOne);

      final radioButton = find.byKey(WidgetKey.singlePortScanRadioButton.key);
      await tester.tap(radioButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(WidgetKey.enterPortTextField.key),
        port.toString(),
      );
      await tester.pumpAndSettle();

      final portScanButton = find.byKey(WidgetKey.portScanButton.key);
      await tester.tap(portScanButton);
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(AdaptiveListTile), findsAny);
    });
  });

  tearDownAll(() {
    server.close();
  });
}
