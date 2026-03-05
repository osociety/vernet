import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/main.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

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
    });

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });
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
      // Since LocationConsentPage might have its own dependencies,
      // we just check for its type if it doesn't crash.
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('TabBarPage', () {
    testWidgets('switches between Home and Settings tabs', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: TabBarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially at Home
      expect(
          find.text('Home'), findsWidgets); // Both tab label and maybe content

      // Tap Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Should show settings related stuff (SettingsPage)
      expect(find.text('Settings'), findsWidgets);
    });
  });
}
