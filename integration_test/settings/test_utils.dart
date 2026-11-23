import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/values/keys.dart';

class TestUtils {
  /// [child] as the home of a MaterialApp carrying the app's real
  /// localization delegates.
  ///
  /// `context.l10n` throws when the delegates are absent, so a suite that pumps
  /// a page directly instead of driving `MyApp` has to supply them itself.
  static Widget wrapWithLocalizations({
    required Widget child,
    Locale locale = const Locale('en'),
  }) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

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

  /// Drops focus and hides the soft keyboard so the lower part of the screen
  /// becomes tappable again.
  ///
  /// The keyboard is a separate Android window, so it swallows taps that land
  /// on it. Normally `Scaffold.resizeToAvoidBottomInset` moves widgets out of
  /// its way, but the integration test view reports zero `MediaQuery.viewInsets`
  /// even while the keyboard is up, so the layout never shrinks and anything
  /// below the keyboard line stays un-tappable.
  ///
  /// The wait is in real time, not in frames: closing the input connection only
  /// *starts* the window dismissal, and `pumpAndSettle` returns as soon as
  /// Flutter has no frames left to draw while the Android window is still
  /// animating out. A tap issued in that window is silently dropped, which is
  /// how one integration leg goes red on one run and green on the next (#604).
  static Future<void> hideKeyboard(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Scrolls [target] into view, but only when it is not already reachable.
  ///
  /// Two hazards make a bare `ensureVisible` the wrong tool here. A `ListView`
  /// child outside the cache extent has no element yet, and `ensureVisible`
  /// answers that with `Bad state: No element`; and it scrolls a widget to the
  /// *edge* of the viewport, which on Android is inside the keyboard window, so
  /// the tap after it still lands on the IME. Dragging [scrollable] toward the
  /// end builds the child instead and leaves room above it.
  ///
  /// A target already built and on screen is left where it is: scrolling the
  /// list would unbuild the widgets above it, and callers read those (the form
  /// fields, the just-tapped button) right after revealing.
  ///
  /// The loop and its failure message follow the sidebar reveal in
  /// [_navigationItem]: the framework's `dragUntilVisible` ends in
  /// `element(finder)` too, so it would throw the same unhelpful error once its
  /// iterations run out.
  static Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    required Finder scrollable,
    double scrollDelta = 240,
    int maxDrags = 40,
  }) async {
    await hideKeyboard(tester);
    if (target.evaluate().isNotEmpty && _isOnScreen(tester, target)) {
      // Already reachable: scrolling away would unbuild the widgets above the
      // target, and several callers read those right after.
      await tester.pumpAndSettle();
      return;
    }
    for (var attempt = 0;
        target.evaluate().isEmpty && attempt < maxDrags;
        attempt++) {
      await tester.drag(scrollable, Offset(0, -scrollDelta));
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (target.evaluate().isEmpty) {
      final built = find
          .descendant(of: scrollable, matching: find.byType(Text))
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .whereType<String>()
          .take(20)
          .toList();
      fail(
        '${target.description} was never built after $maxDrags drags of '
        '$scrollDelta px.'
        ' view=${tester.view.physicalSize}@${tester.view.devicePixelRatio}x'
        ' list=${tester.getRect(scrollable)} builtTexts=$built',
      );
    }
    await tester.ensureVisible(target);
    // The jump above changes the scroll offset without laying out again, so the
    // rect a tap uses next is stale until the following frame.
    await tester.pump();
    await tester.pumpAndSettle();
  }

  static bool _isOnScreen(WidgetTester tester, Finder target) {
    final view = tester.view;
    final screen = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
    final rect = tester.getRect(target);
    return rect.left >= 0 &&
        rect.top >= 0 &&
        rect.right <= screen.width &&
        rect.bottom <= screen.height;
  }

  static Future<void> revealAndTap(
    WidgetTester tester,
    Finder target, {
    required Finder scrollable,
  }) async {
    await reveal(tester, target, scrollable: scrollable);
    await tester.tap(target);
    await tester.pumpAndSettle();
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

  static Future<void> tapSettingsCategory(
    WidgetKey category,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    await tapByWidgetKey(category, tester, find);
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

  /// Focuses the field behind [widgetKey] and makes sure [text] is in it.
  ///
  /// `tester.enterText` does not type: it sends a fake
  /// `TextInputClient.updateEditingState` straight to the focused field
  /// (test_text_input.dart). On a live device the platform IME is attached to
  /// that same field and reports its own — empty — value, and whichever of the
  /// two arrives last wins. When the platform one lands second the field is
  /// left empty with no error anywhere, so the form below it validates false,
  /// the button reports nothing, and the failure surfaces as a missing widget
  /// in an unrelated assertion. That is the nondeterminism in #604.
  ///
  /// So re-inject while the field reads back empty, and name it if it never
  /// fills. A field that holds something *other* than [text] is left alone:
  /// that is the app's own formatter or pre-fill, and the caller's assertion on
  /// the resulting status is the one that should judge it.
  static Future<void> enterTextByKey(
    WidgetKey widgetKey,
    String text,
    WidgetTester tester,
    CommonFinders find,
  ) async {
    final textField = find.byKey(widgetKey.key);
    // On a live device text only reaches the field the platform keyboard is
    // attached to, so focus it with a real tap first. That tap needs the
    // keyboard out of the way, which the fake test view never accounts for.
    await hideKeyboard(tester);
    await tester.ensureVisible(textField);
    await tester.pumpAndSettle();
    await tester.tap(textField);
    await tester.pumpAndSettle();

    for (var attempt = 1; attempt <= 4; attempt++) {
      await tester.enterText(textField, text);
      await tester.pumpAndSettle();
      // Give a competing platform update time to land before reading back, so
      // a value that is about to be overwritten is not accepted as good.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      final actual = _fieldText(tester, textField);
      if (actual == text) {
        return;
      }
      if (actual != null && actual.trim().isNotEmpty) {
        // A formatter rewrote the input — uppercasing, separators, a length
        // cap. That is the app normalizing, not the race, so leave it for the
        // caller's own assertions rather than fighting the field with retries.
        return;
      }
      if (attempt == 4) {
        fail(
          '${widgetKey.value} was still empty after $attempt attempts to enter '
          '"$text" — the platform IME keeps overwriting the injected value '
          '(#604).',
        );
      }
      // Re-attach before retrying: an IME that has taken the connection back
      // will keep answering for the field until it is focused again.
      await tester.tap(textField);
      await tester.pumpAndSettle();
    }
  }

  static String? _fieldText(WidgetTester tester, Finder field) {
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    if (editable.evaluate().isEmpty) {
      return null;
    }
    return tester.widget<EditableText>(editable.first).controller.text;
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

    // Reveal the row by dragging toward the end of the list. This is the
    // direction scrollUntilVisible() picks for a vertical list, done here
    // because that helper ends in element(finder), which on a row that never
    // got built throws "Bad state: No element" and says nothing about why.
    for (var attempt = 0;
        target.evaluate().isEmpty && attempt < 50;
        attempt++) {
      await tester.drag(sidebarScrollable, Offset(0, -scrollDistance));
      await tester.pump(const Duration(milliseconds: 50));
    }

    if (target.evaluate().isEmpty) {
      fail(
          'Sidebar row "$label" was never built.${_describeShell(tester, find)}');
    }
    final item = target.last;
    await tester.ensureVisible(item);
    await tester.pump(const Duration(milliseconds: 300));
    return item;
  }

  /// The window and shell the suite is looking at, for a navigation failure.
  ///
  /// Desktop legs run in a window the suite does not size, so a sidebar row
  /// can sit past the built region of the list; the row's absence is only
  /// readable when the failure carries the geometry and the rows that did
  /// build.
  static String _describeShell(WidgetTester tester, CommonFinders find) {
    final sidebar = find.byType(SidebarX);
    if (sidebar.evaluate().isEmpty) {
      return ' view=${tester.view.physicalSize}@${tester.view.devicePixelRatio}x'
          ' drawer=${find.byIcon(Icons.menu).evaluate().isNotEmpty}'
          ' no SidebarX is mounted, so the shell never rendered.';
    }
    final labels = find
        .descendant(of: sidebar.first, matching: find.byType(Text))
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .toList();
    return ' view=${tester.view.physicalSize}@${tester.view.devicePixelRatio}x'
        ' sidebar=${tester.getRect(sidebar.first)}'
        ' drawer=${find.byIcon(Icons.menu).evaluate().isNotEmpty}'
        ' builtLabels=$labels';
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
