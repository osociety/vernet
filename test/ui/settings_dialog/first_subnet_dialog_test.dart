import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/first_subnet_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirstSubnetDialog', () {
    test('widget can be instantiated', () {
      const dialog = FirstSubnetDialog();
      expect(dialog, isA<FirstSubnetDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = FirstSubnetDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
