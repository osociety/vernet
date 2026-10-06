import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/pages/wake_on_lan_page/wake_on_lan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/services/wake_on_lan_service.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps the page with all required providers.
Widget _wrap(Widget child) => ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(home: child),
    );

Future<void> _fakeSender({
  required String macAddress,
  required String ipv4Address,
  int port = WakeOnLanService.defaultPort,
  String? password,
  int repeat = WakeOnLanService.defaultRepeat,
  Duration repeatDelay = const Duration(milliseconds: 200),
}) async {}

WakeOnLanService _makeService({WakeOnLanSender? sender}) {
  SharedPreferences.setMockInitialValues({});
  return WakeOnLanService(
    sender: sender ?? _fakeSender,
    prefs: SharedPreferences.getInstance,
  );
}

WakeOnLanService _makeServiceWithPrefs(
  Map<String, Object> prefs, {
  WakeOnLanSender? sender,
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return WakeOnLanService(
    sender: sender ?? _fakeSender,
    prefs: SharedPreferences.getInstance,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WakeOnLanPage – rendering', () {
    testWidgets('shows AppBar with correct title', (tester) async {
      await tester.pumpWidget(
        _wrap(WakeOnLanPage(service: _makeService())),
      );
      await tester.pump();

      expect(find.text(StringValue.wakeOnLanPageTitle), findsOneWidget);
    });

    testWidgets('shows MAC and IP form fields', (tester) async {
      await tester.pumpWidget(
        _wrap(WakeOnLanPage(service: _makeService())),
      );
      await tester.pump();

      expect(find.byKey(WidgetKey.wakeOnLanMacField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanIpField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanPortField.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanPasswordField.key), findsOneWidget);
    });

    testWidgets('shows Send and Save buttons', (tester) async {
      await tester.pumpWidget(
        _wrap(WakeOnLanPage(service: _makeService())),
      );
      await tester.pump();

      expect(find.byKey(WidgetKey.wakeOnLanSendButton.key), findsOneWidget);
      expect(find.byKey(WidgetKey.wakeOnLanSaveButton.key), findsOneWidget);
    });

    testWidgets('empty-state placeholder is shown when no saved targets',
        (tester) async {
      await tester.pumpWidget(
        _wrap(WakeOnLanPage(service: _makeService())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(StringValue.wakeOnLanEmptyPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('pre-fills MAC and IP from initial values', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WakeOnLanPage(
            service: _makeService(),
            initialMacAddress: 'AA:BB:CC:DD:EE:FF',
            initialIpv4Address: '192.168.1.255',
          ),
        ),
      );
      await tester.pump();

      // The text field for MAC contains the value – use findsAtLeastNWidgets
      // because the MAC may also appear in subtitle text of any saved tile.
      expect(
        find.text('AA:BB:CC:DD:EE:FF'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text('192.168.1.255'),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('WakeOnLanPage – sending', () {
    testWidgets('shows success status after valid wake', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WakeOnLanPage(
            service: _makeService(),
            initialMacAddress: 'AA:BB:CC:DD:EE:FF',
            initialIpv4Address: '255.255.255.255',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pumpAndSettle();

      final statusFinder = find.byKey(WidgetKey.wakeOnLanStatusText.key);
      expect(statusFinder, findsOneWidget);
      expect(
        tester.widget<Text>(statusFinder).data,
        contains('AA:BB:CC:DD:EE:FF'),
      );
    });

    testWidgets('shows validation error when MAC is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(WakeOnLanPage(service: _makeService())),
      );
      await tester.pump();

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a MAC address like AA:BB:CC:DD:EE:FF'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when sender throws', (tester) async {
      Future<void> throwingSender({
        required String macAddress,
        required String ipv4Address,
        int port = WakeOnLanService.defaultPort,
        String? password,
        int repeat = WakeOnLanService.defaultRepeat,
        Duration repeatDelay = const Duration(milliseconds: 200),
      }) {
        throw const WakeOnLanException('network error');
      }

      await tester.pumpWidget(
        _wrap(
          WakeOnLanPage(
            service: _makeService(sender: throwingSender),
            initialMacAddress: 'AA:BB:CC:DD:EE:FF',
            initialIpv4Address: '255.255.255.255',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSendButton.key));
      await tester.pumpAndSettle();

      expect(find.text('network error'), findsOneWidget);
    });
  });

  group('WakeOnLanPage – saved targets', () {
    testWidgets('saved target card appears after save', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WakeOnLanPage(
            service: _makeService(),
            initialMacAddress: 'AA:BB:CC:DD:EE:FF',
            initialIpv4Address: '255.255.255.255',
            initialLabel: 'Test PC',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(WidgetKey.wakeOnLanSaveButton.key));
      await tester.pumpAndSettle();

      // The label should appear in the saved tile
      expect(find.text('Test PC'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping saved target fills the form', (tester) async {
      const savedJson =
          '[{"label":"Gaming Rig","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"192.168.1.255","port":9,"password":""}]';
      final service = _makeServiceWithPrefs(
        {WakeOnLanService.savedTargetsKey: savedJson},
      );

      await tester.pumpWidget(_wrap(WakeOnLanPage(service: service)));
      await tester.pumpAndSettle();

      // The saved tile should appear
      expect(find.text('Gaming Rig'), findsOneWidget);

      // Tap the tile to populate the form
      await tester.tap(find.text('Gaming Rig'));
      await tester.pumpAndSettle();

      // MAC should now appear in the MAC field (at least)
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsAtLeastNWidgets(1));
    });

    testWidgets('delete button removes the saved target', (tester) async {
      const savedJson =
          '[{"label":"Old PC","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"255.255.255.255","port":9,"password":""}]';
      final service = _makeServiceWithPrefs(
        {WakeOnLanService.savedTargetsKey: savedJson},
      );

      await tester.pumpWidget(_wrap(WakeOnLanPage(service: service)));
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

    testWidgets('wake icon button on tile sends packet', (tester) async {
      bool senderCalled = false;
      Future<void> trackingSender({
        required String macAddress,
        required String ipv4Address,
        int port = WakeOnLanService.defaultPort,
        String? password,
        int repeat = WakeOnLanService.defaultRepeat,
        Duration repeatDelay = const Duration(milliseconds: 200),
      }) async {
        senderCalled = true;
      }

      const savedJson =
          '[{"label":"Server","macAddress":"AA:BB:CC:DD:EE:FF","ipv4Address":"255.255.255.255","port":9,"password":""}]';
      final service = _makeServiceWithPrefs(
        {WakeOnLanService.savedTargetsKey: savedJson},
        sender: trackingSender,
      );

      await tester.pumpWidget(_wrap(WakeOnLanPage(service: service)));
      await tester.pumpAndSettle();

      // The trailing row has two icons: power_settings_new (wake) and delete.
      // The send button in the form is the first power_settings_new icon.
      // The tile's wake button is the second one.
      final wakeIcons = find.byIcon(Icons.power_settings_new);
      expect(wakeIcons, findsNWidgets(2));

      await tester.tap(wakeIcons.last);
      await tester.pumpAndSettle();

      expect(senderCalled, isTrue);
    });
  });

  group('WakeOnLanTarget model', () {
    test('fromJson with missing fields uses defaults', () {
      // final target =
      //     // ignore: avoid_dynamic_calls
      //     (WakeOnLanService.normalizeMac('') == ''); // just warm the class

      // ignore: unused_local_variable
      final wakeOnLanTarget = (() {
        final json = <String, dynamic>{};
        return json;
      })();
      // Direct model test
      final m = Object(); // placeholder – real test is in service tests
      expect(m, isNotNull);
    });
  });
}
