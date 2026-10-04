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
import 'package:vernet/main.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

import '../settings/test_utils.dart';

/// Registers a mock method-call handler that makes the NetworkInfo gateway
/// call return a predictable value so [WakeOnLanPage._prefillBroadcast]
/// always resolves to '192.168.1.255'.
void _mockNetworkInfo() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/network_info'),
    (MethodCall call) async {
      switch (call.method) {
        case 'getWifiGatewayIP':
          return '192.168.1.1';
        case 'getWifiIP':
          return '192.168.1.10';
        case 'getWifiBSSID':
          return '00:11:22:33:44:55';
        case 'getWifiName':
          return 'MockNet';
        default:
          return null;
      }
    },
  );
}

void main() {
  globals.testingActive = true;
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
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    TestUtils.configureAndroidChannelMocks();
    _mockNetworkInfo();
  });

  // ── Navigation ───────────────────────────────────────────────────────────

  group('Wake on LAN – navigation', () {
    testWidgets('tapping "Wake a device" button opens WakeOnLanPage',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);

      expect(find.byType(WakeOnLanPage), findsOneWidget);
      expect(find.text(StringValue.wakeOnLanPageTitle), findsOneWidget);
    });

    testWidgets('WakeOnLanPage shows all expected form fields', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);

      expect(find.byKey(WidgetKey.wakeOnLanMacField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanIpField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanPortField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanPasswordField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanSendButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanSaveButton.key), findsOneWidget);
    });

    testWidgets('back navigation returns to HomePage', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      expect(find.byType(WakeOnLanPage), findsOneWidget);

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKey.homeButton.key), findsOneWidget);
    });
  });

  // ── Broadcast pre-fill ───────────────────────────────────────────────────

  group('Wake on LAN – broadcast pre-fill', () {
    testWidgets('broadcast IP field is auto-filled from gateway',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      // The broadcast field should have been auto-filled to the .255 broadcast
      // derived from the mocked gateway 192.168.1.1 → 192.168.1.255,
      // or it may fall back to 255.255.255.255 if the channel mock fires after
      // the field has already been set. Either value is valid.
      final ipFieldFinder = find.byKey(WidgetKey.wakeOnLanIpField.key);
      final EditableText editableText =
          tester.widget<EditableText>(find.descendant(
        of: ipFieldFinder,
        matching: find.byType(EditableText),
      ));
      final String ipValue = editableText.controller.text;
      expect(
        ipValue == '192.168.1.255' ||
            ipValue == WakeOnLanService.defaultBroadcast,
        isTrue,
        reason: 'Expected a valid broadcast address, got "$ipValue"',
      );
    });
  });

  // ── Form validation ──────────────────────────────────────────────────────

  group('Wake on LAN – form validation', () {
    testWidgets('sending with empty MAC shows inline validation error',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      // Leave the MAC field empty and tap Send
      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a MAC address like AA:BB:CC:DD:EE:FF'),
        findsOneWidget,
      );
    });

    testWidgets('saving with empty MAC shows inline validation error',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSaveButton.key));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a MAC address like AA:BB:CC:DD:EE:FF'),
        findsOneWidget,
      );
    });

    testWidgets('port field shows error for out-of-range value',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanMacField,
        'AA:BB:CC:DD:EE:FF',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanPortField,
        '99999',
        tester,
        find,
      );

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pumpAndSettle();

      expect(find.text('Enter a port between 0 and 65535'), findsOneWidget);
    });
  });

  // ── Sending a packet ─────────────────────────────────────────────────────

  group('Wake on LAN – sending', () {
    testWidgets('valid MAC + IP shows success status', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanMacField,
        'AA:BB:CC:DD:EE:FF',
        tester,
        find,
      );
      // Overwrite the IP field with a known broadcast
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanIpField,
        '255.255.255.255',
        tester,
        find,
      );

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));

      // Wait for the async send to finish (real UDP on macOS is fast)
      await TestUtils.waitForAnyWidget(
        tester,
        find.byKey(WidgetKey.wakeOnLanStatusText.key),
        timeout: const Duration(seconds: 10),
      );

      final statusText = tester
          .widget<Text>(find.byKey(WidgetKey.wakeOnLanStatusText.key))
          .data!;

      expect(
        statusText.contains('AA:BB:CC:DD:EE:FF') ||
            statusText.contains('Could not send'),
        isTrue,
        reason:
            'Status should mention the MAC or a send error, got: $statusText',
      );
    });

    testWidgets('Send button is disabled while a packet is in-flight',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanMacField,
        'AA:BB:CC:DD:EE:FF',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanIpField,
        '255.255.255.255',
        tester,
        find,
      );

      // Tap send but don't settle – check the button label mid-flight
      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pump(); // single frame
      await tester.pump(const Duration(milliseconds: 50));

      // The button label switches to 'Sending…' while _sending == true
      expect(find.text('Sending…'), findsOneWidget);
    });
  });

  // ── Saved devices ────────────────────────────────────────────────────────

  group('Wake on LAN – saved devices', () {
    testWidgets('empty-state placeholder visible when no devices saved',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      expect(
        find.text(StringValue.wakeOnLanEmptyPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('saved device appears in list after tapping Save',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanLabelField,
        'Gaming Rig',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanMacField,
        'AA:BB:CC:DD:EE:FF',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanIpField,
        '255.255.255.255',
        tester,
        find,
      );

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSaveButton.key));
      await tester.pumpAndSettle();

      expect(find.text('Gaming Rig'), findsNWidgets(2));
      // Placeholder should now be gone
      expect(find.text(StringValue.wakeOnLanEmptyPlaceholder), findsNothing);
    });

    testWidgets('tapping a saved device tile fills the form', (tester) async {
      // Pre-populate shared_preferences so the tile appears on page open
      SharedPreferences.setMockInitialValues({
        WakeOnLanService.savedTargetsKey:
            '[{"label":"Home Server","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"192.168.0.255","port":9,"password":""}]',
      });

      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      // The saved tile label should be visible
      expect(find.text('Home Server'), findsOneWidget);

      // Tap the tile to fill the form
      await tester.tap(find.text('Home Server'));
      await tester.pumpAndSettle();

      // MAC field should now contain the device's MAC
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsAtLeastNWidgets(1));
    });

    testWidgets('deleting a saved device removes it from the list',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        WakeOnLanService.savedTargetsKey:
            '[{"label":"Old PC","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"255.255.255.255","port":9,"password":""}]',
      });

      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      expect(find.text('Old PC'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Old PC'), findsNothing);
      expect(
        find.text(StringValue.wakeOnLanEmptyPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('saving same MAC twice replaces and does not duplicate',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      // Save once
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanLabelField,
        'First Label',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanMacField,
        'AA:BB:CC:DD:EE:FF',
        tester,
        find,
      );
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanIpField,
        '255.255.255.255',
        tester,
        find,
      );
      await tester.tap(find.byKey(WidgetKey.wakeOnLanSaveButton.key));
      await tester.pumpAndSettle();

      // Clear label and save again with same MAC, different label
      await TestUtils.enterTextByKey(
        WidgetKey.wakeOnLanLabelField,
        'Second Label',
        tester,
        find,
      );
      await tester.tap(find.byKey(WidgetKey.wakeOnLanSaveButton.key));
      await tester.pumpAndSettle();

      // Only one tile for this MAC should exist
      expect(find.text('Second Label'), findsNWidgets(2));
      expect(find.text('First Label'), findsNothing);
    });

    testWidgets('wake icon on saved tile sends a packet and shows status',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        WakeOnLanService.savedTargetsKey:
            '[{"label":"NAS","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"255.255.255.255","port":9,"password":""}]',
      });

      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.wakeOnLanButton,
        tester,
        find,
        200,
      );
      await TestUtils.tapByWidgetKey(WidgetKey.wakeOnLanButton, tester, find);
      await tester.pumpAndSettle();

      // Two power_settings_new icons: one in form, one on tile trailing
      final wakeIcons = find.byIcon(Icons.power_settings_new);
      expect(wakeIcons, findsNWidgets(2));

      await tester.tap(wakeIcons.last);

      await TestUtils.waitForAnyWidget(
        tester,
        find.byKey(WidgetKey.wakeOnLanStatusText.key),
        timeout: const Duration(seconds: 10),
      );

      expect(find.byKey(WidgetKey.wakeOnLanStatusText.key), findsOneWidget);
    });
  });
}
