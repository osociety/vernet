import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/known_device_repository.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KnownDeviceRepository repository;
  late DeviceTrustService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    globals.testingActive = true;
    db = AppDatabase(NativeDatabase.memory());
    repository = KnownDeviceRepository(_InMemoryDatabaseService(db));
    service = DeviceTrustService(repository);
    await service.addTrustedMac(
      '00:11:22:33:44:55',
      label: 'Living Room TV',
    );
    await service.setTrusted(
      const DeviceData(
        id: 2,
        scanId: 2,
        internetAddress: '192.168.0.9',
        macAddress: '00:11:22:33:44:66',
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0.1',
      ),
      false,
    );
  });

  tearDown(() async {
    globals.testingActive = false;
    await db.close();
  });

  Widget createPage() {
    return ChangeNotifierProvider(
      create: (_) => DarkThemeProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrustedDevicesPage(service: service),
      ),
    );
  }

  /// Drift schedules a zero-delay timer when a watched query is cancelled, and
  /// the test binding flags it if it is still pending when the test ends.
  /// Replacing the tree here lets that timer run inside the test; advancing
  /// past the snackbar duration clears any message timer as well.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('lists known devices and filters by trust', (tester) async {
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.text('00:11:22:33:44:66'), findsWidgets);

    await tester.tap(find.byKey(WidgetKey.trustedDevicesFilterUntrusted.key));
    await tester.pumpAndSettle();

    expect(find.text('Living Room TV'), findsNothing);
    expect(find.text('00:11:22:33:44:66'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('revokes trust through the row menu', (tester) async {
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    final tile = find.ancestor(
      of: find.text('Living Room TV'),
      matching: find.byType(AdaptiveListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.adaptive.more)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove trust'));
    await tester.pumpAndSettle();

    final row = await repository.getByKey('mac:00:11:22:33:44:55');
    expect(row!.trusted, isFalse);
    expect(find.textContaining('no longer trusted'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('adds a device by its MAC address', (tester) async {
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(WidgetKey.trustedDevicesAddManuallyButton.key),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(WidgetKey.trustedDevicesMacField.key),
      '00-1A-2B-3C-4D-5E',
    );
    await tester.tap(find.byKey(WidgetKey.trustedDevicesAddButton.key));
    await tester.pumpAndSettle();

    final row = await repository.getByKey('mac:00:1a:2b:3c:4d:5e');
    expect(row, isNotNull);
    expect(row!.trusted, isTrue);
    expect(find.text('Trusted device added'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('keeps the dialog open for an invalid MAC', (tester) async {
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(WidgetKey.trustedDevicesAddManuallyButton.key),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(WidgetKey.trustedDevicesMacField.key),
      'nope',
    );
    await tester.tap(find.byKey(WidgetKey.trustedDevicesAddButton.key));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a MAC address such as 00:1A:2B:3C:4D:5E'),
      findsOneWidget,
    );
    expect(await repository.getByKey('mac:00:1a:2b:3c:4d:5e'), isNull);
    await disposeTree(tester);
  });
}
