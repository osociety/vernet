import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

import 'network_troubleshooting_test/ping_test/ping_test.dart' as ping_test;
import 'wifi_test/wifi_test_runner.dart' as wifi_test_runner;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('app launch test', () {
    testWidgets('just test if app is able to launch and display homepage',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Verify that there are 4 widgets at homepage
      expect(find.bySubtype<AdaptiveListTile>(), findsAtLeastNWidgets(4));
    });
  });
  wifi_test_runner.main();
  ping_test.main();
}
