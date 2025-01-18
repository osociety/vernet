import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

void main() {
  group('In App Internet Test', () {
    testWidgets('test', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.tapByWidgetKey(
        WidgetKey.inAppInternetSwitch,
        tester,
        find,
      );

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.checkForUpdatesButton,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.checkForUpdatesButton,
        tester,
        find,
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}
