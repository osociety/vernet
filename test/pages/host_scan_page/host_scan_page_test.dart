import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;

class _FakeScannerService implements DeviceScannerService {
  int startCalls = 0;

  @override
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp, {
    void Function(double progress)? onProgress,
  }) {
    startCalls++;
    // The gate test only cares that the scan was started; failing here keeps
    // the bloc handler short-lived so it can be closed cleanly.
    throw StateError('scan started');
  }

  @override
  Future<Stream<List<DeviceData>>> getOnGoingScan() async =>
      const Stream<List<DeviceData>>.empty();

  @override
  Future<int> getCurrentDevicesCount() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScannerService scanner;
  late HostScanBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    globals.testingActive = true;
    await getIt.reset();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => switch (call.method) {
        'wifiIPAddress' => '192.168.1.10',
        'wifiGatewayAddress' => '192.168.1.1',
        _ => null,
      },
    );

    scanner = _FakeScannerService();
    getIt.registerSingleton<DeviceScannerService>(scanner);
    bloc = HostScanBloc();
    getIt.registerSingleton<HostScanBloc>(bloc);
  });

  tearDown(() async {
    // The BlocProvider owns the bloc and closes it with the page.
    await getIt.reset();
  });

  testWidgets('starts the scan only after the route transition completes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => HostScanPage(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HostScanPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(
      bloc.state.maybeMap(initial: (_) => true, orElse: () => false),
      isTrue,
      reason: 'the scan must not start while the push animation is running',
    );

    expect(scanner.startCalls, 0);

    await tester.pump(const Duration(milliseconds: 250));
    // Initialization awaits real network-interface IO, which needs the real
    // event loop; alternate it with fake-time pumps that flush bloc events.
    for (var i = 0; i < 20 && scanner.startCalls == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(scanner.startCalls, 1);
    expect(
      bloc.state.maybeMap(initial: (_) => false, orElse: () => true),
      isTrue,
    );
  });

  testWidgets('starts the scan when the transition never completes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder<void>(
                    transitionDuration: const Duration(seconds: 30),
                    pageBuilder: (_, __, ___) => HostScanPage(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    for (var i = 0; i < 20 && scanner.startCalls == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      scanner.startCalls,
      1,
      reason: 'a window that stops drawing frames must still start the scan',
    );

    await tester.pump(const Duration(seconds: 30));
  });
}
