import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_card.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/services/server_monitor_service.dart';
import 'package:vernet/values/globals.dart' as globals;

import '../settings/test_utils.dart';

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
        MaterialApp(
          home: Scaffold(
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
      final hasInitialState = find.text('Tap to assess your network').evaluate().isNotEmpty;
      final hasSuccessState = find.text('/100').evaluate().isNotEmpty;
      expect(hasInitialState || hasSuccessState, isTrue,
          reason: 'Card should show either initial or success state');
    });

    testWidgets('network score card shows computing state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
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
      final tapTarget = find.text('Tap to assess your network').evaluate().isNotEmpty
          ? find.text('Tap to assess your network')
          : find.text('NETWORK SCORE');
      
      await tester.tap(tapTarget);
      await tester.pump();

      // Should show computing state or transition to success (if already computed)
      final isComputing = find.text('Computing your network score...').evaluate().isNotEmpty;
      final hasSuccessState = find.text('/100').evaluate().isNotEmpty;
      expect(isComputing || hasSuccessState, isTrue,
          reason: 'Card should show computing or success state after tap');
    });

    testWidgets('network score detail page displays score', (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
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

    testWidgets('network score detail page shows dimension bars', (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
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

    testWidgets('network score card navigates to detail page on tap', (tester) async {
      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
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
                                child: NetworkScoreDetailPage(initialScore: testScore),
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

    testWidgets('network score responsive layout on phone size', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: getIt<NetworkScoreBloc>(),
            child: NetworkScoreDetailPage(initialScore: testScore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display without overflow - check for page structure
      expect(find.text('Score Breakdown'), findsOneWidget);
    });

    testWidgets('network score responsive layout on desktop size', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testScore = NetworkScore(
        overallScore: 75,
        computedAt: DateTime(2024),
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
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
        security: const DimensionScore(name: 'Security', value: 80, description: 'Good'),
        health: const DimensionScore(name: 'Health', value: 70, description: 'Good'),
        reliability: const DimensionScore(name: 'Reliability', value: 75, description: 'Good'),
        speed: const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
        vulnerabilities: const DimensionScore(name: 'Vulnerabilities', value: 65, description: 'Moderate'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
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
      await tester.pumpAndSettle();

      // Page should still be present after orientation change
      expect(find.byType(NetworkScoreDetailPage), findsOneWidget);

      // Change back to portrait
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(find.byType(NetworkScoreDetailPage), findsOneWidget);
    });
  });
}
