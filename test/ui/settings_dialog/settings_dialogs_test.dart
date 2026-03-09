import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';

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
      });
    }
  });
}
