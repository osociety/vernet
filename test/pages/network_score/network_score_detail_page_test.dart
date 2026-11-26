import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_detail_page.dart';
import 'package:vernet/pages/trusted_devices_page.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/device_trust_service.dart';
import 'package:vernet/services/network_score_service.dart';

import '../../helpers/test_helpers.dart';

class MockNetworkScoreService extends Mock implements NetworkScoreService {}

class MockNetworkScoreRepository extends Mock
    implements NetworkScoreRepository {}

class MockDeviceTrustService extends Mock implements DeviceTrustService {}

NetworkScore _scoreWithSecurity(int security) => NetworkScore(
      overallScore: 75,
      computedAt: DateTime(2024),
      security: DimensionScore(
          name: 'Security', value: security, description: 'Good'),
      health: const DimensionScore(name: 'Health', value: 100, description: ''),
      reliability: const DimensionScore(
          name: 'Reliability', value: 100, description: ''),
      speed: const DimensionScore(name: 'Speed', value: 100, description: ''),
      vulnerabilities: const DimensionScore(
          name: 'Vulnerabilities', value: 100, description: ''),
    );

void main() {
  late MockNetworkScoreService scoreService;
  late MockNetworkScoreRepository scoreRepository;
  late MockDeviceTrustService trustService;

  setUp(() {
    scoreService = MockNetworkScoreService();
    scoreRepository = MockNetworkScoreRepository();
    trustService = MockDeviceTrustService();
    when(() => trustService.watchAll())
        .thenAnswer((_) => Stream.value(const <KnownDeviceData>[]));
    getIt
      ..registerSingleton<NetworkScoreBloc>(
        NetworkScoreBloc(
          scoreService: scoreService,
          scoreRepository: scoreRepository,
        ),
      )
      ..registerSingleton<DeviceTrustService>(trustService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpDetailPage(WidgetTester tester, NetworkScore score) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithLocalizations(
        child: NetworkScoreDetailPage(initialScore: score),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers device trust when security is not perfect',
      (tester) async {
    await pumpDetailPage(tester, _scoreWithSecurity(95));

    expect(find.text(l10nEn().scoreActionTrustTitle), findsOneWidget);
    expect(find.text(l10nEn().scoreActionScanTitle), findsOneWidget);
  });

  testWidgets('hides device trust when security is perfect', (tester) async {
    await pumpDetailPage(tester, _scoreWithSecurity(100));

    expect(find.text(l10nEn().scoreActionTrustTitle), findsNothing);
  });

  testWidgets('device trust tile opens the trusted devices page',
      (tester) async {
    await pumpDetailPage(tester, _scoreWithSecurity(95));

    await tester.tap(find.text(l10nEn().scoreActionTrustTitle));
    await tester.pumpAndSettle();

    expect(find.byType(TrustedDevicesPage), findsOneWidget);
  });
}
