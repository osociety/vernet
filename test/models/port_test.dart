import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/models/port.dart';

void main() {
  group('Port model', () {
    test('constructs from json with all fields', () {
      final json = {
        'description': 'HTTP',
        'tcp': true,
        'udp': false,
        'port': '80',
        'status': 'open',
      };

      final port = Port.fromJson(json);

      expect(port.desc, 'HTTP');
      expect(port.isTCP, isTrue);
      expect(port.isUDP, isFalse);
      expect(port.port, '80');
      expect(port.status, 'open');
    });

    test('handles udp ports', () {
      final json = {
        'description': 'DNS',
        'tcp': false,
        'udp': true,
        'port': '53',
        'status': 'open',
      };

      final port = Port.fromJson(json);

      expect(port.isTCP, isFalse);
      expect(port.isUDP, isTrue);
      expect(port.port, '53');
    });
  });
}
