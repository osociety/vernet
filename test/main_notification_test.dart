import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart' as di;
import 'package:vernet/main.dart';
import 'package:vernet/pages/host_scan_page/host_scan_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/values/globals.dart' as globals;

class MockScanRepository extends Mock implements ScanRepository {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockScanRepository scanRepository;
  late MockDeviceRepository deviceRepository;

  final scan = ScanData(
    id: 123,
    gatewayIp: '192.168.1',
    startTime: DateTime(2026, 11, 12, 9),
    endTime: DateTime(2026, 11, 12, 9, 0, 30),
    onGoing: false,
  );
  final otherScan = ScanData(
    id: 7,
    gatewayIp: '10.0.0',
    startTime: DateTime(2026, 11, 11, 19),
    endTime: DateTime(2026, 11, 11, 19, 0, 20),
    onGoing: false,
  );
  const tv = DeviceData(
    id: 1,
    scanId: 123,
    internetAddress: '192.168.1.44',
    currentDeviceIp: '192.168.1.10',
    gatewayIp: '192.168.1.1',
    hostMake: 'Living room TV',
  );

  setUpAll(() {
    di.configureDependencies(di.Env.test);
  });

  setUp(() {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    NotificationService.selectedNotificationPayload = null;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();

    scanRepository = MockScanRepository();
    deviceRepository = MockDeviceRepository();
    when(() => scanRepository.get(any())).thenAnswer((_) async => null);
    when(
      () => scanRepository.getRecentScans(limit: any(named: 'limit')),
    ).thenAnswer((_) async => [otherScan]);
    when(() => deviceRepository.getListForScan(any()))
        .thenAnswer((_) async => const <DeviceData>[]);

    di.getIt.pushNewScope();
    di.getIt.registerSingleton<ScanRepository>(scanRepository);
    di.getIt.registerSingleton<DeviceRepository>(deviceRepository);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'Vernet',
        'packageName': 'org.fsociety.vernet',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (call) async => switch (call.method) {
        'wifiIPAddress' => '192.168.1.10',
        'wifiBSSID' => '00:11:22:33:44:55',
        'wifiName' => 'Mock WiFi',
        'wifiGatewayAddress' => '192.168.1.1',
        _ => null,
      },
    );
  });

  tearDown(() {
    di.getIt.popScope();
    globals.testingActive = false;
    NotificationService.skipPermissionRequests = false;
    NotificationService.selectedNotificationPayload = null;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(null));
    await settle(tester);
    await settle(tester);
  }

  Future<void> tapNotification(WidgetTester tester, String payload) async {
    NotificationService.selectNotificationStream.add(payload);
    for (var attempt = 0; attempt < 3; attempt++) {
      await settle(tester);
    }
  }

  group('Scan notification tap', () {
    testWidgets('opens the report of the scan that was notified',
        (tester) async {
      when(() => scanRepository.get(123)).thenAnswer((_) async => scan);
      when(() => deviceRepository.getListForScan(123))
          .thenAnswer((_) async => [tv]);

      await pumpApp(tester);
      await tapNotification(
        tester,
        NotificationService.scanReportPayload(123),
      );

      expect(find.byType(ScanDetailPage), findsOneWidget);
      expect(find.text('Living room TV'), findsOneWidget);
      expect(find.text('192.168.1.44'), findsOneWidget);
    });

    testWidgets('does not open the scan page, which would search again',
        (tester) async {
      when(() => scanRepository.get(123)).thenAnswer((_) async => scan);

      await pumpApp(tester);
      await tapNotification(tester, NotificationService.scanReportPayload(123));

      expect(find.byType(HostScanPage), findsNothing);
      expect(find.byType(ScanHistoryPage), findsNothing);
    });

    testWidgets('older payloads without a scan id open the newest report',
        (tester) async {
      await pumpApp(tester);
      await tapNotification(tester, NotificationService.hostScanPayload);

      expect(find.byType(ScanDetailPage), findsOneWidget);
      verify(() => scanRepository.getRecentScans(limit: 1)).called(1);
    });

    testWidgets('a removed scan still opens its newest sibling',
        (tester) async {
      when(() => scanRepository.get(123)).thenAnswer((_) async => null);

      await pumpApp(tester);
      await tapNotification(tester, NotificationService.scanReportPayload(123));

      expect(find.byType(ScanDetailPage), findsOneWidget);
      verify(() => scanRepository.getRecentScans(limit: 1)).called(1);
    });

    testWidgets('no scans at all opens the history with its empty state',
        (tester) async {
      when(
        () => scanRepository.getRecentScans(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const <ScanData>[]);

      await pumpApp(tester);
      await tapNotification(tester, NotificationService.hostScanPayload);

      expect(find.byType(ScanHistoryPage), findsOneWidget);
      expect(find.byType(ScanDetailPage), findsNothing);
    });

    testWidgets('a failing database read keeps the user where they are',
        (tester) async {
      when(() => scanRepository.get(any())).thenThrow(Exception('db locked'));

      await pumpApp(tester);
      await tapNotification(tester, NotificationService.scanReportPayload(123));

      expect(find.byType(ScanDetailPage), findsNothing);
      expect(find.byType(HostScanPage), findsNothing);
    });

    testWidgets('other payloads do not navigate', (tester) async {
      await pumpApp(tester);
      await tapNotification(tester, 'server_checker');

      expect(find.byType(ScanDetailPage), findsNothing);
      expect(find.byType(ScanHistoryPage), findsNothing);
    });

    testWidgets('one tap opens one report even if both delivery paths fire',
        (tester) async {
      when(() => scanRepository.get(123)).thenAnswer((_) async => scan);

      await pumpApp(tester);
      final payload = NotificationService.scanReportPayload(123);
      NotificationService.selectNotificationStream.add(payload);
      NotificationService.selectNotificationStream.add(payload);
      for (var attempt = 0; attempt < 3; attempt++) {
        await settle(tester);
      }

      expect(find.byType(ScanDetailPage), findsOneWidget);
    });

    testWidgets('a notification that launched the app opens its report',
        (tester) async {
      when(() => scanRepository.get(123)).thenAnswer((_) async => scan);
      NotificationService.selectedNotificationPayload =
          NotificationService.scanReportPayload(123);

      await pumpApp(tester);

      expect(find.byType(ScanDetailPage), findsOneWidget);
      expect(NotificationService.selectedNotificationPayload, isNull);
    });
  });
}
