import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/network_score/network_score_card.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';
import '../../helpers/test_helpers.dart';

class MockNetworkScoreService extends Mock implements NetworkScoreService {}

class MockNetworkScoreRepository extends Mock
    implements NetworkScoreRepository {}

NetworkScore _createTestScore({required DateTime computedAt}) => NetworkScore(
      overallScore: 75,
      computedAt: computedAt,
      security: const DimensionScore(
          name: 'Security', value: 80, description: 'Good'),
      health:
          const DimensionScore(name: 'Health', value: 70, description: 'Good'),
      reliability: const DimensionScore(
          name: 'Reliability', value: 75, description: 'Good'),
      speed:
          const DimensionScore(name: 'Speed', value: 85, description: 'Good'),
      vulnerabilities: const DimensionScore(
          name: 'Vulnerabilities', value: 65, description: 'Moderate'),
    );

Widget _wrap(
  NetworkScoreBloc bloc, {
  Locale locale = const Locale('en'),
}) =>
    BlocProvider<NetworkScoreBloc>.value(
      value: bloc,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: NetworkScoreCard()),
        ),
      ),
    );

void main() {
  late MockNetworkScoreService mockService;
  late MockNetworkScoreRepository mockRepository;

  setUp(() {
    mockService = MockNetworkScoreService();
    mockRepository = MockNetworkScoreRepository();
  });

  testWidgets('shows computation time inside the card meta row',
      (tester) async {
    final computedAt = DateTime.now().subtract(const Duration(days: 2));
    when(() => mockRepository.loadLastScore())
        .thenAnswer((_) async => _createTestScore(computedAt: computedAt));
    final bloc = NetworkScoreBloc(
      scoreService: mockService,
      scoreRepository: mockRepository,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(_wrap(bloc));
    bloc.add(const NetworkScoreEvent.loadCached());
    await tester.pump();
    await tester.pump();

    final timeText = find.text(formatTimestamp(l10nEn(), computedAt));
    expect(timeText, findsOneWidget);

    // Timestamp sits next to the card title in the header row.
    expect(
      tester.getTopLeft(timeText).dx,
      greaterThan(tester.getTopLeft(find.text('NETWORK SCORE')).dx),
    );
    expect(
      tester.getTopLeft(timeText).dy,
      lessThan(
        tester.getTopLeft(find.text('Your network is in good shape')).dy,
      ),
    );
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('hides the meta row when no score is available', (tester) async {
    when(() => mockRepository.loadLastScore()).thenAnswer((_) async => null);
    final bloc = NetworkScoreBloc(
      scoreService: mockService,
      scoreRepository: mockRepository,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(_wrap(bloc));
    bloc.add(const NetworkScoreEvent.loadCached());
    await tester.pump();
    await tester.pump();

    expect(find.text('Just now'), findsNothing);
    expect(find.text('NETWORK SCORE'), findsOneWidget);
  });

  testWidgets('the card reads its labels from the German bundle',
      (tester) async {
    final computedAt = DateTime.now().subtract(const Duration(days: 2));
    when(() => mockRepository.loadLastScore())
        .thenAnswer((_) async => _createTestScore(computedAt: computedAt));
    final bloc = NetworkScoreBloc(
      scoreService: mockService,
      scoreRepository: mockRepository,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(_wrap(bloc, locale: const Locale('de')));
    bloc.add(const NetworkScoreEvent.loadCached());
    await tester.pump();
    await tester.pump();

    expect(find.text('NETWORK SCORE'), findsNothing);
    expect(find.text('NETZWERKBEWERTUNG'), findsOneWidget);
    // The dimension chips are abbreviations of the translated names, so English
    // letters here would mean the stored token leaked into the UI.
    expect(
      find.textContaining('SEC', findRichText: true),
      findsNothing,
    );
    for (final chip in ['SIC', 'ZUS', 'VER', 'TMP', 'SCH']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
  });
}
