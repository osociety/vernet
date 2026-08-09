import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';

Widget wrapWithDarkThemeProvider({required Widget child}) {
  return ChangeNotifierProvider(
    create: (_) => DarkThemeProvider(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Parameterized test data for all settings dialogs
  final dialogTests = [
    ('CustomSubnetDialog', const CustomSubnetDialog()),
    ('FirstSubnetDialog', const FirstSubnetDialog()),
    ('LastSubnetDialog', const LastSubnetDialog()),
    ('PingCountDialog', const PingCountDialog()),
    ('SocketTimeoutDialog', const SocketTimeoutDialog()),
    ('ThemeDialog', const ThemeDialog()),
  ];

  group('Settings Dialogs', () {
    for (final dialogTest in dialogTests) {
      final dialogName = dialogTest.$1;
      final dialog = dialogTest.$2;

      group(dialogName, () {
        test('can be instantiated', () {
          expect(dialog, isA<StatefulWidget>());
        });

        test('is StatefulWidget', () {
          expect(dialog, isA<StatefulWidget>());
        });

        testWidgets('renders without errors', (tester) async {
          await tester.pumpWidget(wrapWithDarkThemeProvider(child: dialog));
          await tester.pumpAndSettle();
          // If we get here without exceptions, the dialog rendered successfully
          expect(find.byType(dialog.runtimeType), findsOneWidget);
        });
      });
    }

    group('CustomSubnetDialog', () {
      testWidgets('builds CustomSubnetDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const CustomSubnetDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CustomSubnetDialog), findsOneWidget);
      });
    });

    group('FirstSubnetDialog', () {
      testWidgets('builds FirstSubnetDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const FirstSubnetDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FirstSubnetDialog), findsOneWidget);
      });
    });

    group('LastSubnetDialog', () {
      testWidgets('builds LastSubnetDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const LastSubnetDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LastSubnetDialog), findsOneWidget);
      });
    });

    group('PingCountDialog', () {
      testWidgets('builds PingCountDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const PingCountDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PingCountDialog), findsOneWidget);
      });
    });

    group('SocketTimeoutDialog', () {
      testWidgets('builds SocketTimeoutDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const SocketTimeoutDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SocketTimeoutDialog), findsOneWidget);
      });
    });

    group('ThemeDialog', () {
      testWidgets('builds ThemeDialog widget', (tester) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const ThemeDialog()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ThemeDialog), findsOneWidget);
      });
    });
  });
}
