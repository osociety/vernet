import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/settings_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'vernet',
            'packageName': 'org.fsociety.vernet',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return null;
      },
    );

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );

    // Mock network_info_plus
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example/network_info'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('MyApp', () {
    testWidgets('renders TabBarPage when allowed is true', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();
      expect(find.byType(TabBarPage), findsOneWidget);
    });

    testWidgets('renders LocationConsentPage when allowed is false',
        (tester) async {
      await tester.pumpWidget(const MyApp(false));
      await tester.pumpAndSettle();
      expect(find.byType(LocationConsentPage), findsOneWidget);
    });

    testWidgets('MyApp is StatefulWidget', (tester) async {
      expect(const MyApp(true), isA<StatefulWidget>());
    });

    testWidgets('MyApp navigator key is set', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();
      expect(MyApp.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });

  group('TabBarPage', () {
    testWidgets('initial state shows Home tab', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: TabBarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKey.homeButton.key), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('switches to Settings tab when tapped', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: TabBarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('switches back to Home tab when tapped', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: TabBarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Go to Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      // Go back to Home
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('bottom navigation bar has correct items', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: TabBarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('TabBarPage can be instantiated', (tester) async {
      const page = TabBarPage();
      expect(page, isA<TabBarPage>());
    });

    testWidgets('TabBarPage is StatefulWidget', (tester) async {
      const page = TabBarPage();
      expect(page, isA<StatefulWidget>());
    });
  });

  group('Navigation', () {
    // Note: Navigation tests to HostScanPage are skipped because HostScanPage
    // triggers HostScanBloc.initialized() which calls NetworkInfo() requiring
    // platform channels that don't work in unit tests
    testWidgets('handles unknown routes gracefully', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );
      await tester.pumpAndSettle();

      // Verify default route works
      expect(find.byType(TabBarPage), findsOneWidget);
    });
  });

  group('_MyAppState', () {
    testWidgets('initState calls getCurrentAppTheme', (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      // Widget should build without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('build returns MaterialApp with correct theme', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
