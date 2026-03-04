
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';

void main() {
  
  group('Run device scan on startup', () {
    testWidgets('if settings for startup is on, then it should run',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.tapByWidgetKey(
        WidgetKey.runOnAppStartupSwitch,
        tester,
        find,
      );

      await TestUtils.tapHomeButton(tester, find);

      // pump with a longer timeout to rebuild HomePage after navigation
      // and allow platform channels to respond
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(WidgetKey.runScanOnStartup.key), findsOne);
    });
  });

}
