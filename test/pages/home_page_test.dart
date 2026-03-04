import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage', () {
    test('HomePage widget can be instantiated', () {
      const page = HomePage();
      expect(page, isA<HomePage>());
    });

    test('HomePage is StatefulWidget', () {
      const page = HomePage();
      expect(page, isA<StatefulWidget>());
    });
  });
}
