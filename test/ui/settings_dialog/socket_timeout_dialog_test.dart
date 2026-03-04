import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/ui/settings_dialog/socket_timeout_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocketTimeoutDialog', () {
    test('widget can be instantiated', () {
      const dialog = SocketTimeoutDialog();
      expect(dialog, isA<SocketTimeoutDialog>());
    });

    test('is StatefulWidget', () {
      const dialog = SocketTimeoutDialog();
      expect(dialog, isA<StatefulWidget>());
    });
  });
}
