import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:vernet/values/keys.dart';

class TestUtils {
  static void configureAndroidChannelMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (methodCall) async {
        switch (methodCall.method) {
          case 'wifiIPAddress':
            return '192.168.1.10';
          case 'wifiBSSID':
            return '00:11:22:33:44:55';
          case 'wifiName':
            return 'Mock WiFi';
          case 'wifiGatewayAddress':
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
            'appName': 'Vernet',
            'packageName': 'org.fsociety.vernet',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return <String, dynamic>{
          'appName': 'Vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
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
    await _openDrawerWhenCompact(tester, find, 'Settings');
    final settingsItem = find.byKey(const ValueKey('sidebar-settings'));
    await tester.ensureVisible(settingsItem);
    await tester.tap(settingsItem);
    await _pumpTransition(tester);
  }

  static Future<void> tapHomeButton(
    WidgetTester tester,
    CommonFinders find,
  ) async {
    await tapNavigationItem('Home', tester, find);
  }

  static Future<void> tapNavigationItem(
    String label,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    final item = await _navigationItem(label, tester, find);
    await tester.ensureVisible(item);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(item);
    await _pumpTransition(tester);
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
    final navigationLabel = _navigationLabel(widgetKey);
    if (navigationLabel != null) {
      await tapNavigationItem(navigationLabel, tester, find);
      return;
    }
    final widget = find.byKey(widgetKey.key);
    await waitForWidget(tester, widget);
    await tester.ensureVisible(widget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(widget);
    await tester.pumpAndSettle();
  }

  static Future<void> scrollUntilVisibleByWidgetKey(
    WidgetKey widgetKey,
    WidgetTester tester,
    CommonFinders find,
    double scrollDistance,
  ) async {
    final navigationLabel = _navigationLabel(widgetKey);
    if (navigationLabel != null) {
      await _navigationItem(
        navigationLabel,
        tester,
        find,
        scrollDistance: scrollDistance,
      );
      return;
    }
    final widget = find.byKey(widgetKey.key);
    final scrollables =
        find.ancestor(of: widget, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(
      widget,
      scrollDistance,
      scrollable: scrollables.evaluate().isNotEmpty
          ? scrollables.first
          : find.byType(Scrollable).first,
    );
  }

  static Future<Finder> _navigationItem(
    String label,
    WidgetTester tester,
    CommonFinders find, {
    double scrollDistance = 300,
  }) async {
    await _openDrawerWhenCompact(tester, find, label);
    final target = find.text(label);
    final sidebarScrollable = find
        .descendant(
          of: find.byType(SidebarX).first,
          matching: find.byType(Scrollable),
        )
        .first;

    // SidebarX lazily builds menu rows. If the current selection has scrolled
    // Home above the viewport, scroll back toward the start so it is built.
    for (var attempt = 0;
        target.evaluate().isEmpty && attempt < 12;
        attempt++) {
      await tester.drag(sidebarScrollable, const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 100));
    }

    if (target.evaluate().isEmpty || target.hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        scrollDistance,
        scrollable: sidebarScrollable,
      );
    }
    final item = target.last;
    await tester.ensureVisible(item);
    await tester.pump(const Duration(milliseconds: 300));
    return item;
  }

  static Future<void> _openDrawerWhenCompact(
    WidgetTester tester,
    CommonFinders find,
    String label,
  ) async {
    final menuButton = find.byIcon(Icons.menu);
    if (menuButton.evaluate().isNotEmpty &&
        find.text(label).evaluate().isEmpty) {
      await tester.tap(menuButton);
      await _pumpTransition(tester);
    }
  }

  static Future<void> _pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  static String? _navigationLabel(WidgetKey key) => switch (key) {
        WidgetKey.homeButton => 'Home',
        WidgetKey.settingsButton => 'Settings',
        WidgetKey.ping => 'Check a website',
        WidgetKey.scanForOpenPortsButton => 'Find security gaps',
        WidgetKey.serverCheckerButton => 'Monitor server',
        WidgetKey.neighborDiscoveryButton => 'Find switch',
        WidgetKey.wakeOnLanButton => 'Wake on LAN',
        WidgetKey.dnsLookupButton => 'Find website addresses',
        WidgetKey.reverseDnsLookupButton => 'Find a device name',
        _ => null,
      };
}
