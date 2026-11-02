import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/services/speedtest/ndt7_service.dart';

class MockWebSocket implements WebSocket {
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final List<dynamic> sentMessages = [];
  bool _closed = false;

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _closed = true;
    await _controller.close();
  }

  void addMessage(dynamic message) {
    if (!_closed) {
      _controller.add(message);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WebSocket> _dummyWebSocketFactory(
  String url, {
  List<String>? protocols,
}) =>
    throw UnimplementedError('WebSocket not needed for discoverServers tests');

void main() {
  group('Ndt7Service', () {
    group('discoverServers', () {
      test('returns list of servers on successful API call', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('locate.measurementlab.net'));
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'machine': 'ndt-mlab1-lga0t.mlab1.test',
                  'site': 'lga0t',
                  'urls': {
                    'wss:///ndt/v7/download':
                        'wss://ndt-mlab1-lga0t.mlab1.test/ndt/v7/download',
                    'wss:///ndt/v7/upload':
                        'wss://ndt-mlab1-lga0t.mlab1.test/ndt/v7/upload',
                  },
                  'location': {
                    'city': 'New York',
                    'country': 'US',
                  },
                },
                {
                  'machine': 'ndt-mlab2-lax0t.mlab2.test',
                  'site': 'lax0t',
                  'urls': {
                    'wss:///ndt/v7/download':
                        'wss://ndt-mlab2-lax0t.mlab2.test/ndt/v7/download',
                    'wss:///ndt/v7/upload':
                        'wss://ndt-mlab2-lax0t.mlab2.test/ndt/v7/upload',
                  },
                  'location': {
                    'city': 'Los Angeles',
                    'country': 'US',
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );
        final servers = await service.discoverServers();

        expect(servers, hasLength(2));
        expect(servers[0].machine, 'ndt-mlab1-lga0t.mlab1.test');
        expect(servers[0].site, 'lga0t');
        expect(servers[0].location?.city, 'New York');
        expect(servers[0].location?.country, 'US');
        expect(servers[0].urls.downloadUrl, isNotNull);
        expect(servers[0].urls.uploadUrl, isNotNull);

        expect(servers[1].machine, 'ndt-mlab2-lax0t.mlab2.test');
        expect(servers[1].location?.city, 'Los Angeles');

        service.dispose();
      });

      test('filters out servers without download/upload URLs', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'machine': 'ndt-mlab1.test',
                  'site': 'site1',
                  'urls': {
                    'wss:///ndt/v7/download':
                        'wss://ndt-mlab1.test/ndt/v7/download',
                    'wss:///ndt/v7/upload':
                        'wss://ndt-mlab1.test/ndt/v7/upload',
                  },
                },
                {
                  'machine': 'ndt-mlab2.test',
                  'site': 'site2',
                  'urls': {},
                },
              ],
            }),
            200,
          );
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );
        final servers = await service.discoverServers();

        expect(servers, hasLength(1));
        expect(servers[0].machine, 'ndt-mlab1.test');

        service.dispose();
      });

      test('throws Ndt7Exception on API error', () {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );

        expect(
          () => service.discoverServers(),
          throwsA(isA<Ndt7Exception>()),
        );

        service.dispose();
      });

      test('throws Ndt7Exception on empty results', () {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'results': []}), 200);
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );

        expect(
          () => service.discoverServers(),
          throwsA(isA<Ndt7Exception>().having(
            (e) => e.message,
            'message',
            contains('No M-Lab servers available'),
          )),
        );

        service.dispose();
      });

      test('throws Ndt7Exception on network error', () {
        final mockClient = MockClient((request) {
          throw const SocketException('Connection failed');
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );

        expect(
          () => service.discoverServers(),
          throwsA(isA<Ndt7Exception>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          )),
        );

        service.dispose();
      });

      test('throws Ndt7Exception on invalid JSON', () {
        final mockClient = MockClient((request) async {
          return http.Response('invalid json', 200);
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: _dummyWebSocketFactory,
        );

        expect(
          () => service.discoverServers(),
          throwsA(isA<Ndt7Exception>().having(
            (e) => e.message,
            'message',
            contains('Invalid Locate API response'),
          )),
        );

        service.dispose();
      });
    });

    group('runTest', () {
      test('service can be created with mock dependencies', () {
        final mockWebSocket = MockWebSocket();
        Future<WebSocket> mockWebSocketFactory(
          String url, {
          List<String>? protocols,
        }) async {
          if (url.contains('download')) {
            Timer(const Duration(milliseconds: 100), () {
              mockWebSocket.addMessage(jsonEncode({
                'AppInfo': {
                  'ElapsedTime': 10000000,
                  'NumBytes': 1250000,
                },
                'OriginType': 1,
                'Test': 0,
              }));
            });
          }
          return mockWebSocket;
        }

        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'results': []}), 200);
        });

        final service = Ndt7Service.withDependencies(
          httpClient: mockClient,
          webSocketFactory: mockWebSocketFactory,
        );

        const server = Ndt7Server(
          machine: 'test.mlab',
          site: 'test',
          urls: Ndt7ServerUrls(
            downloadUrl: 'wss://test.mlab/ndt/v7/download',
            uploadUrl: 'wss://test.mlab/ndt/v7/upload',
          ),
        );

        expect(service, isNotNull);
        expect(server.machine, 'test.mlab');

        service.dispose();
      });
    });

    group('Ndt7Server', () {
      test('fromJson parses server correctly', () {
        final json = {
          'machine': 'ndt-mlab1.test',
          'site': 'site1',
          'urls': {
            'wss:///ndt/v7/download': 'wss://test/download',
            'wss:///ndt/v7/upload': 'wss://test/upload',
          },
          'location': {
            'city': 'NYC',
            'country': 'US',
          },
        };

        final server = Ndt7Server.fromJson(json);

        expect(server.machine, 'ndt-mlab1.test');
        expect(server.site, 'site1');
        expect(server.urls.downloadUrl, 'wss://test/download');
        expect(server.urls.uploadUrl, 'wss://test/upload');
        expect(server.location?.city, 'NYC');
        expect(server.location?.country, 'US');
        expect(server.displayName, 'NYC');
      });

      test('displayName falls back to site when city is null', () {
        const server = Ndt7Server(
          machine: 'test',
          site: 'site1',
          urls: Ndt7ServerUrls(),
        );

        expect(server.displayName, 'site1');
      });
    });

    group('Ndt7TestResult', () {
      test('toJson and fromJson roundtrip', () {
        const result = Ndt7TestResult(
          downloadMbps: 100.5,
          uploadMbps: 50.2,
          latencyMs: 15.3,
          server: Ndt7Server(
            machine: 'test.mlab',
            site: 'site1',
            urls: Ndt7ServerUrls(),
            location: Ndt7ServerLocation(city: 'NYC', country: 'US'),
          ),
          minRTT: 14.8,
          retransmissions: 5,
        );

        final json = result.toJson();
        final restored = Ndt7TestResult.fromJson(json);

        expect(restored.downloadMbps, result.downloadMbps);
        expect(restored.uploadMbps, result.uploadMbps);
        expect(restored.latencyMs, result.latencyMs);
        expect(restored.server.machine, result.server.machine);
        expect(restored.minRTT, result.minRTT);
        expect(restored.retransmissions, result.retransmissions);
      });
    });
  });
}
