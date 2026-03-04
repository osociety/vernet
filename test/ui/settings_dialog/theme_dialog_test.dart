import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/theme_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeDialog', () {
    test('widget can be instantiated', () {
      const dialog = ThemeDialog();
      expect(dialog, isA<ThemeDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = ThemeDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
