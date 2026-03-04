import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/enums/file_size.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/speed_test_dialog.dart';

class _FakeSpeedTestDart extends SpeedTestDart {
  _FakeSpeedTestDart({
    required this.bestServers,
    this.downloadSpeed = 123.0,
    this.uploadSpeed = 45.0,
  });

  final List<Server> bestServers;
  final double downloadSpeed;
  final double uploadSpeed;

  @override
  Future<List<Server>> getBestServers({
    required List<Server> servers,
    int retryCount = 2,
    int timeoutInSeconds = 2,
  }) async {
    return bestServers;
  }

  @override
  Future<double> testDownloadSpeed({
    required List<Server> servers,
    int simultaneousDownloads = 2,
    int retryCount = 3,
    List<FileSize> downloadSizes = const [],
  }) async {
    return downloadSpeed;
  }

  @override
  Future<double> testUploadSpeed({
    required List<Server> servers,
    int simultaneousUploads = 2,
    int retryCount = 3,
  }) async {
    return uploadSpeed;
  }
}

Server _server({
  required int id,
  required String name,
  required double latency,
}) {
  final coordinate = Coordinate(0.0, 0.0);
  return Server(
    id,
    name,
    'US',
    'Sponsor',
    'host',
    'http://example.com',
    0.0,
    0.0,
    0.0,
    latency,
    coordinate,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeedTestDialog', () {
    testWidgets('shows loading state then renders best server info',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeTester = _FakeSpeedTestDart(
        bestServers: [
          _server(id: 1, name: 'A', latency: 20),
          _server(id: 2, name: 'B', latency: 10),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: SpeedTestDialog(
                tester: fakeTester,
                servers: const [],
                odometerStart: 0,
              ),
            ),
          ),
        ),
      );

      // First frame: best servers not loaded yet.
      expect(find.text('Loading Best Servers'), findsOneWidget);

      // Resolve getBestServers + rebuild.
      await tester.pump();

      expect(find.textContaining('Best server:'), findsOneWidget);
      expect(find.textContaining('Latency:'), findsOneWidget);
    });

    testWidgets('start button runs download+upload and shows final speeds',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeTester = _FakeSpeedTestDart(
        bestServers: [
          _server(id: 1, name: 'Fast', latency: 5),
        ],
        downloadSpeed: 111.0,
        uploadSpeed: 22.0,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: SpeedTestDialog(
                tester: fakeTester,
                servers: const [],
                odometerStart: 0,
              ),
            ),
          ),
        ),
      );

      // Resolve best servers.
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Advance timers / stream iterations a bit without pumpAndSettle (gauges animate).
      await tester.pump(const Duration(milliseconds: 600));

      // After completion, upload result row should be visible.
      expect(find.byIcon(Icons.upload), findsOneWidget);
      expect(find.text('22 Mbps'), findsOneWidget);
    });
  });
}
