import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final isDesktop = Platform.isLinux || Platform.isMacOS;
  final isMobileOrWindows =
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    final db = AppDatabase(NativeDatabase.memory());
    final databaseService = _InMemoryDatabaseService(db);
    final scanRepository = ScanRepository(databaseService);
    final deviceRepository = DeviceRepository(databaseService);
    final networkScoreRepository = NetworkScoreRepository();
    final networkScoreService = NetworkScoreService(
      scanRepository: scanRepository,
      deviceRepository: deviceRepository,
      scoreRepository: networkScoreRepository,
    );
    final networkScoreBloc = NetworkScoreBloc(
      scoreService: networkScoreService,
      scoreRepository: networkScoreRepository,
    );

    GetIt.instance
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<DatabaseService<AppDatabase>>(databaseService)
      ..registerSingleton<ScanRepository>(scanRepository)
      ..registerSingleton<DeviceRepository>(deviceRepository)
      ..registerSingleton<NetworkScoreRepository>(networkScoreRepository)
      ..registerSingleton<NetworkScoreService>(networkScoreService)
      ..registerSingleton<NetworkScoreBloc>(networkScoreBloc);

    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'Vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    // Mock PermissionHandler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions') {
        return {3: 1}; // 3 is location, 1 is granted (PermissionStatus.granted)
      }
      return null;
    });
  });

  tearDown(() async {
    if (GetIt.instance.isRegistered<AppDatabase>()) {
      await GetIt.instance<AppDatabase>().close();
    }
    await GetIt.instance.reset();
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: const MaterialApp(
        home: LocationConsentPage(),
      ),
    );
  }

  testWidgets('LocationConsentPage renders app name and icon',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Vernet'), findsOneWidget);
    expect(
        find.byIcon(isMobileOrWindows ? Icons.location_on : Icons.check_circle),
        findsOneWidget);
  });

  testWidgets('primary button navigates to TabBarPage',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 600));

    final buttonLabel =
        isMobileOrWindows ? 'Allow location access' : 'Get Started';
    await tester.tap(find.text(buttonLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TabBarPage), findsOneWidget);
  });

  testWidgets('skip button is shown on mobile platforms',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 600));

    if (isDesktop) {
      expect(find.text('Continue without it'), findsNothing);
    } else {
      expect(find.text('Continue without it'), findsOneWidget);
      await tester.tap(find.text('Continue without it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TabBarPage), findsOneWidget);
    }
  });
}
