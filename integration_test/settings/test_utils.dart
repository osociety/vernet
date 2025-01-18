import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/keys.dart';

class TestUtils {
  static Future<void> tapSettingsButton(
    WidgetTester tester,
    CommonFinders find,
  ) async {
    await tapByWidgetKey(WidgetKey.settingsButton, tester, find);
  }

  static Future<void> tapHomeButton(
    WidgetTester tester,
    CommonFinders find,
  ) async {
    await tapByWidgetKey(WidgetKey.homeButton, tester, find);
  }

  static Future<void> tapByText(
    String text,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    final widget = find.text(text);
    await tester.tap(widget);
    await tester.pumpAndSettle();
  }

  static Future<void> enterTextByKey(
    WidgetKey widgetKey,
    String text,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    final textField = find.byKey(widgetKey.key);
    await tester.enterText(textField, text);
    await tester.pumpAndSettle();
  }

  static Future<void> tapByWidgetKey(
    WidgetKey widgetKey,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    final widget = find.byKey(widgetKey.key);
    await tester.tap(widget);
    await tester.pumpAndSettle();
  }

  static Future<void> scrollUntilVisibleByWidgetKey(
    WidgetKey widgetKey,
    WidgetTester tester,
    CommonFinders find,
    double scrollDistance,
  ) async {
    final widget = find.byKey(widgetKey.key);
    await tester.scrollUntilVisible(
      widget,
      scrollDistance,
      scrollable: find.byType(Scrollable),
    );
  }
}
