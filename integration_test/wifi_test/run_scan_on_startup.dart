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

import '../settings/test_utils.dart';
import 'wifi_test_runner.dart' show clearDatabase;

void main() {
  globals.testingActive = true;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
  });

  setUp(() async {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
    // Clear database before each test to prevent stale scan records
    await clearDatabase();
  });

  group('Run device scan on startup', () {
    testWidgets('if settings for startup is on, then it should run',
        (tester) async {
      await tester.pumpWidget(const MyApp(true));
      await tester.pumpAndSettle();

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.tapByWidgetKey(
        WidgetKey.runOnAppStartupSwitch,
        tester,
        find,
      );

      await TestUtils.tapHomeButton(tester, find);

      // pump with a longer timeout to rebuild HomePage after navigation
      // and allow platform channels to respond
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await TestUtils.waitForWidget(
        tester,
        find.byKey(WidgetKey.runScanOnStartup.key),
      );
      expect(find.byKey(WidgetKey.runScanOnStartup.key), findsOne);
    });
  });
}
