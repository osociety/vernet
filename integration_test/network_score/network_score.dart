import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_card.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/services/network_score_service.dart';
import 'package:vernet/utils/device_util.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../settings/test_utils.dart';
import '../wifi_test/wifi_test_runner.dart' show clearDatabase;

/// The resource bundle the app renders: these suites run in English.
final _en = AppLocalizationsEn();

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

    // Reset network score BLoC state between tests
    if (getIt.isRegistered<NetworkScoreBloc>()) {
      getIt<NetworkScoreBloc>().add(const NetworkScoreEvent.loadCached());
    }

    // Mock NetworkInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/network_info'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'wifiIPAddress':
            return '192.168.1.10';
          case 'wifiBSSID':
            return '00:11:22:33:44:55';
          case 'wifiName':
            return 'MockWiFi';
          case 'wifiGatewayAddress':
            return '192.168.1.1';
          default:
            return null;
        }
      },
    );

    // Mock PermissionHandler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          final permissions = (methodCall.arguments as List<dynamic>?) ?? [];
          return <int, int>{
            for (final permission in permissions) permission as int: 1,
          };
        }
        if (methodCall.method == 'checkPermissionStatus' ||
            methodCall.method == 'checkServiceStatus') {
          return 1;
        }
        return null;
      },
    );

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
      },
    );
  });

  group('Network Score Integration Tests', () {
    testWidgets('network score card displays initial state', (tester) async {
      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    BlocProvider.value(
                      value: getIt<NetworkScoreBloc>(),
                      child: const NetworkScoreCard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the card with NETWORK SCORE label
      expect(find.text('NETWORK SCORE'), findsOneWidget);
      // Card shows either initial state or success state (if BLoC has cached score)
      final hasInitialState =
          find.text('Tap to assess your network').evaluate().isNotEmpty;
      final hasSuccessState = find.text('/100').evaluate().isNotEmpty;
      expect(hasInitialState || hasSuccessState, isTrue,
          reason: 'Card should show either initial or success state');
    });

    testWidgets('network score card shows computing state', (tester) async {
      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    BlocProvider.value(
                      value: getIt<NetworkScoreBloc>(),
                      child: const NetworkScoreCard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the tappable area - either "Tap to assess" or the card itself if showing score
      final tapTarget =
          find.text('Tap to assess your network').evaluate().isNotEmpty
              ? find.text('Tap to assess your network')
              : find.text('NETWORK SCORE');

      await tester.tap(tapTarget);
      await tester.pump();

      // Should show computing state or transition to success (if already computed)
      final isComputing =
          find.text('Computing your network score...').evaluate().isNotEmpty;
      final hasSuccessState = find.text('/100').evaluate().isNotEmpty;
      expect(isComputing || hasSuccessState, isTrue,
          reason: 'Card should show computing or success state after tap');
    });

    testWidgets('network score detail page displays score', (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display the detail page with score breakdown section
      expect(find.text('Score Breakdown'), findsOneWidget);
      // Should display the gauge (CircularProgressIndicator with score)
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('network score detail page shows dimension bars',
        (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show dimension section
      expect(find.text('Score Breakdown'), findsOneWidget);
      // Should show the detail page
      expect(find.byType(NetworkScoreDetailPage), findsOneWidget);
    });

    testWidgets('network score card navigates to detail page on tap',
        (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    BlocProvider.value(
                      value: getIt<NetworkScoreBloc>(),
                      child: const NetworkScoreCard(),
                    ),
                    Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlocProvider.value(
                                value: getIt<NetworkScoreBloc>(),
                                child: NetworkScoreDetailPage(
                                    initialScore: testScore),
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Detail'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the button to open detail page
      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      // Should navigate to detail page and show score breakdown
      expect(find.text('Score Breakdown'), findsOneWidget);
    });

    testWidgets('network score responsive layout on phone size',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display without overflow - check for page structure
      expect(find.text('Score Breakdown'), findsOneWidget);
    });

    testWidgets('network score responsive layout on desktop size',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display without overflow - check for page structure
      expect(find.text('Score Breakdown'), findsOneWidget);
    });

    testWidgets('network score handles orientation changes', (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 75, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        TestUtils.wrapWithLocalizations(
          child: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display the page structure
      expect(find.text('Score Breakdown'), findsOneWidget);

      // Change to landscape
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      // The orchestrator runs every suite in one app, so a size left here is
      // inherited by the suites after this one: their real keyboard inset then
      // exceeds this surface, the scrollable is laid out with a zero-height
      // viewport, and finders stop seeing any of its children.
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      // Page should still be present after orientation change
      expect(find.byType(NetworkScoreDetailPage), findsOneWidget);

      // Change back to portrait
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(find.byType(NetworkScoreDetailPage), findsOneWidget);
    });

    /// Shows [score] on the detail page for sure.
    ///
    /// The bloc is a singleton and the page prefers its success state over
    /// `initialScore`, so an earlier suite test that computed a score would
    /// leave the page showing that score instead of this one. Seeding the
    /// repository and re-reading it pins the bloc to [score]; the provider the
    /// trust page's list tile reads comes from the app, so it is mounted here
    /// as well.
    Future<void> pumpDetail(WidgetTester tester, NetworkScore score) async {
      await getIt<NetworkScoreRepository>().saveScore(score);
      final bloc = getIt<NetworkScoreBloc>();
      bloc.add(const NetworkScoreEvent.loadCached());
      await bloc.stream
          .firstWhere(
            (state) => state.maybeWhen(
              success: (s) =>
                  s.overallScore == score.overallScore &&
                  s.security.value == score.security.value,
              orElse: () => false,
            ),
          )
          .timeout(const Duration(seconds: 10));
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => DarkThemeProvider(),
          child: TestUtils.wrapWithLocalizations(
            child: NetworkScoreDetailPage(initialScore: score),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('security actions offer the trust registry below a full score',
        (tester) async {
      final testScore = NetworkScore(
        overallScore: 86,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 95, description: 'Good'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 80, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await pumpDetail(tester, testScore);

      final trustAction = find.text(_en.scoreActionTrustTitle);
      await TestUtils.revealWithin(
        tester,
        trustAction,
        within: find.byType(NetworkScoreDetailPage),
      );
      await tester.tap(trustAction);
      await tester.pumpAndSettle();

      await TestUtils.waitForWidget(
        tester,
        find.byKey(WidgetKey.trustedDevicesAddManuallyButton.key),
      );
      expect(find.byType(TrustedDevicesPage), findsOneWidget);
    });

    testWidgets('a full security score offers neither scan nor trust',
        (tester) async {
      final testScore = NetworkScore(
        overallScore: 88,
        computedAt: DateTime(2024),
        security: const DimensionScore(
            name: 'Security', value: 100, description: 'Excellent'),
        health: const DimensionScore(
            name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(
            name: 'Reliability', value: 80, description: 'Good'),
        speed:
            const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(
            name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await pumpDetail(tester, testScore);

      // The action that follows the security block has to be built for the
      // absence to mean anything.
      await TestUtils.revealWithin(
        tester,
        find.text(_en.scoreActionWifiTitle),
        within: find.byType(NetworkScoreDetailPage),
      );
      expect(find.text(_en.scoreActionTrustTitle), findsNothing);
      expect(find.text(_en.scoreActionScanTitle), findsNothing);
    });

    testWidgets('security dimension deducts points for untrusted devices',
        (tester) async {
      await clearDatabase();
      final scanRepository = getIt<ScanRepository>();
      final deviceRepository = getIt<DeviceRepository>();
      final trustService = getIt<DeviceTrustService>();

      final start = DateTime.now().subtract(const Duration(minutes: 10));
      final scan = await scanRepository.put(ScanData(
        id: 901,
        gatewayIp: '192.168.0',
        startTime: start,
        endTime: start.add(const Duration(seconds: 40)),
      ));
      final device = await deviceRepository.put(DeviceData(
        id: 9101,
        scanId: scan.id,
        internetAddress: '192.168.0.5',
        currentDeviceIp: '192.168.0.10',
        gatewayIp: '192.168.0',
        macAddress: '00:03:93:AA:BB:01',
        hostMake: 'Kitchen Speaker',
      ));
      await trustService.setTrusted(device, false);
      addTearDown(() async {
        await trustService.forget(DeviceUtil.deviceKey(device));
        await clearDatabase();
      });

      final score = await getIt<NetworkScoreService>().computeScore();

      expect(score.security.value, 95);
      expect(
        score.security.factors,
        contains(_en.scoreSecurityUntrustedDevices('1', '5')),
      );
      expect(score.security.factors, contains(_en.scoreSecurityUntrustedTip));
    });
  });
}
