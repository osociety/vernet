import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/pages/ping_page/ping_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/keys.dart';

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
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PingPage', () {
    testWidgets('renders all initial UI components and statistics placeholders',
        (tester) async {
      await tester.pumpWidget(createPingPageTestWidget(const PingPage()));

      expect(find.text('Check connection'), findsOneWidget);
      expect(find.text('Enter a website or device address'), findsOneWidget);
      expect(find.text('Start check'), findsOneWidget);
      expect(find.text('Connection results will appear here'), findsOneWidget);

      // Verify all summary statistic items are present
      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryPacketLoss.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryMin.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryAvg.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryMax.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryStdDev.key), findsOneWidget);

      expect(find.text('Checks sent: --'), findsOneWidget);
      expect(find.text('Replies received: --'), findsOneWidget);
      expect(find.text('Packet loss: --'), findsOneWidget);
      expect(find.text('Total time: --'), findsOneWidget);
      expect(find.text('Min: --'), findsOneWidget);
      expect(find.text('Avg: --'), findsOneWidget);
      expect(find.text('Max: --'), findsOneWidget);
      expect(find.text('Std dev: --'), findsOneWidget);
    });

    testWidgets('initializes with target address when provided', (tester) async {
      await tester.pumpWidget(
        createPingPageTestWidget(const PingPage(target: '192.168.1.1')),
      );

      expect(find.text('192.168.1.1'), findsOneWidget);
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
      await tester.tap(find.text('Start check'));
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
      expect(find.text('Min: 10.0 ms'), findsOneWidget);
      expect(find.text('Avg: 10.0 ms'), findsOneWidget);
      expect(find.text('Max: 10.0 ms'), findsOneWidget);

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
      expect(find.text('Min: 10.0 ms'), findsOneWidget);
      expect(find.text('Avg: 15.0 ms'), findsOneWidget);
      expect(find.text('Max: 20.0 ms'), findsOneWidget);
      expect(find.text('Std dev: 5.0 ms'), findsOneWidget);

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
      expect(find.text('Checks sent: 2'), findsOneWidget);
      expect(find.text('Replies received: 2'), findsOneWidget);
      expect(find.text('Packet loss: 0%'), findsOneWidget);
      expect(find.text('Total time: 1500.0 ms'), findsOneWidget);
      expect(find.text('Min: 10.0 ms'), findsOneWidget);
      expect(find.text('Avg: 15.0 ms'), findsOneWidget);
      expect(find.text('Max: 20.0 ms'), findsOneWidget);
      expect(find.text('Std dev: 5.0 ms'), findsOneWidget);
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

        await tester.tap(find.text('Start check'));
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
        expect(find.text('Total time: --'), findsNothing);
        expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);
        expect(find.text('Checks sent: 4'), findsOneWidget);
        expect(find.text('Replies received: 4'), findsOneWidget);
      });
    });
  });
}
