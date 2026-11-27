import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';

class MockNetworkScoreService extends Mock implements NetworkScoreService {}

class MockNetworkScoreRepository extends Mock
    implements NetworkScoreRepository {}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<NetworkScoreBloc>(
      NetworkScoreBloc(
        scoreService: MockNetworkScoreService(),
        scoreRepository: MockNetworkScoreRepository(),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  NetworkScore scoreWithFactors(List<String> factors) => NetworkScore(
        overallScore: 72,
        computedAt: DateTime(2026, 1, 1, 9, 30),
        security: const DimensionScore(
          name: 'Security',
          value: 95,
          description: 'Good',
        ),
        health: const DimensionScore(
          name: 'Health',
          value: 70,
          description: 'Good',
        ),
        reliability: const DimensionScore(
          name: 'Reliability',
          value: 75,
          description: 'Good',
        ),
        speed: const DimensionScore(
          name: 'Speed',
          value: 85,
          description: 'Good',
        ),
        vulnerabilities: DimensionScore(
          name: 'Vulnerabilities',
          value: 55,
          description: 'Some vulnerabilities detected',
          factors: factors,
        ),
      );

  testWidgets('breaks down the findings that cost vulnerabilities points',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NetworkScoreDetailPage(
          initialScore: scoreWithFactors(const [
            '✗ Telnet exposed on 192.168.1.10 (-25 points)',
            '~ 1 of 2 exposed service(s) are risky (50%) (-10 points)',
            '✓ Every device is identified and trusted',
          ]),
        ),
      ),
    );

    await tester.tap(find.text('Vulnerabilities'));
    await tester.pumpAndSettle();

    expect(find.text('✗ Telnet exposed on 192.168.1.10'), findsOneWidget);
    expect(find.text('-25'), findsOneWidget);
    expect(
      find.text('~ 1 of 2 exposed service(s) are risky (50%)'),
      findsOneWidget,
    );
    expect(find.text('-10'), findsOneWidget);
  });
}
