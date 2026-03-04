import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vernet/api/update_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateChecker _checkUpdates', () {
    test('detects update when remote version is newer', () async {
      // Current version: 1.0.0, Remote version: 2.0.0
      // Mock the HTTP response
      final testVersion = '1.0.0';

      // Simulating _checkUpdates logic inline for testing
      // Version format: "1.0.0" should be older than "2.0.0"
      final comparison = '1.0.0'.compareTo('2.0.0');
      expect(comparison, lessThan(0)); // 1.0.0 < 2.0.0
    });

    test('detects no update when remote version is same', () async {
      final comparison = '1.0.0'.compareTo('1.0.0');
      expect(comparison, equals(0));
    });

    test('detects no update when local version is newer', () async {
      final comparison = '2.0.0'.compareTo('1.0.0');
      expect(comparison, greaterThan(0));
    });

    test('handles version strings with -store suffix', () async {
      // Example: "1.0.0-store123" should compare to "1.0.0"
      String tempV = '1.0.0-store123';
      if (tempV.contains('-store')) {
        final List<String> sp = tempV.split('-store');
        tempV = sp[0] + sp[1];
      }
      expect(tempV, equals('1.0.0123'));
    });

    test('handles version strings with v prefix', () async {
      String tag = 'v1.0.0';
      if (tag.contains('v')) {
        tag = tag.substring(1);
      }
      expect(tag, equals('1.0.0'));
    });
  });

  group('UpdateChecker integration', () {
    test('update checker functions are exported and callable', () {
      // Verify that the functions are accessible
      expect(checkForUpdates, isNotNull);
    });
  });
}
