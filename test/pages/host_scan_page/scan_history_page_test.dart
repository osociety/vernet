import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';

import '../../helpers/test_helpers.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScanRepository scanRepo;
  late DeviceRepository deviceRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final service = _InMemoryDatabaseService(db);
    scanRepo = ScanRepository(service);
    deviceRepo = DeviceRepository(service);

    await scanRepo.put(
      ScanData(
        id: 1,
        gatewayIp: '192.168.0',
        startTime: DateTime(2024, 1, 1, 10),
        endTime: DateTime(2024, 1, 1, 10, 0, 30),
        onGoing: false,
      ),
    );
    await deviceRepo.put(
      const DeviceData(
        id: 10,
        internetAddress: '192.168.0.12',
        currentDeviceIp: '192.168.0.100',
        gatewayIp: '192.168.0.1',
        macAddress: '00:11:22:33:44:55',
        hostMake: 'Device One',
        scanId: 1,
      ),
    );
    await deviceRepo.put(
      const DeviceData(
        id: 11,
        internetAddress: '192.168.0.5',
        currentDeviceIp: '192.168.0.100',
        gatewayIp: '192.168.0.1',
        hostMake: 'Device Two',
        scanId: 1,
      ),
    );

    await scanRepo.put(
      ScanData(
        id: 2,
        gatewayIp: '10.0.0',
        startTime: DateTime(2024, 1, 2, 11),
        onGoing: true,
      ),
    );
    await deviceRepo.put(
      const DeviceData(
        id: 12,
        internetAddress: '10.0.0.7',
        currentDeviceIp: '10.0.0.20',
        gatewayIp: '10.0.0.1',
        hostMake: 'Device Three',
        scanId: 2,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithDarkThemeProvider(
        child: MaterialApp(
          home: ScanHistoryPage(
            scanRepository: scanRepo,
            deviceRepository: deviceRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists previous scans newest first with counts and status',
      (tester) async {
    await pumpHistory(tester);

    expect(find.text('Previous scans'), findsOneWidget);
    expect(find.text('Network 192.168.0'), findsOneWidget);
    expect(find.text('Network 10.0.0'), findsOneWidget);
    expect(find.textContaining('2 devices'), findsOneWidget);
    expect(find.textContaining('1 device'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);

    final newerScanY = tester.getTopLeft(find.text('Network 10.0.0')).dy;
    final olderScanY = tester.getTopLeft(find.text('Network 192.168.0')).dy;
    expect(newerScanY, lessThan(olderScanY));
  });

  testWidgets('opens a previous scan report with its devices', (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.text('Network 192.168.0'));
    await tester.pumpAndSettle();

    expect(find.text('Scan report'), findsOneWidget);
    expect(find.text('2 devices found'), findsOneWidget);
    expect(find.text('Device One'), findsOneWidget);
    expect(find.text('Device Two'), findsOneWidget);
    expect(find.text('192.168.0.5'), findsOneWidget);
    expect(find.text('192.168.0.12 • 00:11:22:33:44:55'), findsOneWidget);
  });

  testWidgets('shows scan activity and a table on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistory(tester);

    expect(find.text('SCAN ACTIVITY'), findsOneWidget);
    expect(find.text('Scan history'), findsOneWidget);
    expect(find.text('NETWORK'), findsOneWidget);
    expect(find.text('STARTED'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('DEVICES'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.textContaining('2 devices'), findsNothing);
  });

  testWidgets('shows rich scan cards on a phone-width window', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistory(tester);

    expect(find.text('SCAN ACTIVITY'), findsOneWidget);
    expect(find.textContaining('2 devices'), findsOneWidget);
    expect(find.textContaining('1 device'), findsOneWidget);
    expect(find.text('NETWORK'), findsNothing);
    expect(find.text('STATUS'), findsNothing);
  });

  testWidgets('keeps the report readable on a wide desktop window',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistory(tester);
    await tester.tap(find.text('Network 192.168.0'));
    await tester.pumpAndSettle();

    final summaryLeft = tester.getTopLeft(find.text('Network 192.168.0')).dx;
    final resultsLeft = tester.getTopLeft(find.text('Discovered devices')).dx;
    expect(summaryLeft, greaterThan(150));
    expect(resultsLeft, greaterThan(summaryLeft));

    expect(find.text('DEVICE'), findsOneWidget);
    expect(find.text('IP ADDRESS'), findsOneWidget);
    expect(find.text('MAC ADDRESS'), findsOneWidget);
    expect(find.text('192.168.0.12'), findsOneWidget);
    expect(find.text('00:11:22:33:44:55'), findsOneWidget);
  });

  testWidgets('keeps the report usable on a phone-width window',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistory(tester);
    await tester.tap(find.text('Network 192.168.0'));
    await tester.pumpAndSettle();

    expect(find.text('Discovered devices'), findsOneWidget);
    expect(find.text('Device One'), findsOneWidget);
    expect(
      find.text('192.168.0.12 • 00:11:22:33:44:55'),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty state when no scans exist', (tester) async {
    final emptyDb = AppDatabase(NativeDatabase.memory());
    addTearDown(emptyDb.close);
    final emptyService = _InMemoryDatabaseService(emptyDb);

    await tester.pumpWidget(
      wrapWithDarkThemeProvider(
        child: MaterialApp(
          home: ScanHistoryPage(
            scanRepository: ScanRepository(emptyService),
            deviceRepository: DeviceRepository(emptyService),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No previous scans yet'), findsOneWidget);
  });
}
