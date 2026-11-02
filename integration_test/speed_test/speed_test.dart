import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/pages/speed_test/bloc/speed_test_bloc.dart';
import 'package:vernet/pages/speed_test/speed_test_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/speedtest/ndt7_service.dart';
import 'package:vernet/values/globals.dart' as globals;

import '../settings/test_utils.dart';

const _fakeServers = <Ndt7Server>[
  Ndt7Server(
    machine: 'mlab1.fake.test',
    site: 'fake-site',
    urls: Ndt7ServerUrls(
      downloadUrl: 'wss://fake.mlab.test/ndt/v7/download',
      uploadUrl: 'wss://fake.mlab.test/ndt/v7/upload',
    ),
    location: Ndt7ServerLocation(city: 'Test City', country: 'TC'),
  ),
];

/// Deterministic Ndt7Service fake. Either serves [servers] instantly or
/// throws [error], so tests never reach the real M-Lab Locate API.
class _FakeNdt7Service implements Ndt7Service {
  _FakeNdt7Service({
    List<Ndt7Server>? servers,
    String? error,
    Completer<List<Ndt7Server>>? discoveryGate,
  })  : _servers = servers,
        _error = error,
        _discoveryGate = discoveryGate;

  final List<Ndt7Server>? _servers;
  final String? _error;
  final Completer<List<Ndt7Server>>? _discoveryGate;

  @override
  Future<List<Ndt7Server>> discoverServers() {
    final gate = _discoveryGate;
    if (gate != null) return gate.future;
    if (_servers == null) {
      throw Ndt7Exception(_error ?? 'No M-Lab servers available');
    }
    return Future.value(_servers);
  }

  @override
  Future<Ndt7Measurement> runDownloadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    for (final speed in const [12.0, 48.0, 95.0]) {
      onProgress?.call(
        Ndt7Progress(
          elapsed: speed / 50,
          speed: speed,
          bytesTransferred: (speed * 125000).round(),
          isDownload: true,
        ),
      );
    }
    return const Ndt7Measurement(
      throughputMbps: 95.0,
      minRTT: 12.0,
      retransmissions: 3,
    );
  }

  @override
  Future<Ndt7Measurement> runUploadTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    for (final speed in const [8.0, 19.0, 38.0]) {
      onProgress?.call(
        Ndt7Progress(
          elapsed: speed / 25,
          speed: speed,
          bytesTransferred: (speed * 125000).round(),
          isDownload: false,
        ),
      );
    }
    return const Ndt7Measurement(
      throughputMbps: 38.0,
      minRTT: 12.0,
      retransmissions: 3,
    );
  }

  @override
  Future<Ndt7TestResult> runTest(
    Ndt7Server server, {
    void Function(Ndt7Progress)? onProgress,
  }) async {
    final download = await runDownloadTest(server, onProgress: onProgress);
    final upload = await runUploadTest(server, onProgress: onProgress);
    return Ndt7TestResult(
      downloadMbps: download.throughputMbps ?? 0,
      uploadMbps: upload.throughputMbps ?? 0,
      latencyMs: download.minRTT ?? upload.minRTT ?? 0,
      server: server,
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {}
}

void _installSpeedTestBloc(Ndt7Service service) {
  if (getIt.isRegistered<SpeedTestBloc>()) {
    getIt.unregister<SpeedTestBloc>();
  }
  getIt.registerSingleton<SpeedTestBloc>(
    SpeedTestBloc(ndt7Service: service),
  );
}

void _restoreProductionSpeedTestBloc() {
  if (getIt.isRegistered<SpeedTestBloc>()) {
    getIt<SpeedTestBloc>().close();
    getIt.unregister<SpeedTestBloc>();
  }
  getIt.registerSingleton<SpeedTestBloc>(
    SpeedTestBloc(ndt7Service: Ndt7Service()),
  );
}

Widget _hostScaffold() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SpeedTestPage()),
            ),
            child: const Text('Open Speed Test'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
  });

  tearDown(() {
    _restoreProductionSpeedTestBloc();
  });

  group('Speed Test Integration Tests', () {
    // SpeedTestPage pulls the SpeedTestBloc singleton from getIt and
    // auto-starts a test once servers are loaded. Each test installs a
    // fresh bloc backed by a fake Ndt7Service, so runs are deterministic
    // and never reach M-Lab. Tests that install a serving fake must wait
    // for 'Test Again' before finishing so tearDown can close the bloc
    // without a suspended startTest handler emitting after close.

    testWidgets('speed test page displays loading state initially',
        (tester) async {
      // Gate discovery so the loading state cannot resolve mid-test.
      _installSpeedTestBloc(
        _FakeNdt7Service(discoveryGate: Completer<List<Ndt7Server>>()),
      );
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('speed test page shows main UI after loading', (tester) async {
      _installSpeedTestBloc(_FakeNdt7Service(servers: _fakeServers));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(tester, find.text('Test Server'));
      expect(find.text('Test City'), findsOneWidget);

      await TestUtils.waitForWidget(tester, find.text('Test Again'));
    });

    testWidgets('speed test page displays M-Lab attribution', (tester) async {
      _installSpeedTestBloc(_FakeNdt7Service(servers: _fakeServers));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(tester, find.text('Test Again'));

      await tester.tap(find.text('Powered by Measurement Lab (M-Lab)'));
      await tester.pumpAndSettle();
      expect(find.text('Measurement Lab (M-Lab)'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Measurement Lab (M-Lab)'), findsNothing);
    });

    testWidgets('speed test page responsive layout on phone size',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _installSpeedTestBloc(_FakeNdt7Service(servers: _fakeServers));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(tester, find.text('Test Again'));

      expect(find.text('Test Again'), findsOneWidget);
      expect(find.text('Powered by Measurement Lab (M-Lab)'), findsOneWidget);
    });

    testWidgets('speed test page responsive layout on desktop size',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _installSpeedTestBloc(_FakeNdt7Service(servers: _fakeServers));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(tester, find.text('Test Again'));

      expect(find.text('Test Again'), findsOneWidget);
      expect(find.text('Latency'), findsOneWidget);
      expect(find.text('Powered by Measurement Lab (M-Lab)'), findsOneWidget);
    });

    testWidgets('speed test page handles orientation changes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _installSpeedTestBloc(_FakeNdt7Service(servers: _fakeServers));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(tester, find.text('Test Again'));

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.text('Test Again'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('Test Again'), findsOneWidget);
    });

    testWidgets('speed test page error state has go back button',
        (tester) async {
      _installSpeedTestBloc(_FakeNdt7Service(error: 'Locate API unreachable'));
      await tester.pumpWidget(const MaterialApp(home: SpeedTestPage()));

      await TestUtils.waitForWidget(
          tester, find.text('Speed Test Unavailable'));
      // The message shows in both the body text and the error snackbar.
      expect(find.textContaining('Could not find test servers'), findsWidgets);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('speed test page can be closed via go back button',
        (tester) async {
      _installSpeedTestBloc(_FakeNdt7Service(error: 'Locate API unreachable'));
      await tester.pumpWidget(_hostScaffold());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Speed Test'));
      await TestUtils.waitForWidget(
          tester, find.text('Speed Test Unavailable'));

      await tester.tap(find.text('Go Back'));
      await TestUtils.waitForWidget(tester, find.text('Open Speed Test'));
    });

    testWidgets('speed test page handles rapid open/close cycles',
        (tester) async {
      _installSpeedTestBloc(_FakeNdt7Service(error: 'Locate API unreachable'));
      await tester.pumpWidget(_hostScaffold());
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Open Speed Test'));
        await TestUtils.waitForWidget(
          tester,
          find.text('Speed Test Unavailable'),
        );
        await tester.tap(find.text('Go Back'));
        await TestUtils.waitForWidget(tester, find.text('Open Speed Test'));
      }
    });
  });
}
