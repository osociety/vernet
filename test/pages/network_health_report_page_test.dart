import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/health_report/network_health_report_page.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/health_report_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_analysis/device_risk_service.dart';
import 'package:vernet/services/network_analysis/network_health_report_service.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScanRepository scans;
  late DeviceRepository devices;
  late NetworkHealthReportService service;

  final scan = ScanData(
    id: 1,
    gatewayIp: '192.168.0',
    startTime: DateTime(2024, 1, 1, 10),
    endTime: DateTime(2024, 1, 1, 10, 0, 30),
    onGoing: false,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final database = _InMemoryDatabaseService(db);
    scans = ScanRepository(database);
    devices = DeviceRepository(database);
    service = NetworkHealthReportService(
      devices,
      scans,
      HealthReportRepository(database),
      DeviceRiskService(devices, scans),
    );
    await scans.put(scan);
    await devices.put(
      const DeviceData(
        id: 1,
        scanId: 1,
        internetAddress: '192.168.0.20',
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0.1',
        macAddress: '00:03:93:AA:BB:01',
        vendorName: 'Acme',
        deviceType: 'Printer',
        hostMake: 'Printer',
        openPorts: '631',
      ),
    );
    await devices.put(
      const DeviceData(
        id: 2,
        scanId: 1,
        internetAddress: '192.168.0.50',
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0.1',
        macAddress: '00:03:93:AA:BB:02',
        vendorName: 'Acme',
        deviceType: 'Server',
        hostMake: 'Legacy box',
        openPorts: '23',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NetworkHealthReportPage(scan: scan, service: service),
      );

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('renders the grade, findings and device summary', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Network health report'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('65 / 100'), findsOneWidget);
    expect(find.text('Poor'), findsOneWidget);
    expect(find.text('No earlier report to compare'), findsOneWidget);
    expect(find.text('Critical issues'), findsOneWidget);
    expect(find.text('Warnings'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Legacy box · 192.168.0.50'), findsOneWidget);
    expect(find.text('Device summary'), findsOneWidget);
    expect(find.text('High-risk devices'), findsOneWidget);
    expect(find.text('Legacy box'), findsOneWidget);
    expect(find.text('Low 1'), findsOneWidget);
    expect(find.text('High 1'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('copies the report as text', (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy report'));
    await tester.pump();

    expect(find.text('Report copied to the clipboard'), findsOneWidget);
    expect(clipboardText, contains('Grade D (65/100)'));
    expect(clipboardText, contains('Legacy box (192.168.0.50)'));
    expect(clipboardText, contains('Devices: 2 (1 low, 0 medium, 1 high)'));

    await disposeTree(tester);
  });
}
