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
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/main.dart';
import 'package:vernet/repository/notification_service.dart';
import 'package:vernet/values/globals.dart' as globals;
import 'package:vernet/values/keys.dart';

import '../../settings/test_utils.dart';

/// The resource bundle the test device renders: these suites run in English.
final _en = AppLocalizationsEn();

/// Google rotates the edge hostname a PTR query returns, so these suites want
/// the shape of an answer rather than one specific answer.
final _edgeHostname = RegExp(r'\.1e100\.net$');
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

  setUp(() {
    globals.testingActive = true;
    NotificationService.skipPermissionRequests = true;
    SharedPreferences.setMockInitialValues({});
    AppSettings.instance.resetForTesting();
    TestUtils.configureAndroidChannelMocks();
  });
  group('Reverse DNS lookup integration test', () {
    testWidgets('tap on the reverse DNS lookup button, verify lookup ended',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(null, testing: true));
      await tester.pumpAndSettle();

      await TestUtils.tapNavigationItem(
        _en.navFindDeviceName,
        tester,
        find,
      );

      expect(
        find.text(_en.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '172.217.160.142',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final resultText = find.textContaining(_edgeHostname);

      expect(resultText, findsOneWidget);
      await tester.tap(resultText);
      await tester.pumpAndSettle();
      expect(find.text(_en.reverseDnsNameCopied), findsOneWidget);
    });

    testWidgets('tap on the reverse DNS lookup button, verify error returned',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(null, testing: true));
      await tester.pumpAndSettle();

      await TestUtils.tapNavigationItem(
        _en.navFindDeviceName,
        tester,
        find,
      );

      expect(
        find.text(_en.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '172.217.160.',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(
        find.text(_en.reverseDnsInvalidAddress),
        findsOneWidget,
      );
    });

    testWidgets(
        'tap on the reverse DNS lookup button, verify reverse address not found returned',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp(null, testing: true));
      await tester.pumpAndSettle();

      await TestUtils.tapNavigationItem(
        _en.navFindDeviceName,
        tester,
        find,
      );

      expect(
        find.text(_en.reverseDnsLookupEmptyPlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '0.0.0.0',
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(WidgetKey.basePageSubmitButton.key);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      // The page answers every lookup with `_edgeHostname` while
      // `globals.testingActive` is set, so this cannot assert the not-found
      // message: the fake returns before the resolver is ever asked.
      expect(find.textContaining(_edgeHostname), findsOneWidget);
    });
  });
}
