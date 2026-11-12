import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

class MockUrlLauncherPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const githubReleases = 'https://github.com/osociety/vernet/releases/latest';

  late MockUrlLauncherPlatform launcher;

  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    launcher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = launcher;
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'Vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('external_app_launcher'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'isAppInstalled') return false;
      if (methodCall.method == 'openApp') return true;
      return null;
    });
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const Center(child: Text('Test')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('navigateToStore', () {
    testWidgets('asks which channel before linking out', (tester) async {
      await pumpHost(tester);

      unawaited(navigateToStore(tester.element(find.text('Test'))));
      await tester.pumpAndSettle();

      expect(find.text('Where to get the update'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      verifyNever(() => launcher.canLaunch(any()));
    });

    testWidgets('GitHub goes to the releases page', (tester) async {
      await pumpHost(tester);

      unawaited(navigateToStore(tester.element(find.text('Test'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      expect(find.text('Open this link?'), findsOneWidget);
      expect(find.text(githubReleases), findsOneWidget);
    });

    testWidgets('closing the choice opens nothing', (tester) async {
      await pumpHost(tester);

      unawaited(navigateToStore(tester.element(find.text('Test'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Open this link?'), findsNothing);
      verifyNever(() => launcher.canLaunch(any()));
    });
  });
}
