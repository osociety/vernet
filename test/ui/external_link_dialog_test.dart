import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/external_link_dialog.dart';

class MockUrlLauncherPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  group('ExternalLinkWarningDialog', () {
    late MockUrlLauncherPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockUrlLauncherPlatform();
      UrlLauncherPlatform.instance = mockPlatform;

      when(() => mockPlatform.canLaunch(any())).thenAnswer((_) async => true);
      when(() => mockPlatform.launch(
            any(),
            useSafariVC: any(named: 'useSafariVC'),
            useWebView: any(named: 'useWebView'),
            enableJavaScript: any(named: 'enableJavaScript'),
            enableDomStorage: any(named: 'enableDomStorage'),
            universalLinksOnly: any(named: 'universalLinksOnly'),
            headers: any(named: 'headers'),
            webOnlyWindowName: any(named: 'webOnlyWindowName'),
          )).thenAnswer((_) async => true);
      when(() => mockPlatform.launchUrl(any(), any()))
          .thenAnswer((_) async => true);
    });

    testWidgets('renders title, link and triggers launch on action tap',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const url = 'https://example.com';

      // Use showAdaptiveDialog directly in the test.
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final BuildContext context = tester.element(find.byType(Scaffold));
      showAdaptiveDialog(
        context: context,
        builder: (context) => const ExternalLinkWarningDialog(link: url),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm external link'), findsOneWidget);
      expect(find.text(url), findsOneWidget);

      await tester.tap(find.text('Open Link'));
      await tester.pumpAndSettle();

      verify(() => mockPlatform.canLaunch(url)).called(1);
      verify(() => mockPlatform.launchUrl(url, any())).called(1);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
