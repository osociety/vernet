import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/helper/dark_theme_preference.dart';
import 'package:vernet/main.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

void main() {
  globals.testingActive = true;
  group('Test if theme preference is set properly', () {
    testWidgets('theme preference cycle test', (tester) async {
      final darkThemePreference = DarkThemePreference();
      // Ensure it starts as system
      expect(await darkThemePreference.getTheme(), ThemePreference.system);

      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Change to Dark
      await TestUtils.tapSettingsButton(tester, find);
      await tester.tap(find.byKey(WidgetKey.changeThemeTile.key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKey.darkThemeRadioButton.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await darkThemePreference.getTheme(), ThemePreference.dark);

      // Change to Light
      await tester.tap(find.byKey(WidgetKey.changeThemeTile.key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKey.lightThemeRadioButton.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await darkThemePreference.getTheme(), ThemePreference.light);

      // Change to System
      await tester.tap(find.byKey(WidgetKey.changeThemeTile.key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKey.systemThemeRadioButton.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await darkThemePreference.getTheme(), ThemePreference.system);
    });
  });
}
