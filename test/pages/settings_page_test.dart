import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage', () {
    test('SettingsPage widget can be instantiated', () {
      const page = SettingsPage();
      expect(page, isA<SettingsPage>());
    });

    test('SettingsPage is StatefulWidget', () {
      const page = SettingsPage();
      expect(page, isA<StatefulWidget>());
    });
  });
}
