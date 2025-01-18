import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vernet/helper/app_settings.dart';
import 'package:vernet/main.dart';
import 'package:vernet/values/keys.dart';

import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final appSettings = AppSettings.instance;
  group('subnet tests', () {
    testWidgets('set custom subnet test', (tester) async {
      await appSettings.load();

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.customSubnetTile,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.customSubnetTile, tester, find);

      await TestUtils.enterTextByKey(
        WidgetKey.settingsTextField,
        '192.168.1.0',
        tester,
        find,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsSubmitButton,
        tester,
        find,
      );
      await appSettings.load();

      expect(appSettings.customSubnet, '192.168.1.0');
    });

    testWidgets('First subnet test', (tester) async {
      await appSettings.load();

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.firstSubnetTile,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.firstSubnetTile, tester, find);

      await TestUtils.enterTextByKey(
        WidgetKey.settingsTextField,
        '10',
        tester,
        find,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsSubmitButton,
        tester,
        find,
      );
      await appSettings.load();

      expect(appSettings.firstSubnet, 10);
    });

    testWidgets('Last subnet test', (tester) async {
      await appSettings.load();

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.lastSubnetTile,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.lastSubnetTile, tester, find);

      await TestUtils.enterTextByKey(
        WidgetKey.settingsTextField,
        '250',
        tester,
        find,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsSubmitButton,
        tester,
        find,
      );
      await appSettings.load();

      expect(appSettings.lastSubnet, 250);
    });

    testWidgets('Socket timeout test', (tester) async {
      await appSettings.load();

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.socketTimeoutTile,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.socketTimeoutTile, tester, find);

      await TestUtils.enterTextByKey(
        WidgetKey.settingsTextField,
        '250',
        tester,
        find,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsSubmitButton,
        tester,
        find,
      );
      await appSettings.load();

      expect(appSettings.socketTimeout, 250);
    });

    testWidgets('Ping count test', (tester) async {
      await appSettings.load();

      await tester.pumpWidget(const MyApp(true));

      await TestUtils.tapSettingsButton(tester, find);

      await TestUtils.scrollUntilVisibleByWidgetKey(
        WidgetKey.pingCountTile,
        tester,
        find,
        200.0,
      );

      await TestUtils.tapByWidgetKey(WidgetKey.pingCountTile, tester, find);

      await TestUtils.enterTextByKey(
        WidgetKey.settingsTextField,
        '6',
        tester,
        find,
      );

      await TestUtils.tapByWidgetKey(
        WidgetKey.settingsSubmitButton,
        tester,
        find,
      );
      await appSettings.load();

      expect(appSettings.pingCount, 6);
    });
  });
}
