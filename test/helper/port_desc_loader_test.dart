import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/helper/port_desc_loader.dart';
import 'package:vernet/models/port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PortDescLoader', () {
    test('loads and parses ports_lists asset', () async {
      final loader = PortDescLoader('assets/ports_lists.json');

      final Map<String, Port> ports = await loader.load();

      expect(ports, isNotEmpty);
      expect(ports.containsKey('1'), isTrue);

      final port1 = ports['1']!;
      expect(port1.port, '1');
      expect(port1.desc, isNotEmpty);
      expect(port1.isTCP, isTrue);
    });
  });
}

