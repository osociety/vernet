import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/ping_count_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PingCountDialog', () {
    test('widget can be instantiated', () {
      const dialog = PingCountDialog();
      expect(dialog, isA<PingCountDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = PingCountDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
