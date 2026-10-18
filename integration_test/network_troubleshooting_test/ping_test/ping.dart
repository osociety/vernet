import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';
import '../../settings/test_utils.dart';

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final appSettings = AppSettings.instance;

  setUpAll(() async {
    globals.testingActive = true;
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
  });
  group('Ping integration test', () {
    testWidgets('tap on the ping button, verify ping ended', (tester) async {
      await appSettings.load();
      // Load app widget.
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapNavigationItem('Check a website', tester, find);
      final interface = await NetInterface.localInterface();

      await tester.enterText(
        find.byType(TextFormField),
        interface?.ipAddress ?? '192.168.0.1',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);

      await TestUtils.waitForWidget(
        tester,
        find.byKey(WidgetKey.pingSummarySent.key),
        timeout: const Duration(seconds: 30),
      );

      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryTotalTime.key), findsOneWidget);

      expect(find.byKey(WidgetKey.pingSummarySent.key), findsOneWidget);
      expect(find.byKey(WidgetKey.pingSummaryReceived.key), findsOneWidget);
    });
  });
}
