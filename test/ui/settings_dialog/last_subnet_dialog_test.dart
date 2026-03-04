import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/last_subnet_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LastSubnetDialog', () {
    test('widget can be instantiated', () {
      const dialog = LastSubnetDialog();
      expect(dialog, isA<LastSubnetDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = LastSubnetDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
