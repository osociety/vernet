import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/repository/notification_service.dart';

import 'helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    configureDependencies(Env.test);
  });

  setUp(() {
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'Vernet',
        'packageName': 'org.fsociety.vernet',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => switch (call.method) {
        'wifiIPAddress' => '192.168.1.10',
        'wifiBSSID' => '00:11:22:33:44:55',
        'wifiName' => 'Mock WiFi',
        'wifiGatewayAddress' => '192.168.1.1',
        _ => null,
      },
    );
  });

  tearDown(() {
    NotificationService.skipPermissionRequests = false;
  });

  Future<void> pumpVisibleFrame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpTabBarPage(
    WidgetTester tester, {
    Size size = const Size(900, 800),
    Locale? locale,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DarkThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TabBarPage(),
        ),
      ),
    );
    await pumpVisibleFrame(tester);
  }

  group('MyApp', () {
    testWidgets('renders the redesigned entry point when allowed',
        (tester) async {
      await tester.pumpWidget(const MyApp(null));
      await pumpVisibleFrame(tester);

      expect(find.byType(TabBarPage), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders LocationConsentPage when access is not allowed',
        (tester) async {
      await tester.pumpWidget(const MyApp(OnboardingStage.consent));
      await pumpVisibleFrame(tester);

      expect(find.byType(LocationConsentPage), findsOneWidget);
    });

    testWidgets('navigator key is configured', (tester) async {
      await tester.pumpWidget(const MyApp(null));
      await pumpVisibleFrame(tester);

      expect(MyApp.navigatorKey.currentState, isNotNull);
    });

    // gen-l10n orders supportedLocales by ARB filename, so German is first and
    // Flutter's own fallback would render a Russian or Polish system in German
    // while appStrings() handed out English. The entry point resolves it now.
    testWidgets('an unsupported system language renders English, not German',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MyApp(null));
      await pumpVisibleFrame(tester);

      expect(
        Localizations.localeOf(tester.element(find.byType(TabBarPage))),
        const Locale('en'),
      );
      expect(find.text('Scan your network'), findsWidgets);
      expect(find.text('Netzwerk scannen'), findsNothing);
    });

    testWidgets('a supported system language still renders that language',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MyApp(null));
      await pumpVisibleFrame(tester);

      expect(
        Localizations.localeOf(tester.element(find.byType(TabBarPage))),
        const Locale('de'),
      );
      expect(find.text('Netzwerk scannen'), findsWidgets);
    });

    testWidgets('a saved choice beats the system language', (tester) async {
      SharedPreferences.setMockInitialValues({'LOCALESTATUS': 'de'});
      AppSettings.instance.resetForTesting();
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const MyApp(null));
      await pumpVisibleFrame(tester);

      expect(
        Localizations.localeOf(tester.element(find.byType(TabBarPage))),
        const Locale('de'),
      );
    });
  });

  group('Responsive entry-point navigation', () {
    testWidgets('desktop keeps the sidebar visible beside the home dashboard',
        (tester) async {
      await pumpTabBarPage(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Scan your network'), findsWidgets);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('sidebar selection replaces the main content', (tester) async {
      await pumpTabBarPage(tester);

      await tester.tap(find.text('Check a website'));
      await pumpVisibleFrame(tester);

      expect(find.byType(PingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.text('Check a website'), findsOneWidget);
    });

    testWidgets('the rail is reused, not rebuilt, when a page is chosen',
        (tester) async {
      await pumpTabBarPage(tester);

      final rail = tester.widget<SidebarX>(find.byType(SidebarX));

      await tester.tap(find.text('Check a website'));
      await pumpVisibleFrame(tester);

      // Selecting a destination notifies the controller, which repaints the rail
      // from inside; the shell itself must not rebuild on top of that, or the
      // eleven items and their callbacks are allocated twice per tap.
      expect(
        tester.widget<SidebarX>(find.byType(SidebarX)).items,
        same(rail.items),
      );
      expect(
        tester.widget<SidebarX>(find.byType(SidebarX)).theme,
        same(rail.theme),
      );
    });

    testWidgets('Settings and Home are available from the persistent menu',
        (tester) async {
      await pumpTabBarPage(tester);

      await tester.tap(find.text('Settings').last);
      await pumpVisibleFrame(tester);
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await pumpVisibleFrame(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('the shell renders in the selected locale', (tester) async {
      await pumpTabBarPage(tester, locale: const Locale('de'));

      // The scan label sits on the rail and on the dashboard's own button, and
      // both are German now that the button reads from the resource bundle.
      expect(find.text('Netzwerk scannen'), findsNWidgets(2));
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Scan your network'), findsNothing);
      expect(find.text('Monitor server'), findsNothing);

      await tester.tap(find.text('Einstellungen'));
      await pumpVisibleFrame(tester);

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('App-Einstellungen'), findsOneWidget);
      await tester.tap(find.text('App-Einstellungen'));
      await pumpVisibleFrame(tester);
      expect(find.text('Erscheinungsbild'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);
    });
  });

  // Android 15+ hands an app targeting SDK 35 or newer the whole window and
  // reports the bars only as view padding, so anything that ignores the
  // padding draws underneath them. osociety/vernet#428.
  // A page hosted by the shell used to paint its own AppBar under the shell's
  // compact one, so a phone showed the destination named twice with two bars
  // stacked. Desktop has no shell bar, so there the page bar stays the only
  // heading; a page pushed over the shell keeps its bar at any width.
  group('One heading per destination', () {
    const destinations = <(String shellTitle, String pageTitle)>[
      ('Check a website', 'Check connection'),
      ('Subnet calculator', 'IP subnet calculator'),
      ('Support Vernet', 'Support Vernet'),
    ];

    for (final (shellTitle, pageTitle) in destinations) {
      testWidgets('$shellTitle paints one AppBar and one heading on a phone',
          (tester) async {
        await pumpTabBarPage(tester, size: const Size(390, 844));

        await tester.tap(find.byIcon(Icons.menu));
        await pumpVisibleFrame(tester);
        await tester.tap(find.text(shellTitle).last);
        await pumpVisibleFrame(tester);

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(shellTitle), findsOneWidget);
        if (pageTitle != shellTitle) {
          expect(find.text(pageTitle), findsNothing);
        }
      });

      testWidgets('$shellTitle keeps the page heading on desktop',
          (tester) async {
        await pumpTabBarPage(tester);

        await tester.tap(find.text(shellTitle).first);
        await pumpVisibleFrame(tester);

        expect(find.byType(AppBar), findsOneWidget);
        if (pageTitle != shellTitle) {
          expect(find.text(pageTitle), findsOneWidget);
        }
      });
    }
  });

  // The scan page's AppBar also carried its history action, which the compact
  // shell has no slot for; test/pages/host_scan_page/host_scan_page_test.dart
  // follows that button into the results header.
  group('Edge-to-edge insets', () {
    // HomePage and SettingsPage own no Scaffold of their own, so this also
    // proves the shell is what keeps them out of the navigation bar.
    testWidgets(
      'the compact shell clears the status bar and the navigation bar',
      (tester) async {
        await pumpTabBarPage(tester, size: const Size(390, 844));
        fakeSystemBarInsets(tester);
        await tester.pump();

        expect(
          tester.getSize(find.byType(AppBar)).height,
          greaterThanOrEqualTo(kToolbarHeight + kTestStatusBarInset),
          reason: 'the AppBar must grow to cover the status bar inset',
        );
        expect(
          tester.getBottomLeft(find.byType(ListView).first).dy,
          lessThanOrEqualTo(safeBottom(tester)),
          reason: 'dashboard content must not sit under the navigation bar',
        );
      },
    );

    // The drawer is Scaffold's own surface, not the body, so the shell's
    // SafeArea does not reach it: its footer row is pinned to the panel bottom
    // and needs the inset on its own.
    testWidgets('the compact drawer clears the navigation bar', (tester) async {
      await pumpTabBarPage(tester, size: const Size(390, 844));
      fakeSystemBarInsets(tester);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await pumpVisibleFrame(tester);

      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('sidebar-settings'))).dy,
        lessThanOrEqualTo(safeBottom(tester)),
        reason: 'the drawer footer must not sit under the navigation bar',
      );
    });
  });
}
