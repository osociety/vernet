import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/impls/device_scanner_service.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

class _FakeScannerService implements DeviceScannerService {
  _FakeScannerService({this.devices = const []});

  final List<DeviceData> devices;
  int startCalls = 0;

  @override
  Stream<DeviceData> startNewScan(
    String subnet,
    String ip,
    String gatewayIp, {
    void Function(double progress)? onProgress,
  }) {
    startCalls++;
    if (devices.isEmpty) {
      // The gate tests only care that the scan was started; failing here keeps
      // the bloc handler short-lived so it can be closed cleanly.
      throw StateError('scan started');
    }
    onProgress?.call(100);
    return Stream<DeviceData>.fromIterable(devices);
  }

  @override
  Future<Stream<List<DeviceData>>> getOnGoingScan() async =>
      const Stream<List<DeviceData>>.empty();

  @override
  Future<int> getCurrentDevicesCount() async => devices.length;
}

class _MockNotificationPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

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
    globals.testingActive = true;
    NotificationService.debugIgnorePlatformCheck = false;
    NotificationService.flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
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

  testWidgets('finishes the scan when the completion alert is refused',
      (tester) async {
    // The beta report: scanning stopped on "Found … so far" with the bar frozen
    // at "Scanning 100%". The notification ran before the success emit and
    // outside the try, so a platform that refused the show strand the page.
    final scanner = _FakeScannerService(devices: const [
      DeviceData(
        id: 1,
        internetAddress: '192.168.1.42',
        hostMake: 'Test host',
        currentDeviceIp: '192.168.1.10',
        gatewayIp: '192.168.1.1',
        scanId: 1,
      ),
    ]);
    await getIt.unregister<DeviceScannerService>();
    getIt.registerSingleton<DeviceScannerService>(scanner);

    final plugin = _MockNotificationPlugin();
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenThrow(Exception('notification channel unavailable'));
    globals.testingActive = false;
    NotificationService.debugIgnorePlatformCheck = true;
    NotificationService.flutterLocalNotificationsPlugin = plugin;

    await tester.pumpWidget(
      // AdaptiveListTile reads the theme provider, which the app installs above
      // MaterialApp; without it the results header builds as an error widget.
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
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
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Resolution awaits real interface IO, so alternate real delays with the
    // fake-time pumps that drive the bloc and the route.
    for (var i = 0;
        i < 40 && (scanner.startCalls == 0 || bloc.state is! LoadSuccess);
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(scanner.startCalls, greaterThan(0));
    expect(bloc.state, isA<LoadSuccess>());

    // The alert is attempted after the screen has already settled on results.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    verify(() => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        )).called(1);

    // The header and the snackbar both carry the count; the progress row and
    // its "Scanning 100%" label must be gone, with rescan offered.
    expect(find.text('Scan complete - 1 device found'), findsWidgets);
    expect(find.textContaining('Scanning '), findsNothing);
    expect(find.byKey(WidgetKey.rescanIconButton.key), findsOneWidget);
  });
}
