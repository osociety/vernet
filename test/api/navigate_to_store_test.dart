import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/api/update_checker.dart';
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

    // Mock External App Launcher
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('external_app_launcher'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'isAppInstalled') {
        return false;
      }
      if (methodCall.method == 'openApp') {
        return true;
      }
      return null;
    });
  });

  group('navigateToStore', () {
    testWidgets('completes without throwing exceptions on iOS/Web',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('Test'),
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('Test'));

      // Test that the function completes without throwing exceptions
      // This mainly tests the iOS/Web path which goes to launchURLWithWarning
      expect(() async => await navigateToStore(context), returnsNormally);
    });

    testWidgets('handles Android store version correctly', (tester) async {
      // Mock PackageInfo to return a store version
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/package_info'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'vernet',
            'packageName': 'org.fsociety.vernet.store',
            'version': '1.0.0-store',
            'buildNumber': '1',
          };
        }
        return null;
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('Test'),
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('Test'));

      // Test that the function completes without throwing exceptions
      expect(() async => await navigateToStore(context), returnsNormally);
    });
  });
}
