import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/models/wifi_metrics.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/services/network_connectivity_service.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
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

  Future<void> pumpHomePage(
    WidgetTester tester, {
    required Size size,
    NetworkConnectivityService? connectivityService,
    Future<WifiInfo?> Function({bool force})? wifiInfoLoader,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    connectivityService ??= NetworkConnectivityService(
      pingProbe: (host) async => const Duration(milliseconds: 20),
      fallbackProbe: (host) async => true,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: HomePage(
            connectivityService: connectivityService,
            wifiInfoLoader: wifiInfoLoader ??
                ({bool force = false}) async => WifiInfo(
                      '192.168.1.10',
                      '00:11:22:33:44:55',
                      'Mock WiFi',
                      false,
                      '192.168.1.1',
                      true,
                      const WifiNetworkMetrics(
                        rawRssi: -50,
                        normalizedLevel: 3,
                        statusMessage: 'Good signal',
                      ),
                    ),
          ),
        ),
      ),
    );
    // The dashboard has live network futures and a refresh indicator; advance
    // frames without waiting for every ongoing indicator to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('HomePage dashboard', () {
    testWidgets('shows the network overview and connection details',
        (tester) async {
      await pumpHomePage(tester, size: const Size(900, 800));

      expect(find.text('NETWORK OVERVIEW'), findsOneWidget);
      expect(find.text('Your network'), findsOneWidget);
      expect(find.text('CONNECTION PATH'), findsOneWidget);
      expect(find.text('THIS DEVICE'), findsOneWidget);
      expect(find.text('WI-FI ROUTER'), findsOneWidget);
      expect(find.text('INTERNET PROVIDER'), findsOneWidget);
      expect(find.text('WI-FI CONNECTION'), findsOneWidget);
      expect(find.text('INTERNET SERVICE'), findsOneWidget);
    });

    testWidgets('shows connection line status and opens detail dialog on click',
        (tester) async {
      final connectivityService = NetworkConnectivityService(
        pingProbe: (host) async => const Duration(milliseconds: 20),
        fallbackProbe: (host) async => true,
      );

      await pumpHomePage(
        tester,
        size: const Size(900, 800),
        connectivityService: connectivityService,
      );

      // Verify connection segments exist on the path
      expect(
        find.byKey(WidgetKey.deviceToRouterConnector.key),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKey.routerToInternetConnector.key),
        findsOneWidget,
      );

      // Verify the status text over the lines
      expect(find.text('Connected'), findsWidgets);

      // Tap device-to-router connector to open dialog
      await tester.tap(find.byKey(WidgetKey.deviceToRouterConnector.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Device Connected to Router'), findsOneWidget);
      expect(find.text('Connected via Wi-Fi (Mock WiFi)'), findsOneWidget);
      expect(find.text('192.168.1.10'), findsWidgets);

      // Close the dialog
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Device Connected to Router'), findsNothing);

      // Tap router-to-internet connector to open dialog
      await tester.tap(find.byKey(WidgetKey.routerToInternetConnector.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Router Connected to Internet'), findsOneWidget);
      expect(find.text('Test Target'), findsOneWidget);
      expect(find.text('google.com'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('shows Disconnected and troubleshooting dialog when offline',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/network_info'),
        (call) async => null,
      );

      final connectivityService = NetworkConnectivityService(
        pingProbe: (host) async => null,
        fallbackProbe: (host) async => false,
      );

      await pumpHomePage(
        tester,
        size: const Size(900, 800),
        connectivityService: connectivityService,
        wifiInfoLoader: ({bool force = false}) async => WifiInfo(
          null,
          null,
          null,
          true,
          '',
          false,
          WifiNetworkMetrics.disconnected(),
        ),
      );

      expect(find.text('Disconnected'), findsWidgets);

      await tester.tap(find.byKey(WidgetKey.deviceToRouterConnector.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Device Disconnected from Router'), findsOneWidget);
      expect(find.text('Troubleshooting Steps'), findsOneWidget);
      expect(
        find.text(
          'Ensure Wi-Fi or Ethernet is turned on in your device settings.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not check internet when Wi-Fi is disconnected',
        (tester) async {
      bool internetProbeCalled = false;
      final connectivityService = NetworkConnectivityService(
        pingProbe: (host) async {
          internetProbeCalled = true;
          return const Duration(milliseconds: 25);
        },
        fallbackProbe: (host) async {
          internetProbeCalled = true;
          return true;
        },
      );

      // When Wi-Fi is disconnected, internet probe should not be called
      await pumpHomePage(
        tester,
        size: const Size(900, 800),
        connectivityService: connectivityService,
        wifiInfoLoader: ({bool force = false}) async => WifiInfo(
          null,
          null,
          null,
          true,
          '',
          false,
          WifiNetworkMetrics.disconnected(),
        ),
      );

      expect(internetProbeCalled, isFalse);
      expect(find.text('Disconnected'), findsWidgets);

      // Tap router to internet connector to verify dialog shows it's unreachable due to Wi-Fi
      await tester.tap(find.byKey(WidgetKey.routerToInternetConnector.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Internet Unreachable (No Local Link)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Connect to a Wi-Fi network or plug in an Ethernet cable.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('checks internet after Wi-Fi is connected', (tester) async {
      bool internetProbeCalled = false;
      final connectivityService = NetworkConnectivityService(
        pingProbe: (host) async {
          internetProbeCalled = true;
          return const Duration(milliseconds: 25);
        },
        fallbackProbe: (host) async {
          internetProbeCalled = true;
          return true;
        },
      );

      await pumpHomePage(
        tester,
        size: const Size(900, 800),
        connectivityService: connectivityService,
        wifiInfoLoader: ({bool force = false}) async => WifiInfo(
          '192.168.1.15',
          '00:11:22:33:44:55',
          'Mock WiFi',
          false,
          '192.168.1.1',
          true,
          const WifiNetworkMetrics(
            rawRssi: -50,
            normalizedLevel: 3,
            statusMessage: 'Good signal',
          ),
        ),
      );

      expect(internetProbeCalled, isTrue);
      expect(find.text('Connected'), findsWidgets);
    });

    testWidgets('keeps the tool shortcuts in the sidebar, not the dashboard',
        (tester) async {
      await pumpHomePage(tester, size: const Size(900, 800));

      expect(find.text('Check your connection'), findsNothing);
      expect(find.text('Website and address tools'), findsNothing);
      expect(find.byKey(const ValueKey('ping')), findsNothing);
      expect(find.text('Internet lookups are off'), findsOneWidget);
    });

    testWidgets('opens scan history from the Wi-Fi panel', (tester) async {
      await getIt.reset();
      final db = AppDatabase(NativeDatabase.memory());
      final databaseService = _InMemoryDatabaseService(db);
      getIt
        ..registerSingleton<ScanRepository>(ScanRepository(databaseService))
        ..registerSingleton<DeviceRepository>(
            DeviceRepository(databaseService));
      addTearDown(() async {
        await getIt.reset();
        await db.close();
      });

      await pumpHomePage(tester, size: const Size(900, 800));

      expect(
        find.byKey(WidgetKey.scanHistoryIconButton.key),
        findsOneWidget,
      );

      await tester.tap(find.byKey(WidgetKey.scanHistoryIconButton.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScanHistoryPage), findsOneWidget);
      expect(find.text(StringValue.previousScansTitle), findsOneWidget);
    });

    testWidgets('keeps the mobile header left aligned', (tester) async {
      await pumpHomePage(tester, size: const Size(390, 844));

      final overview = tester.widget<Text>(find.text('NETWORK OVERVIEW'));
      final title = tester.widget<Text>(find.text('Your network'));
      expect(overview.textAlign, isNull);
      expect(title.textAlign, isNull);
    });

    testWidgets('matches Wi-Fi and internet panel heights on desktop',
        (tester) async {
      await pumpHomePage(tester, size: const Size(1100, 800));

      final wifiPanel = find
          .ancestor(
            of: find.text('WI-FI CONNECTION'),
            matching: find.byType(Container),
          )
          .first;
      final ispPanel = find
          .ancestor(
            of: find.text('INTERNET SERVICE'),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(wifiPanel).height, tester.getSize(ispPanel).height);
    });
  });
}
