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
import '../wifi_test/wifi_test_runner.dart' show clearDatabase;

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ServerSocket? ipv6Server;

  setUpAll(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
    if (test_port.portIPv6 == 0) {
      try {
        ipv6Server = await ServerSocket.bind(
          InternetAddress.loopbackIPv6,
          0,
          shared: true,
        );
        test_port.portIPv6 = ipv6Server!.port;
        debugPrint('Opened IPv6 port on [::1]:${test_port.portIPv6}');
      } on SocketException catch (e) {
        debugPrint('IPv6 loopback unavailable, test will be skipped: $e');
      }
    }
  });

  setUp(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
    await clearDatabase();
  });

  tearDownAll(() async {
    await ipv6Server?.close();
  });

  group('IPv6 port scan', () {
    testWidgets(
      'scanning [::1] finds the open IPv6 loopback port',
      (tester) async {
        if (test_port.portIPv6 == 0) {
          debugPrint(
            'Skipping IPv6 port scan test: no IPv6 loopback on this platform',
          );
          return;
        }

        await tester.pumpWidget(const MyApp(true));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        // Navigate directly to the port scan page via the sidebar.
        await TestUtils.tapNavigationItem(
          'Find security gaps',
          tester,
          find,
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Wait for the page to fully load by checking for a radio button label.
        await TestUtils.waitForWidget(
          tester,
          find.text('One service'),
          timeout: const Duration(seconds: 10),
        );

        // Enter the IPv6 loopback address with brackets — the page must strip
        // them via normalizeTarget before passing to the DNS resolver.
        final targetField = find.byType(TextFormField).first;
        await tester.enterText(targetField, '[::1]');
        await tester.pumpAndSettle();

        // Select single-port scan mode by tapping the radio button widget directly.
        final radioButton = find.byKey(WidgetKey.singlePortScanRadioButton.key);
        await tester.ensureVisible(radioButton);
        await tester.tap(radioButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Wait for the port field to appear (it's conditionally rendered).
        final portField = find.byKey(WidgetKey.enterPortTextField.key);
        await TestUtils.waitForWidget(
          tester,
          portField,
          timeout: const Duration(seconds: 5),
        );

        // Enter the port the IPv6 server is listening on.
        await tester.enterText(portField, test_port.portIPv6.toString());
        await tester.pumpAndSettle();

        // Start the scan.
        final scanButton = find.byKey(WidgetKey.portScanButton.key);
        await tester.ensureVisible(scanButton);
        await tester.tap(scanButton);
        await tester.pumpAndSettle();

        // isOpen resolves in real async time (DNS lookup + socket connect).
        await TestUtils.waitForAnyWidget(
          tester,
          find.byType(AdaptiveListTile),
          timeout: const Duration(seconds: 30),
        );

        expect(find.byType(AdaptiveListTile), findsAtLeastNWidgets(1));
      },
    );
  });
}
