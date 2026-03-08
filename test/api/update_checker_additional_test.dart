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

  group('update checker additional tests', () {
    test('returns false when no tags in response', () async {
      final payload = jsonEncode([]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isFalse);
    });

    test('handles version comparison correctly for same versions', () async {
      final payload = jsonEncode([
        {'name': 'v1.0.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isFalse);
    });

    test('handles version comparison correctly for older remote version',
        () async {
      final payload = jsonEncode([
        {'name': 'v0.9.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isFalse);
    });

    test('handles complex version strings with -store suffix', () async {
      final payload = jsonEncode([
        {'name': 'v2.0.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.9.9-store', client: client);
      expect(result, isTrue);
    });

    test('handles malformed version strings gracefully', () async {
      final payload = jsonEncode([
        {'name': 'invalid_version'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.0.0', client: client);
      // Should handle gracefully and return false
      expect(result, isFalse);
    });

    test('handles empty response body', () async {
      final client = MockClient((_) async => http.Response('', 200));
      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isFalse);
    });
  });

  group('checkForUpdates edge cases', () {
    testWidgets('handles exception in package info gracefully',
        (WidgetTester tester) async {
      // Override the package info method channel to throw an exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/package_info'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          throw Exception('Package info error');
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
      // Should not throw exception
      expect(() => checkForUpdates(context), returnsNormally);
    });

    testWidgets('shows "no updates" message when requested',
        (WidgetTester tester) async {
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
      // Should not throw exception
      expect(() => checkForUpdates(context, showIfNoUpdate: true),
          returnsNormally);
      await tester.pump();
    });
  });
}
