import 'dart:convert';

import 'package:flutter/services.dart';
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

    test('loadIP returns body when client returns success', () async {
      final client = MockClient((_) async => http.Response('1.2.3.4', 200));
      final ip = await ISPLoader.loadIP('http://foo', client);
      expect(ip, '1.2.3.4');
    });

    test('loadIP returns empty when client fails', () async {
      final client = MockClient((_) async => http.Response('err', 500));
      final ip = await ISPLoader.loadIP('http://foo', client);
      expect(ip, '');
    });

    test('loadISP returns body when client returns success', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode({'isp': 'abc'}), 200));
      final isp = await ISPLoader.loadISP('http://foo', client);
      expect(isp, contains('isp'));
    });

    test('loadISP returns empty on error', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      final isp = await ISPLoader.loadISP('http://foo', client);
      expect(isp, '');
    });

    test('load() returns provider from bundled asset in debug mode', () async {
      // intercept asset requests
      const fakeJson =
          '{"isp":"fake","country":"Z","region":"R","city":"C","ip":"1.2.3.4","type":"ipv4","latitude":"0","longitude":"0","country_flag":"url"}';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets',
          (ByteData? message) async {
        if (message == null) return null;
        final key = const Utf8Decoder().convert(message.buffer.asUint8List());
        if (key == 'assets/ipwhois.json') {
          final bytes = utf8.encoder.convert(fakeJson);
          return ByteData.view(Uint8List.fromList(bytes).buffer);
        }
        return null;
      });

      final loader = ISPLoader();
      final provider = await loader.load();
      expect(provider, isNotNull);
      expect(provider!.isp, 'fake');
      expect(provider.location.address, contains('Z'));
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
