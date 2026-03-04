import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/external_link_dialog.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? lastLaunchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(
    String url,
    LaunchOptions options,
  ) async {
    lastLaunchedUrl = url;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalLinkWarningDialog', () {
    late UrlLauncherPlatform originalPlatform;
    late _FakeUrlLauncherPlatform fakePlatform;

    setUp(() {
      originalPlatform = UrlLauncherPlatform.instance;
      fakePlatform = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakePlatform;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalPlatform;
    });

    testWidgets('renders title, link and triggers launch on action tap',
        (tester) async {
      const url = 'https://example.com';

      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ExternalLinkWarningDialog(link: url),
            ),
          ),
        ),
      );

      expect(find.text('Confirm external link'), findsOneWidget);
      expect(find.text(url), findsOneWidget);
      expect(find.text('Open Link'), findsOneWidget);

      await tester.tap(find.text('Open Link'));
      await tester.pump();

      expect(fakePlatform.lastLaunchedUrl, url);
    });
  });
}
