import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/external_link_dialog.dart';

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  group('UtilsHelper', () {
    late MockUrlLauncher mockUrlLauncher;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
    });

    test('storeCurrentScanId and getCurrentScanId round trip', () async {
      await storeCurrentScanId(42);
      final id = await getCurrentScanId();

      expect(id, 42);
    });

    test('launchURL calls canLaunch and launch', () async {
      const url = 'https://flutter.dev';
      when(() => mockUrlLauncher.canLaunch(url)).thenAnswer((_) async => true);
      when(() => mockUrlLauncher.launchUrl(url, any()))
          .thenAnswer((_) async => true);

      await launchURL(url);

      verify(() => mockUrlLauncher.canLaunch(url)).called(1);
      verify(() => mockUrlLauncher.launchUrl(url, any())).called(1);
    });

    test('launchURL throws error if canLaunch returns false', () {
      const url = 'invalid_url';
      when(() => mockUrlLauncher.canLaunch(url)).thenAnswer((_) async => false);

      expect(() => launchURL(url), throwsA(contains('Could not launch')));
    });

    testWidgets('launchURLWithWarning shows ExternalLinkWarningDialog',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Click me'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('Click me'));
      launchURLWithWarning(context, 'https://flutter.dev');
      await tester.pumpAndSettle();

      expect(find.byType(ExternalLinkWarningDialog), findsOneWidget);
      expect(find.textContaining('https://flutter.dev'), findsOneWidget);
    });
  });
}
