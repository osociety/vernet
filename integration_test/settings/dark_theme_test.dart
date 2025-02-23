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
    testWidgets('dark theme test', (tester) async {
      final darkThemePreference = DarkThemePreference();
      expect(await darkThemePreference.getTheme(), ThemePreference.system);

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      final changeThemeButton = find.byKey(WidgetKey.changeThemeTile.key);
      await tester.tap(changeThemeButton);
      await tester.pumpAndSettle();

      final darkThemeTileButton =
          find.byKey(WidgetKey.darkThemeRadioButton.key);
      await tester.tap(darkThemeTileButton);
      await tester.pumpAndSettle();

      expect(await darkThemePreference.getTheme(), ThemePreference.dark);
    });

    testWidgets('light theme test', (tester) async {
      final darkThemePreference = DarkThemePreference();
      expect(await darkThemePreference.getTheme(), ThemePreference.dark);

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      final changeThemeButton = find.byKey(WidgetKey.changeThemeTile.key);
      await tester.tap(changeThemeButton);
      await tester.pumpAndSettle();

      final darkThemeTileButton =
          find.byKey(WidgetKey.lightThemeRadioButton.key);
      await tester.tap(darkThemeTileButton);
      await tester.pumpAndSettle();

      expect(await darkThemePreference.getTheme(), ThemePreference.light);
    });

    testWidgets('system theme test', (tester) async {
      final darkThemePreference = DarkThemePreference();
      expect(await darkThemePreference.getTheme(), ThemePreference.light);

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      final changeThemeButton = find.byKey(WidgetKey.changeThemeTile.key);
      await tester.tap(changeThemeButton);
      await tester.pumpAndSettle();

      final darkThemeTileButton =
          find.byKey(WidgetKey.systemThemeRadioButton.key);
      await tester.tap(darkThemeTileButton);
      await tester.pumpAndSettle();

      expect(await darkThemePreference.getTheme(), ThemePreference.system);
    });
  });
}
