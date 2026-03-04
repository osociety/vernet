import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/custom_subnet_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomSubnetDialog', () {
    test('widget can be instantiated', () {
      const dialog = CustomSubnetDialog();
      expect(dialog, isA<CustomSubnetDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = CustomSubnetDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
