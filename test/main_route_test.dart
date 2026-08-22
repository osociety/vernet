import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/home_page.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/providers/dark_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Main.dart Route Tests', () {
    testWidgets('initial route shows HomePage when allowed=true', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('MyApp with allowed=false shows LocationConsentPage',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(false),
        ),
      );
      await tester.pumpAndSettle();

      // Should show LocationConsentPage when not allowed
      expect(find.byType(LocationConsentPage), findsOneWidget);
    });

    testWidgets('navigatorKey is properly configured', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: const MyApp(true),
        ),
      );
      await tester.pumpAndSettle();

      expect(MyApp.navigatorKey.currentState, isNotNull);
      expect(MyApp.navigatorKey.currentState?.context, isNotNull);
    });

    testWidgets('MyApp is StatefulWidget', (tester) async {
      expect(const MyApp(true), isA<StatefulWidget>());
    });

    testWidgets('MyApp navigatorKey is static and accessible', (tester) async {
      expect(MyApp.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });
}
