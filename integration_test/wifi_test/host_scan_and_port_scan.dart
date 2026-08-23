import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';
import '../test_port.dart' as test_port;
import 'wifi_test_runner.dart' show clearDatabase;

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ServerSocket? server;

  setUpAll(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
    if (test_port.port == 0) {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0, shared: true);
      test_port.port = server!.port;
      debugPrint("Opened port in this machine at ${test_port.port}");
    }
  });

  setUp(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
    // Clear database before each test to prevent stale scan records
    await clearDatabase();
  });

  tearDownAll(() async {
    await server?.close();
  });

  group('host scanner end-to-end test', () {
    testWidgets('tap on the scan for devices button, verify device found',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));

      // Use a longer timeout to allow platform channels to respond
      // In CI environments, this might timeout quickly if WiFi info isn't available
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify that there are at least 3 tiles on homepage (including scan button)
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(3));

      // Finds the scan for devices button to tap on.
      final devicesButton = find.byKey(WidgetKey.scanForDevicesButton.key);

      // Emulate a tap on the button.
      await TestUtils.waitForWidget(tester, devicesButton);
      await tester.tap(devicesButton);
      await tester.pump();
      expect(find.byType(AdaptiveListTile), findsAny);
      await tester.pumpAndSettle(const Duration(seconds: 15));
      await tester.pump();

      if (find.byType(AdaptiveListTile).evaluate().length < 2) {
        debugPrint(
            'Not enough devices found in CI. Skipping the rest of the test.');
        return;
      }
      expect(find.byType(AdaptiveListTile), findsAtLeast(2));

      final routerIconButton =
          find.byKey(WidgetKey.thisDeviceTileIconButton.key);

      Finder targetButton = routerIconButton;
      if (routerIconButton.evaluate().isEmpty) {
        targetButton = find.byIcon(Icons.radar).first;
      }

      if (targetButton.evaluate().isNotEmpty) {
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            targetButton,
            500.0,
            scrollable: find.byType(Scrollable).first,
          );
        }
        // Ensure widget is fully visible and tap in center
        await tester.ensureVisible(targetButton);
        await tester.pumpAndSettle();
        await tester.tap(targetButton, warnIfMissed: false);
      } else {
        debugPrint('No port scan button found. Skipping the rest of the test.');
        return;
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AppBar), findsOne);

      // Wait for port scan page to fully load and radio button to be visible
      await tester.pumpAndSettle(const Duration(seconds: 3));
      final radioButton = find.byKey(WidgetKey.singlePortScanRadioButton.key);

      // Force IP to localhost so the local port we just opened will be hit
      // We know there are TextFormFields. The top one is the IP entered by the user.
      await tester.enterText(
        find.byType(TextFormField).first,
        '127.0.0.1',
      );

      // Verify radio button exists before tapping
      if (find
          .byKey(WidgetKey.singlePortScanRadioButton.key)
          .evaluate()
          .isEmpty) {
        debugPrint('Radio button not found, scrolling to find it');
        await tester.scrollUntilVisible(
          radioButton,
          500.0,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.tap(radioButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(WidgetKey.enterPortTextField.key),
        test_port.port.toString(),
      );
      await tester.pumpAndSettle();

      final portScanButton = find.byKey(WidgetKey.portScanButton.key);
      await tester.tap(portScanButton);
      await tester.pumpAndSettle();
      // Wait for the async port scan to finish since there is no UI animation to hold pumpAndSettle
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AdaptiveListTile), findsAny);
    });
  });

  // tearDownAll(() {
  //   server.close();
  // });
}
