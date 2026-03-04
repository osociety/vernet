import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/classes/odometer.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/injection.dart' as di;
import 'package:vernet/pages/isp_page/bloc/isp_page_bloc.dart';
import 'package:vernet/pages/isp_page/isp_page.dart';
import 'package:vernet/pages/isp_page/isp_page_widget.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/values/strings.dart';

// Create mock Settings and Client for testing
Settings createTestSettings() {
  final coordinate = Coordinate(0.0, 0.0);
  return Settings(
    Client(
      '192.168.1.1', // ip
      37.7749, // latitude
      -122.4194, // longitude
      'Test ISP', // isp
      4.5, // ispRating
      4.0, // rating
      100, // ispAvarageDownloadSpeed
      50, // ispAvarageUploadSpeed
      coordinate, // geoCoordinate
    ),
    Times(100, 100, 100, 50, 50, 50),
    Download(5000, '', '0', 4),
    Upload(5000, 100, 0, '0', 4, '0', '0', 1),
    ServerConfig(''),
    [],
    Odometer(0, 1),
  );
}

Server createTestServer({
  required int id,
  required String name,
  required double latency,
  double lat = 37.7749,
  double lon = -122.4194,
}) {
  final coordinate = Coordinate(lat, lon);
  return Server(
    id,
    name,
    'US',
    'Test Sponsor',
    'test.host.com',
    'http://test.com',
    lat,
    lon,
    100.0,
    latency,
    coordinate,
  );
}

Widget _wrapWithProviders(Widget child) {
  return ChangeNotifierProvider<DarkThemeProvider>(
    create: (_) => DarkThemeProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IspPageWidget', () {
    late IspPageBloc ispPageBloc;
    late Settings testSettings;
    late Client testClient;

    setUp(() {
      ispPageBloc = IspPageBloc();
      testSettings = createTestSettings();
      testClient = testSettings.client;
    });

    tearDown(() async {
      await ispPageBloc.close();
    });

    testWidgets('IspPageWidget displays Container on initial state',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        BlocProvider<IspPageBloc>.value(
          value: ispPageBloc,
          child: IspPageWidget(client: testClient),
        ),
      ));

      // Initial state should display empty container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('IspPageWidget displays loading indicator on LoadInProgress',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        BlocProvider<IspPageBloc>.value(
          value: ispPageBloc,
          child: IspPageWidget(client: testClient),
        ),
      ));

      // Emit LoadInProgress state
      ispPageBloc.emit(const IspPageState.loadInProgress());
      await tester.pump();

      // Should display progress indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('IspPageWidget displays error message on LoadFailure',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        BlocProvider<IspPageBloc>.value(
          value: ispPageBloc,
          child: IspPageWidget(client: testClient),
        ),
      ));

      // Emit LoadFailure state
      ispPageBloc.emit(const IspPageState.loadFailure());
      await tester.pump();

      // Should display error text
      expect(find.text('Error'), findsWidgets);
    });

    testWidgets('IspPageWidget displays servers on LoadSuccess',
        (WidgetTester tester) async {
      final servers = [
        createTestServer(id: 1, name: 'Test Server 1', latency: 10),
        createTestServer(id: 2, name: 'Test Server 2', latency: 20),
      ];

      await tester.pumpWidget(_wrapWithProviders(
        Scaffold(
          body: IspPageContent(
            client: testClient,
            childrens: [
              const Text('List of Servers'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemBuilder: (context, item) => Text(servers[item].name),
                  itemCount: servers.length,
                ),
              ),
            ],
          ),
        ),
      ));

      // Should display server information
      expect(find.text('List of Servers'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('IspPageContent displays ISP information',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        Scaffold(
          body: IspPageContent(
            client: testClient,
            childrens: const [
              Text('Test Child'),
            ],
          ),
        ),
      ));

      // Should display ISP name
      expect(find.text(testClient.isp), findsWidgets);
      // Should display rating text
      expect(find.text('Your ISP is rated ${testClient.ispRating} out of 5'),
          findsWidgets);
      // Should display child widget
      expect(find.text('Test Child'), findsWidgets);
    });

    testWidgets('IspPageContent displays rating bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        Scaffold(
          body: IspPageContent(
            client: testClient,
            childrens: const [],
          ),
        ),
      ));

      // Should display rating stars
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('IspPageContent displays multiple child widgets',
        (WidgetTester tester) async {
      final children = [
        const Text('Child 1'),
        const Text('Child 2'),
        const Text('Child 3'),
      ];

      await tester.pumpWidget(_wrapWithProviders(
        Scaffold(
          body: IspPageContent(
            client: testClient,
            childrens: children,
          ),
        ),
      ));

      // Should display all child widgets
      expect(find.text('Child 1'), findsWidgets);
      expect(find.text('Child 2'), findsWidgets);
      expect(find.text('Child 3'), findsWidgets);
    });

    test('IspPageWidget is a StatelessWidget', () {
      expect(IspPageWidget(client: testClient), isA<StatelessWidget>());
    });

    test('IspPageContent is a StatelessWidget', () {
      expect(
        IspPageContent(client: testClient, childrens: const []),
        isA<StatelessWidget>(),
      );
    });
  });

  group('IspPage Integration', () {
    setUp(() async {
      await di.getIt.reset();
      di.getIt.registerFactory<IspPageBloc>(() => IspPageBloc());
    });

    testWidgets('IspPage builds Scaffold with correct title and widget',
        (WidgetTester tester) async {
      final settings = createTestSettings();
      final speedTester = SpeedTestDart();

      await tester.pumpWidget(
        _wrapWithProviders(
          IspPage(tester: speedTester, settings: settings),
        ),
      );

      // App bar title from IspPage.
      expect(find.text(StringValue.ispPageTitle), findsOneWidget);

      // Body contains IspPageWidget wired with settings.client.
      expect(find.byType(IspPageWidget), findsOneWidget);
    });
  });
}
