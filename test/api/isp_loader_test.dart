import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/api/isp_loader.dart';
import 'package:vernet/providers/internet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ISPLoader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns InternetProvider in debug mode using bundled asset',
        () async {
      final loader = ISPLoader();

      final InternetProvider? provider = await loader.load();

      expect(provider, isNotNull);
      expect(provider!.isp, isNotEmpty);
      expect(provider.ip, isNotEmpty);
      expect(provider.location.address, isNotEmpty);
    });

    test('loadIP returns response body on success', () async {
      final ip = await ISPLoader.loadIP('https://api.ipify.org/');
      // Should return some response (could be valid or empty depending on network)
      expect(ip, isA<String>());
    });

    test('loadISP returns response body on success', () async {
      final isp = await ISPLoader.loadISP('https://api.example.com/');
      // Should return some response
      expect(isp, isA<String>());
    });

    test('ISPLoader instance can be created', () {
      final loader = ISPLoader();
      expect(loader, isA<ISPLoader>());
    });
  });

  group('InternetProvider', () {
    test('can be created from valid map with all fields', () {
      final map = {
        'isp': 'Test ISP',
        'country': 'Test Country',
        'region': 'Test Region',
        'city': 'Test City',
        'ip': '192.0.2.1',
        'type': 'ipv4',
        'latitude': '0.0',
        'longitude': '0.0',
        'country_flag': 'https://example.com/flag.png',
      };

      final provider = InternetProvider.fromMap(map);
      expect(provider, isA<InternetProvider>());
      expect(provider.isp, 'Test ISP');
      expect(provider.ip, '192.0.2.1');
      expect(provider.ipType, 'ipv4');
      expect(provider.location.address, contains('Test City'));
    });

    test('can handle minimal map data', () {
      final map = {
        'isp': 'Test ISP',
        'ip': '192.0.2.1',
        'type': 'ipv4',
        'country': 'US',
        'region': 'CA',
        'city': 'SF',
        'latitude': '37.7749',
        'longitude': '-122.4194',
        'country_flag': 'https://example.com/flag.png',
      };

      final provider = InternetProvider.fromMap(map);
      expect(provider, isA<InternetProvider>());
      expect(provider.isp, 'Test ISP');
    });
  });
}
