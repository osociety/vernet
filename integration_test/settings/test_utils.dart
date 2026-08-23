import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/values/keys.dart';

class TestUtils {
  static void configureAndroidChannelMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (methodCall) async {
        switch (methodCall.method) {
          case 'getWifiIP':
            return '192.168.1.10';
          case 'getWifiBSSID':
            return '00:11:22:33:44:55';
          case 'getWifiName':
            return 'Mock WiFi';
          case 'getWifiGatewayIP':
            return '192.168.1.1';
          default:
            return null;
        }
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          final permissions = (methodCall.arguments as List<dynamic>?) ?? [];
          return <int, int>{
            for (final permission in permissions) permission as int: 1,
          };
        }
        if (methodCall.method == 'checkPermissionStatus' ||
            methodCall.method == 'checkServiceStatus') {
          return 1;
        }
        return 1;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'vernet',
            'packageName': 'org.fsociety.vernet',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return <String, dynamic>{
          'appName': 'vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.demine/in_app_review'),
      (methodCall) async {
        if (methodCall.method == 'isAvailable') {
          return true;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (methodCall) async {
        switch (methodCall.method) {
          case 'areNotificationsEnabled':
            return true;
          case 'requestNotificationsPermission':
          case 'requestPermission':
          case 'requestExactAlarmsPermission':
            return true;
          case 'initialize':
            return true;
          default:
            return true;
        }
      },
    );
  }

  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsOneWidget);
  }

  static Future<void> waitForAnyWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsAtLeastNWidgets(1));
  }

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
    await waitForWidget(tester, widget);
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
