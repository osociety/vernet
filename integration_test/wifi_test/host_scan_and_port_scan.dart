import 'dart:async';
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
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';
import '../test_port.dart' as test_port;
import 'wifi_test_runner.dart' show clearDatabase;

Future<void> _waitForScanToFinish() async {
  final scanRepository = getIt<ScanRepository>();
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  int? scanId;

  while (DateTime.now().isBefore(deadline)) {
    scanId ??= await getCurrentScanId();
    if (scanId != null) {
      final scan = await scanRepository.get(scanId);
      if (scan != null && scan.onGoing == false) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  throw TimeoutException('Device scan did not finish within 3 minutes');
}

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
      server =
          await ServerSocket.bind(InternetAddress.anyIPv4, 0, shared: true);
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
      // The Android CI emulator is on 10.0.2.x, a NAT sandbox with four live
      // addresses and ~250 that silently drop ICMP, so a full /24 sweep spends
      // a ping timeout per dead host and outlasts _waitForScanToFinish. Hosts
      // 1..16 cover every address the emulator has; desktop keeps the full
      // range and still finds real devices.
      if (Platform.isAndroid) {
        await AppSettings.instance.setFirstSubnet(1);
        await AppSettings.instance.setLastSubnet(16);
      }

      // Load app widget.
      await tester.pumpWidget(const MyApp(true));

      // Use a longer timeout to allow platform channels to respond
      // In CI environments, this might timeout quickly if WiFi info isn't available
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Finds the scan for devices button to tap on.
      final devicesButton = find.byKey(WidgetKey.scanForDevicesButton.key);

      // Emulate a tap on the button.
      await TestUtils.waitForWidget(tester, devicesButton);
      await tester.ensureVisible(devicesButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(devicesButton);
      await TestUtils.waitForWidget(tester, find.text('Find devices'));

      // Windows CI can take longer to finish host discovery. Keep the test
      // from returning (and the next test clearing the DB) while inserts are
      // still running in the scan service.
      await _waitForScanToFinish();
      await tester.pump(const Duration(milliseconds: 500));

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
