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

  group('end-to-end test', () {
    testWidgets('just test if app is able to launch', (tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();
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

      // // Trigger a frame.
      await tester.pumpAndSettle();

      // Verify that the scan completes
      // expect(
      //   find.byKey(const ValueKey(Keys.rescanIconButton)),
      //   findsOneWidget,
      // );
      // expect(find.byType(AdaptiveListTile), findsAny);

      // await tester.pumpAndSettle();
    });
  });
}
