import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/dns/reverse_dns_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReverseDNSPage', () {
    test('ReverseDNSPage widget can be instantiated', () {
      const page = ReverseDNSPage();
      expect(page, isA<ReverseDNSPage>());
    });

    test('ReverseDNSPage is StatefulWidget', () {
      const page = ReverseDNSPage();
      expect(page, isA<StatefulWidget>());
    });
  });
}
