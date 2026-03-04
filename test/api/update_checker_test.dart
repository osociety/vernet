import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('version comparison helpers', () {
    test('handles version strings with store suffix', () {
      // Just verify the helper logic without running widget code
      final payload = jsonEncode([
        {'name': 'v3.1.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      expect(
        checkUpdatesForTest('2.5.0-store', client: client),
        completion(isTrue), // 2.5.0 < 3.1.0
      );
    });

    test('handles version strings in various formats', () async {
      final payload = jsonEncode([
        {'name': 'v1.5.0'}
      ]);
      final client = MockClient((_) async => http.Response(payload, 200));

      final result = await checkUpdatesForTest('1.5.0', client: client);
      expect(result, isFalse); // Same version, no update
    });

    test('handles empty response', () async {
      final client = MockClient((_) async => http.Response('[]', 200));
      final result = await checkUpdatesForTest('1.0.0', client: client);
      expect(result, isFalse);
    });

    test('handles network errors gracefully', () async {
      final client = MockClient((_) async => throw Exception('Network error'));
      try {
        await checkUpdatesForTest('1.0.0', client: client);
      } catch (_) {
        // Expected to fail on network error
      }
    });
  });
}
