import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

class MockPermissionHandler extends Mock with MockPlatformInterfaceMixin {}

class MockDarkThemeProvider extends Mock implements DarkThemeProvider {
  @override
  ThemePreference get themePref => ThemePreference.light;
  @override
  bool get darkTheme => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'vernet',
          'packageName': 'org.fsociety.vernet',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    // Mock PermissionHandler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions') {
        return {3: 1}; // 3 is location, 1 is granted (PermissionStatus.granted)
      }
      return null;
    });
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<DarkThemeProvider>(
      create: (_) => DarkThemeProvider(),
      child: const MaterialApp(
        home: LocationConsentPage(),
      ),
    );
  }

  testWidgets('LocationConsentPage renders correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Vernet'), findsOneWidget);
    expect(find.text('Grant Location Permission'), findsOneWidget);
    expect(find.text('Continue without permission'), findsOneWidget);
  });

  testWidgets('Choosing "Continue without permission" navigates to TabBarPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Continue without permission'));
    await tester.pumpAndSettle();

    expect(find.byType(TabBarPage), findsOneWidget);
  });

  testWidgets('Choosing "Grant Location Permission" navigates to TabBarPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Grant Location Permission'));
    await tester.pumpAndSettle();

    expect(find.byType(TabBarPage), findsOneWidget);
  });
}
