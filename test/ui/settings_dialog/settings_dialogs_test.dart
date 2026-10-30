import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

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

      Future<void> enterAndSubmit(WidgetTester tester, String value) async {
        await tester.pumpWidget(
          wrapWithDarkThemeProvider(child: const CustomSubnetDialog()),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(WidgetKey.settingsTextField.key),
          value,
        );
        await tester.tap(find.byKey(WidgetKey.settingsSubmitButton.key));
        await tester.pumpAndSettle();
      }

      for (final invalid in ['abc', '1.2.3', '999.1.1.1', '10.0.0.-1']) {
        testWidgets('rejects invalid IPv4 "$invalid"', (tester) async {
          await enterAndSubmit(tester, invalid);
          expect(find.text(StringValue.customSubnetInvalid), findsOneWidget);
        });
      }

      for (final networkAddress in ['192.168.1.0', '10.0.0.255']) {
        testWidgets('rejects network/broadcast address "$networkAddress"',
            (tester) async {
          await enterAndSubmit(tester, networkAddress);
          expect(
            find.text(StringValue.customSubnetNotUsableHost),
            findsOneWidget,
          );
        });
      }

      testWidgets('accepts a valid host address', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await enterAndSubmit(tester, '10.0.0.1');
        expect(find.text(StringValue.customSubnetInvalid), findsNothing);
        expect(find.text(StringValue.customSubnetNotUsableHost), findsNothing);
        expect(find.byType(CustomSubnetDialog), findsNothing);
      });

      testWidgets('accepts empty input to clear the setting', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await enterAndSubmit(tester, '');
        expect(find.byType(CustomSubnetDialog), findsNothing);
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
