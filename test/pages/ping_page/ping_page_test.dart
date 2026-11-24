import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/repository/drift/device_repository.dart';
import 'package:vernet/repository/drift/scan_repository.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';
import 'package:vernet/values/keys.dart';

import '../../helpers/test_helpers.dart';

class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<AppDatabase?> open() async => db;
}

class FakePing implements Ping {
  FakePing(this._stream);
  final Stream<PingEvent> _stream;

  @override
  late PingParser parser;

  @override
  String get command => 'fake ping';

  @override
  Stream<PingEvent> get stream => _stream;

  @override
  Future<bool> stop() async => true;
}

Widget createPingPageTestWidget(Widget child) {
  return ChangeNotifierProvider<DarkThemeProvider>(
    create: (_) => DarkThemeProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// The English bundle, so the assertions follow the copy the app renders instead
/// of repeating it.
final l10n = l10nEn();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  tearDown(() async {
    if (GetIt.instance.isRegistered<AppDatabase>()) {
      await GetIt.instance<AppDatabase>().close();
    }
    await GetIt.instance.reset();
  });

  group('PingPage', () {
    testWidgets('uses the saved ping count when starting a check',
        (tester) async {
      await AppSettings.instance.setPingCount(7);
      final controller = StreamController<PingEvent>();
      int? usedCount;

      await tester.pumpWidget(
        createPingPageTestWidget(
          PingPage(
            target: '1.1.1.1',
            pingBuilder: (host, {count, forceCodepage = false}) {
              usedCount = count;
              return FakePing(controller.stream);
            },
          ),
        ),
      );

      await tester.tap(find.text(l10n.startCheck));
      await tester.pump();

      expect(usedCount, 7);

      await controller.close();
      await tester.pumpAndSettle();
    });

    testWidgets('renders all initial UI components and statistics placeholders',
        (tester) async {
      await tester.pumpWidget(createPingPageTestWidget(const PingPage()));

      expect(find.text(l10n.pingPageTitle), findsOneWidget);
      expect(find.text(l10n.pingFieldHint), findsOneWidget);
      expect(find.text(l10n.startCheck), findsOneWidget);
      expect(find.text(l10n.pingResultsEmpty), findsOneWidget);

      // Verify all summary statistic items are present
      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryPacketLoss.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryMin.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryAvg.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryMax.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryStdDev.key), findsOneWidget);

      expect(find.text(l10n.pingSummarySent('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryReceived('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryPacketLoss('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryTotalTime('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMin('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryAvg('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMax('--')), findsOneWidget);
      expect(find.text(l10n.pingSummaryStdDev('--')), findsOneWidget);
    });

    testWidgets('initializes with target address when provided',
        (tester) async {
      await tester.pumpWidget(
        createPingPageTestWidget(const PingPage(target: '192.168.1.1')),
      );

      expect(find.text('192.168.1.1'), findsOneWidget);
    });

    // BasePage builds the scaffold for Ping, DNS and Reverse DNS, so this one
    // case covers the inset handling of all three. osociety/vernet#428.
    testWidgets('keeps the results list clear of the navigation bar',
        (tester) async {
      await tester.pumpWidget(createPingPageTestWidget(const PingPage()));

      fakeSystemBarInsets(tester);
      await tester.pump();

      expect(
        tester.getSize(find.byType(AppBar)).height,
        greaterThanOrEqualTo(kToolbarHeight + kTestStatusBarInset),
      );
      expect(
        tester.getBottomLeft(find.byType(ListView).first).dy,
        lessThanOrEqualTo(safeBottom(tester)),
      );
    });

    testWidgets('tapping a popular chip fills text field', (tester) async {
      await tester.pumpWidget(createPingPageTestWidget(const PingPage()));

      await tester.tap(find.text('google.com'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'google.com'),
        findsOneWidget,
      );
    });

    testWidgets(
        'runs ping and displays packet results and round-trip statistics',
        (tester) async {
      final controller = StreamController<PingEvent>();

      await tester.pumpWidget(
        createPingPageTestWidget(
          PingPage(
            target: '1.1.1.1',
            pingBuilder: (host, {count, forceCodepage = false}) =>
                FakePing(controller.stream),
          ),
        ),
      );

      // Tap 'Start check'
      await tester.tap(find.text(l10n.startCheck));
      await tester.pump();

      // Emit first response
      controller.add(
        const PingResponse(
          seq: 1,
          ip: '1.1.1.1',
          time: Duration(milliseconds: 10),
          stats: RoundTripStats(
            min: Duration(milliseconds: 10),
            avg: Duration(milliseconds: 10),
            max: Duration(milliseconds: 10),
            stddev: Duration.zero,
            sampleCount: 1,
          ),
        ),
      );
      await tester.pump();

      // Verify packet list has seq 1 and 10.0 ms
      expect(find.text('1'), findsOneWidget);
      expect(find.text('10.0 ms'), findsWidgets);
      expect(find.text(l10n.pingSummaryMin('10.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryAvg('10.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMax('10.0 ms')), findsOneWidget);

      // Emit second response
      controller.add(
        const PingResponse(
          seq: 2,
          ip: '1.1.1.1',
          time: Duration(milliseconds: 20),
          stats: RoundTripStats(
            min: Duration(milliseconds: 10),
            avg: Duration(milliseconds: 15),
            max: Duration(milliseconds: 20),
            stddev: Duration(milliseconds: 5),
            sampleCount: 2,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text(l10n.pingSummaryMin('10.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryAvg('15.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMax('20.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryStdDev('5.0 ms')), findsOneWidget);

      // Emit summary event
      controller.add(
        PingSummary(
          transmitted: 2,
          received: 2,
          time: const Duration(milliseconds: 1500),
          stats: const RoundTripStats(
            min: Duration(milliseconds: 10),
            avg: Duration(milliseconds: 15),
            max: Duration(milliseconds: 20),
            stddev: Duration(milliseconds: 5),
            sampleCount: 2,
          ),
        ),
      );
      await controller.close();
      await tester.pumpAndSettle();

      // Verify final statistics
      expect(find.text(l10n.pingSummarySent('2')), findsOneWidget);
      expect(find.text(l10n.pingSummaryReceived('2')), findsOneWidget);
      expect(find.text(l10n.pingSummaryPacketLoss('0%')), findsOneWidget);
      expect(find.text(l10n.pingSummaryTotalTime('1500.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMin('10.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryAvg('15.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryMax('20.0 ms')), findsOneWidget);
      expect(find.text(l10n.pingSummaryStdDev('5.0 ms')), findsOneWidget);
    });

    testWidgets(
        'falls back to elapsed stopwatch time when summary.time is null (macOS/Windows)',
        (tester) async {
      await tester.runAsync(() async {
        final controller = StreamController<PingEvent>();

        await tester.pumpWidget(
          createPingPageTestWidget(
            PingPage(
              target: '1.1.1.1',
              pingBuilder: (host, {count, forceCodepage = false}) =>
                  FakePing(controller.stream),
            ),
          ),
        );

        await tester.tap(find.text(l10n.startCheck));
        await tester.pump();

        // Wait a tiny bit so elapsed stopwatch is > 0
        await Future<void>.delayed(const Duration(milliseconds: 15));

        // Emit summary with time: null (matches macOS/Windows dart_ping behavior)
        controller.add(
          PingSummary(
            transmitted: 4,
            received: 4,
            stats: const RoundTripStats(
              min: Duration(milliseconds: 30),
              avg: Duration(milliseconds: 32),
              max: Duration(milliseconds: 34),
              stddev: Duration(milliseconds: 2),
              sampleCount: 4,
            ),
          ),
        );
        await controller.close();
        await tester.pumpAndSettle();

        // Total time should not be '--'
        expect(find.text(l10n.pingSummaryTotalTime('--')), findsNothing);
        expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);
        expect(find.text(l10n.pingSummarySent('4')), findsOneWidget);
        expect(find.text(l10n.pingSummaryReceived('4')), findsOneWidget);
      });
    });
  });
}
