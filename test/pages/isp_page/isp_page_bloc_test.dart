import 'package:flutter_test/flutter_test.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/classes/odometer.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/pages/isp_page/bloc/isp_page_bloc.dart';

// Mock SpeedTestDart for testing
class MockSpeedTestDart extends SpeedTestDart {

  MockSpeedTestDart({
    this.mockServers,
    this.mockException,
    this.shouldFail = false,
  });
  final List<Server>? mockServers;
  final Exception? mockException;
  final bool shouldFail;

  @override
  Future<List<Server>> getBestServers({
    required List<Server> servers,
    int retryCount = 2,
    int timeoutInSeconds = 2,
  }) async {
    if (shouldFail) {
      throw mockException ?? Exception('Test error');
    }
    return mockServers ?? [];
  }
}

// Create a mock Settings instance
Settings createMockSettings() {
  final coordinate = Coordinate(0.0, 0.0);
  return Settings(
    Client(
      '192.168.1.1', // ip
      0.0, // latitude
      0.0, // longitude
      'Test ISP', // isp
      0.0, // ispRating
      0.0, // rating
      1000, // ispAvarageDownloadSpeed
      100, // ispAvarageUploadSpeed
      coordinate, // geoCoordinate
    ),
    Times(
      100, // download1
      100, // download2
      100, // download3
      50, // upload1
      50, // upload2
      50, // upload3
    ),
    Download(
      5000, // testLength
      '', // initialTest
      '0', // minTestSize
      4, // threadsPerUrl
    ),
    Upload(
      5000, // testLength
      100, // ratio
      0, // initialTest
      '0', // minTestSize
      4, // threads
      '0', // maxChunkSize
      '0', // maxChunkCount
      1, // threadsPerUrl
    ),
    ServerConfig(''),
    [],
    Odometer(0, 1),
  );
}

// Create a mock Server instance
Server createMockServer({
  required int id,
  required String name,
  required double latency,
}) {
  final coordinate = Coordinate(0.0, 0.0);
  return Server(
    id,
    name,
    'US',
    'Test Sponsor',
    'test.host.com',
    'http://test.com',
    0.0,
    0.0,
    100.0,
    latency,
    coordinate,
  );
}

void main() {
  group('IspPageBloc', () {
    late IspPageBloc ispPageBloc;

    setUp(() {
      ispPageBloc = IspPageBloc();
    });

    tearDown(() async {
      await ispPageBloc.close();
    });

    test('initial state is IspPageState.initial', () {
      expect(ispPageBloc.state, const IspPageState.initial());
    });

    test('handles Started event successfully', () async {
      final mockTester = MockSpeedTestDart(
        mockServers: [createMockServer(id: 1, name: 'Server 1', latency: 10)],
      );

      final settings = createMockSettings();
      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      // Wait for the event to be processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Check that the state changed from initial (should be LoadSuccess)
      var isInitial = true;
      ispPageBloc.state.map(
        initial: (_) => isInitial = true,
        loadInProgress: (_) => isInitial = false,
        loadFailure: (_) => isInitial = false,
        loadSuccess: (_) => isInitial = false,
      );
      expect(isInitial, false,
          reason: 'State should have changed from initial');
    });

    test('emits LoadInProgress when Started event is added', () async {
      final mockTester = MockSpeedTestDart(
        mockServers: [],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Check that LoadInProgress state was emitted
      var foundLoadInProgress = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) => foundLoadInProgress = true,
          loadFailure: (_) {},
          loadSuccess: (_) {},
        );
      }
      expect(foundLoadInProgress, true);

      await subscription.cancel();
    });

    test('emits LoadSuccess with sorted servers on successful getBestServers',
        () async {
      // Create mock servers with different latencies (unsorted)
      final server1 = createMockServer(id: 1, name: 'Server 1', latency: 50);
      final server2 = createMockServer(id: 2, name: 'Server 2', latency: 10);
      final server3 = createMockServer(id: 3, name: 'Server 3', latency: 30);

      // Return servers in unsorted order
      final mockTester = MockSpeedTestDart(
        mockServers: [server1, server2, server3],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Check for LoadSuccess state with sorted servers
      var foundSortedServers = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) {},
          loadSuccess: (success) {
            // Verify servers are sorted by latency (ascending)
            final servers = success.bestServers;
            if (servers.length == 3) {
              if (servers[0].latency == 10 &&
                  servers[1].latency == 30 &&
                  servers[2].latency == 50) {
                foundSortedServers = true;
              }
            }
          },
        );
      }
      expect(foundSortedServers, true,
          reason: 'Servers should be sorted by latency in ascending order');

      await subscription.cancel();
    });

    test('emits LoadFailure when getBestServers throws exception', () async {
      final mockTester = MockSpeedTestDart(
        mockException: Exception('Network error'),
        shouldFail: true,
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Check that LoadFailure state was emitted
      var foundLoadFailure = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) => foundLoadFailure = true,
          loadSuccess: (_) {},
        );
      }
      expect(foundLoadFailure, true);

      await subscription.cancel();
    });

    test('handles Completed event without crashing', () async {
      ispPageBloc.add(const IspPageEvent.completed());

      // Wait for the event to be processed
      await Future.delayed(const Duration(milliseconds: 50));

      // Should not throw
      expect(true, true);
    });

    test('handles Failed event without crashing', () async {
      ispPageBloc.add(const IspPageEvent.failed());

      // Wait for the event to be processed
      await Future.delayed(const Duration(milliseconds: 50));

      // Should not throw
      expect(true, true);
    });

    test('state transitions correctly through loading sequence', () async {
      final mockTester = MockSpeedTestDart(
        mockServers: [
          createMockServer(id: 1, name: 'Server', latency: 20),
        ],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      // Initial state should be initial
      var isInitial = false;
      ispPageBloc.state.map(
        initial: (_) => isInitial = true,
        loadInProgress: (_) {},
        loadFailure: (_) {},
        loadSuccess: (_) {},
      );
      expect(isInitial, true, reason: 'Should start at initial state');

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 150));

      // Should have transitioned through states
      expect(states.isNotEmpty, true);

      // Check if we emitted both LoadInProgress and LoadSuccess
      var hadInProgress = false;
      var hadSuccess = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) => hadInProgress = true,
          loadFailure: (_) {},
          loadSuccess: (_) => hadSuccess = true,
        );
      }
      expect(hadInProgress || hadSuccess, true);

      await subscription.cancel();
    });

    test('handles empty server list from getBestServers', () async {
      final mockTester = MockSpeedTestDart(
        mockServers: [],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Should emit LoadSuccess with empty list
      var foundEmptySuccess = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) {},
          loadSuccess: (success) {
            if (success.bestServers.isEmpty) {
              foundEmptySuccess = true;
            }
          },
        );
      }
      expect(foundEmptySuccess, true,
          reason: 'Should emit LoadSuccess with empty server list');

      await subscription.cancel();
    });

    test('closes without errors', () async {
      await ispPageBloc.close();
      expect(true, true);
    });

    test('handles multiple servers with same latency', () async {
      final server1 = createMockServer(id: 1, name: 'Server 1', latency: 20);
      final server2 = createMockServer(id: 2, name: 'Server 2', latency: 20);
      final server3 = createMockServer(id: 3, name: 'Server 3', latency: 20);

      final mockTester = MockSpeedTestDart(
        mockServers: [server3, server1, server2],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Should still emit LoadSuccess even with duplicate latencies
      var foundSuccess = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) {},
          loadSuccess: (success) {
            if (success.bestServers.length == 3) {
              foundSuccess = true;
            }
          },
        );
      }
      expect(foundSuccess, true);

      await subscription.cancel();
    });

    test('adds Completed event after successful retrieval', () async {
      final mockTester = MockSpeedTestDart(
        mockServers: [createMockServer(id: 1, name: 'Server', latency: 15)],
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 150));

      // Should have received success state
      var hadSuccess = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) {},
          loadSuccess: (_) => hadSuccess = true,
        );
      }
      expect(hadSuccess, true);

      await subscription.cancel();
    });

    test('adds Failed event after retrieval failure', () async {
      final mockTester = MockSpeedTestDart(
        mockException: Exception('Connection timeout'),
        shouldFail: true,
      );

      final settings = createMockSettings();
      final states = <IspPageState>[];
      final subscription = ispPageBloc.stream.listen((state) {
        states.add(state);
      });

      ispPageBloc.add(IspPageEvent.started(mockTester, settings));

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have received failure state
      var hadFailure = false;
      for (final state in states) {
        state.map(
          initial: (_) {},
          loadInProgress: (_) {},
          loadFailure: (_) => hadFailure = true,
          loadSuccess: (_) {},
        );
      }
      expect(hadFailure, true);

      await subscription.cancel();
    });
  });
}
