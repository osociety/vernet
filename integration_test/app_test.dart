// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureDependencies(Env.test);

  group('host scanner end-to-end test', () {
    testWidgets('just test if app is able to launch and display homepage',
        (tester) async {
      // Build our app and trigger a frame.
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));
    });

    testWidgets('tap on the scan for devices button, verify device found',
        (tester) async {
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));

      // Finds the scan for devices button to tap on.
      final devicesButton = find.byKey(
        const ValueKey(
          Keys.scanForDevicesButton,
        ),
      );

      // Emulate a tap on the button.
      await tester.tap(devicesButton);
      await tester.pump();
      expect(find.byType(AdaptiveListTile), findsAny);
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveListTile), findsAtLeast(2));

      // final routerIconButton = find.byKey(Keys.routerOrGatewayTileIconButton);

      // await tester.tap(routerIconButton);
      // await tester.pumpAndSettle();
      // expect(find.byType(AppBar), findsOne);

      // final radioButton = find.byKey(Keys.rangePortScanRadioButton);
      // await tester.tap(radioButton);
      // await tester.pump();

      // final fullRangeChip = find.byKey(Keys.fullPortChip);

      // await tester.tap(fullRangeChip);
      // await tester.pump();

      // final portScanButton = find.byKey(Keys.portScanButton);
      // await tester.tap(portScanButton);
    });
  });
}
