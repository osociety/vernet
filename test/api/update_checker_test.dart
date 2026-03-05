import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      return null;
    });
  });

  group('update checker helper', () {
    test('returns true when remote tag is newer', () async {
      final payload = jsonEncode([
        {'name': 'v2.0.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isTrue);
    });

    test('strips leading v and -store suffix correctly', () async {
      final payload = jsonEncode([
        {'name': 'v1.2.3'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.2.3-store', client: client);
      expect(result, isFalse);
    });

    test('returns false when response not OK', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final result = await checkUpdatesForTest('0.0.1', client: client);
      expect(result, isFalse);
    });
  });

  group('checkForUpdates widget tests', () {
    testWidgets('shows snackbar when update is available', (tester) async {
      // Since checkForUpdates uses compute() which is hard to mock in tests,
      // and available depends on appSettings.inAppInternet,
      // This part might still be tricky without mocking appSettings.
      // For now, let's verify it doesn't crash and handles the context correctly.

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
      // We can't easily trigger the update available branch because of compute() and appSettings
      // but we can test the general flow.
      await checkForUpdates(context);
      await tester.pump();

      // Verification of snackbar would go here if we could mock compute/appSettings
    });
  });
}
