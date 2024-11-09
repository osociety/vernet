import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/keys.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureDependencies(Env.test);
  final appDocDirectory = await getApplicationDocumentsDirectory();
  await configureNetworkToolsFlutter(appDocDirectory.path);
  group('end-to-end test', () {
    testWidgets('tap on the floating action button, verify counter',
        (tester) async {
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

      // Trigger a frame.
      await tester.pumpAndSettle();

      // Verify that the scan completes
      expect(
        find.byKey(const ValueKey(Keys.rescanIconButton)),
        findsOneWidget,
      );
      expect(find.byType(AdaptiveListTile), findsAny);
    });
  });
}
