import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/speed_test/bloc/speed_test_bloc.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/speedtest/ndt7_service.dart';

class MockNdt7Service implements Ndt7Service {
  MockNdt7Service({
    this.discoverServersResult,
    this.discoverServersError,
    this.runDownloadTestResult,
    this.runDownloadTestError,
    this.runUploadTestResult,
    this.runUploadTestError,
  });

  final Future<List<Ndt7Server>> Function()? discoverServersResult;
  final Object? discoverServersError;
  final Future<Ndt7Measurement> Function(Ndt7Server server)?
      runDownloadTestResult;
  final Object? runDownloadTestError;
  final Future<Ndt7Measurement> Function(Ndt7Server server)?
      runUploadTestResult;
  final Object? runUploadTestError;

  @override
  Future<List<Ndt7Server>> discoverServers() async {
    if (discoverServersError != null) throw discoverServersError!;
    if (discoverServersResult != null) return await discoverServersResult!();
    return [];
  }

  @override
  Future<Ndt7Measurement> runDownloadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    if (runDownloadTestError != null) throw runDownloadTestError!;
    if (runDownloadTestResult != null) {
      return await runDownloadTestResult!(server);
    }
    return const Ndt7Measurement(throughputMbps: 100.0);
  }

  @override
  Future<Ndt7Measurement> runUploadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    if (runUploadTestError != null) throw runUploadTestError!;
    if (runUploadTestResult != null) return await runUploadTestResult!(server);
    return const Ndt7Measurement(throughputMbps: 50.0);
  }

  @override
  void reset() {
    // No-op in tests
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNetworkScoreRepository extends Mock
    implements NetworkScoreRepository {}

class MockNetworkScoreBloc extends Mock implements NetworkScoreBloc {}

class FakeSpeedSnapshot extends Fake implements SpeedSnapshot {}

void main() {
  group('SpeedTestBloc', () {
    late SpeedTestBloc bloc;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      bloc = SpeedTestBloc(ndt7Service: MockNdt7Service());
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is correct', () {
      expect(bloc.state.isLoading, isTrue);
      expect(bloc.state.speedTestStarted, isFalse);
      expect(bloc.state.downloadSpeedTestDone, isFalse);
      expect(bloc.state.uploadSpeedTestDone, isFalse);
      expect(bloc.state.currentDownloadSpeed, 0.0);
      expect(bloc.state.currentUploadSpeed, 0.0);
      expect(bloc.state.downloadSpeeds, isEmpty);
      expect(bloc.state.uploadSpeeds, isEmpty);
      expect(bloc.state.bestServers, isNull);
      expect(bloc.state.fetchError, isNull);
    });

    blocTest<SpeedTestBloc, SpeedTestState>(
      'emits [data] when toggleServerInfo is added',
      build: () => bloc,
      act: (bloc) => bloc.add(const SpeedTestEvent.toggleServerInfo()),
      expect: () => [
        isA<SpeedTestState>().having(
            (s) => s.isServerInfoExpanded, 'isServerInfoExpanded', isTrue),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'emits [data] when reset is added',
      build: () => bloc,
      seed: () => const SpeedTestState.data(
        isLoading: false,
        speedTestStarted: true,
        currentDownloadSpeed: 50.0,
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.reset()),
      expect: () => [
        isA<SpeedTestState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.speedTestStarted, 'speedTestStarted', isFalse)
            .having((s) => s.currentDownloadSpeed, 'currentDownloadSpeed', 0.0),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'emits [data] with servers when init with preloadedServers',
      build: () => bloc,
      act: (bloc) => bloc.add(
        const SpeedTestEvent.init(
          preloadedServers: [
            Ndt7Server(
              machine: 'mlab1.test',
              site: 'site1',
              urls: Ndt7ServerUrls(
                downloadUrl: 'wss://mlab1.test/ndt/v7/download',
                uploadUrl: 'wss://mlab1.test/ndt/v7/upload',
              ),
              location: Ndt7ServerLocation(
                city: 'NYC',
                country: 'US',
              ),
            ),
          ],
        ),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<SpeedTestState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.bestServers, 'bestServers', isNotNull)
            .having(
              (s) => s.bestServers!.length,
              'bestServers length',
              1,
            ),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'startTest emits error when no servers available',
      build: () => bloc,
      seed: () => const SpeedTestState.data(
        isLoading: false,
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.startTest()),
      expect: () => [
        isA<SpeedTestState>().having(
          (s) => s.fetchError,
          'fetchError',
          contains('No test servers available'),
        ),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'startTest emits error when servers list is empty',
      build: () => bloc,
      seed: () => const SpeedTestState.data(
        isLoading: false,
        bestServers: [],
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.startTest()),
      expect: () => [
        isA<SpeedTestState>().having(
          (s) => s.fetchError,
          'fetchError',
          contains('No test servers available'),
        ),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'toggleServerInfo toggles from expanded to collapsed',
      build: () => bloc,
      seed: () => const SpeedTestState.data(
        isLoading: false,
        isServerInfoExpanded: true,
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.toggleServerInfo()),
      expect: () => [
        isA<SpeedTestState>().having(
          (s) => s.isServerInfoExpanded,
          'isServerInfoExpanded',
          isFalse,
        ),
      ],
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'reset clears all test data and errors',
      build: () => bloc,
      seed: () => const SpeedTestState.data(
        isLoading: false,
        speedTestStarted: true,
        downloadSpeedTestDone: true,
        uploadSpeedTestDone: true,
        currentDownloadSpeed: 100.0,
        currentUploadSpeed: 50.0,
        downloadSpeeds: [10.0, 20.0, 30.0],
        uploadSpeeds: [5.0, 15.0, 25.0],
        fetchError: 'Some error',
        isServerInfoExpanded: true,
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.reset()),
      expect: () => [
        isA<SpeedTestState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.speedTestStarted, 'speedTestStarted', isFalse)
            .having((s) => s.downloadSpeedTestDone, 'downloadSpeedTestDone',
                isFalse)
            .having(
                (s) => s.uploadSpeedTestDone, 'uploadSpeedTestDone', isFalse)
            .having((s) => s.currentDownloadSpeed, 'currentDownloadSpeed', 0.0)
            .having((s) => s.currentUploadSpeed, 'currentUploadSpeed', 0.0)
            .having((s) => s.downloadSpeeds, 'downloadSpeeds', isEmpty)
            .having((s) => s.uploadSpeeds, 'uploadSpeeds', isEmpty)
            .having((s) => s.fetchError, 'fetchError', isNull)
            .having(
                (s) => s.isServerInfoExpanded, 'isServerInfoExpanded', isFalse),
      ],
    );
  });

  group('SpeedTestBloc server retry', () {
    const server1 = Ndt7Server(
      machine: 'mlab1.test',
      site: 'site1',
      urls: Ndt7ServerUrls(
        downloadUrl: 'wss://mlab1.test/ndt/v7/download',
        uploadUrl: 'wss://mlab1.test/ndt/v7/upload',
      ),
    );
    const server2 = Ndt7Server(
      machine: 'mlab2.test',
      site: 'site2',
      urls: Ndt7ServerUrls(
        downloadUrl: 'wss://mlab2.test/ndt/v7/download',
        uploadUrl: 'wss://mlab2.test/ndt/v7/upload',
      ),
    );

    late MockNetworkScoreRepository mockRepo;
    late MockNetworkScoreBloc mockScoreBloc;

    setUp(() {
      mockRepo = MockNetworkScoreRepository();
      mockScoreBloc = MockNetworkScoreBloc();
      registerFallbackValue(const NetworkScoreEvent.loadCached());
      registerFallbackValue(FakeSpeedSnapshot());
      when(() => mockScoreBloc.add(any())).thenReturn(null);
      when(() => mockRepo.saveSpeedSnapshot(any())).thenAnswer((_) async {});
      GetIt.instance
        ..registerSingleton<NetworkScoreRepository>(mockRepo)
        ..registerSingleton<NetworkScoreBloc>(mockScoreBloc);
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    blocTest<SpeedTestBloc, SpeedTestState>(
      'falls back to next server when first server download fails',
      build: () {
        var downloadCallCount = 0;
        return SpeedTestBloc(
          ndt7Service: MockNdt7Service(
            runDownloadTestResult: (server) async {
              downloadCallCount++;
              if (downloadCallCount == 1) {
                throw const Ndt7Exception('WebSocket connection failed');
              }
              return const Ndt7Measurement(throughputMbps: 100.0);
            },
          ),
        );
      },
      seed: () => const SpeedTestState.data(
        isLoading: false,
        bestServers: [server1, server2],
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.startTest()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        // Should have tried 2 servers (first failed, second succeeded)
        expect(bloc.state.showSummary, isTrue);
        expect(bloc.state.fetchError, isNull);
        expect(bloc.state.currentDownloadSpeed, 100.0);
      },
    );

    blocTest<SpeedTestBloc, SpeedTestState>(
      'emits error when all servers fail',
      build: () {
        return SpeedTestBloc(
          ndt7Service: MockNdt7Service(
            runDownloadTestError: const Ndt7Exception('All servers down'),
          ),
        );
      },
      seed: () => const SpeedTestState.data(
        isLoading: false,
        bestServers: [server1, server2],
      ),
      act: (bloc) => bloc.add(const SpeedTestEvent.startTest()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.speedTestStarted, isFalse);
        expect(bloc.state.fetchError, contains('high demand'));
        expect(bloc.state.fetchError, contains('try again later'));
      },
    );
  });
}
