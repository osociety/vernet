import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';

class MockNetworkScoreService extends Mock implements NetworkScoreService {}

class MockNetworkScoreRepository extends Mock implements NetworkScoreRepository {}

NetworkScore _createTestScore() => NetworkScore(
      overallScore: 75,
      computedAt: DateTime(2024),
      security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
      health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
      reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
      speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
      vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
    );

WifiInfo _createTestWifiInfo() => WifiInfo(
      '192.168.1.10',
      '00:11:22:33:44:55',
      'TestWiFi',
      false,
      '192.168.1.1',
      true,
      WifiNetworkMetrics.disconnected(),
    );

NetworkConnectionStatus _createTestConnectivity() => const NetworkConnectionStatus(
      type: NetworkConnectionType.deviceToRouter,
      state: NetworkConnectionState.connected,
      title: 'Connected',
      summary: 'Connected to router',
      description: 'Device is connected to router',
    );

void main() {
  group('NetworkScoreBloc', () {
    late NetworkScoreBloc bloc;
    late MockNetworkScoreService mockService;
    late MockNetworkScoreRepository mockRepository;

    setUp(() {
      mockService = MockNetworkScoreService();
      mockRepository = MockNetworkScoreRepository();
      bloc = NetworkScoreBloc(
        scoreService: mockService,
        scoreRepository: mockRepository,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is _Initial', () {
      expect(bloc.state, const NetworkScoreState.initial());
    });

    group('loadCached', () {
      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits success when cached score exists',
        build: () {
          when(() => mockRepository.loadLastScore()).thenAnswer(
            (_) async => _createTestScore(),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const NetworkScoreEvent.loadCached()),
        expect: () => [
          isA<NetworkScoreState>()
              .having((s) => s.maybeWhen(success: (_) => true, orElse: () => false), 'is success', isTrue),
        ],
      );

      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits nothing when no cached score',
        build: () {
          when(() => mockRepository.loadLastScore()).thenAnswer(
            (_) async => null,
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const NetworkScoreEvent.loadCached()),
        expect: () => [],
      );
    });

    group('compute', () {
      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits computing then success on compute',
        build: () {
          when(() => mockService.computeScore(
                liveWifiInfo: any(named: 'liveWifiInfo'),
                liveConnectivityStatus: any(named: 'liveConnectivityStatus'),
              )).thenAnswer((_) async => _createTestScore());
          return bloc;
        },
        act: (bloc) => bloc.add(NetworkScoreEvent.compute(
          wifiInfo: _createTestWifiInfo(),
          connectivityStatus: _createTestConnectivity(),
        )),
        expect: () => [
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(computing: () => true, orElse: () => false),
            'is computing',
            isTrue,
          ),
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(success: (_) => true, orElse: () => false),
            'is success',
            isTrue,
          ),
        ],
      );

      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits failure when compute throws',
        build: () {
          when(() => mockService.computeScore(
                liveWifiInfo: any(named: 'liveWifiInfo'),
                liveConnectivityStatus: any(named: 'liveConnectivityStatus'),
              )).thenThrow(Exception('Test error'));
          return bloc;
        },
        act: (bloc) => bloc.add(NetworkScoreEvent.compute(
          wifiInfo: _createTestWifiInfo(),
          connectivityStatus: _createTestConnectivity(),
        )),
        expect: () => [
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(computing: () => true, orElse: () => false),
            'is computing',
            isTrue,
          ),
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(failure: (_) => true, orElse: () => false),
            'is failure',
            isTrue,
          ),
        ],
      );
    });

    group('refresh', () {
      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits computing then success on refresh',
        build: () {
          when(() => mockService.computeScore(
                liveWifiInfo: any(named: 'liveWifiInfo'),
                liveConnectivityStatus: any(named: 'liveConnectivityStatus'),
              )).thenAnswer((_) async => _createTestScore());
          return bloc;
        },
        act: (bloc) => bloc.add(const NetworkScoreEvent.refresh()),
        expect: () => [
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(computing: () => true, orElse: () => false),
            'is computing',
            isTrue,
          ),
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(success: (_) => true, orElse: () => false),
            'is success',
            isTrue,
          ),
        ],
      );

      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits failure when refresh throws',
        build: () {
          when(() => mockService.computeScore(
                liveWifiInfo: any(named: 'liveWifiInfo'),
                liveConnectivityStatus: any(named: 'liveConnectivityStatus'),
              )).thenThrow(Exception('Refresh error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const NetworkScoreEvent.refresh()),
        expect: () => [
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(computing: () => true, orElse: () => false),
            'is computing',
            isTrue,
          ),
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(failure: (_) => true, orElse: () => false),
            'is failure',
            isTrue,
          ),
        ],
      );
    });

    group('updateCache', () {
      blocTest<NetworkScoreBloc, NetworkScoreState>(
        'emits computing then success on updateCache',
        build: () {
          when(() => mockService.computeScore(
                liveWifiInfo: any(named: 'liveWifiInfo'),
                liveConnectivityStatus: any(named: 'liveConnectivityStatus'),
              )).thenAnswer((_) async => _createTestScore());
          return bloc;
        },
        act: (bloc) => bloc.add(NetworkScoreEvent.updateCache(
          wifiInfo: _createTestWifiInfo(),
          connectivityStatus: _createTestConnectivity(),
        )),
        expect: () => [
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(computing: () => true, orElse: () => false),
            'is computing',
            isTrue,
          ),
          isA<NetworkScoreState>().having(
            (s) => s.maybeWhen(success: (_) => true, orElse: () => false),
            'is success',
            isTrue,
          ),
        ],
      );
    });
  });
}
