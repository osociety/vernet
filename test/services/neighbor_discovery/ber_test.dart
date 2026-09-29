import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/neighbor_discovery/ber.dart';

void main() {
  group('Ber', () {
    test('round-trips integers', () {
      for (final value in [0, 1, 127, 128, 255, 256, 65535, 0x7fffffff]) {
        final encoded = Ber.encodeInteger(value);
        final tlv = Ber.decodeTlv(encoded, 0);
        expect(tlv.tag, 0x02);
        expect(Ber.decodeInteger(tlv.value), value);
      }
    });

    test('round-trips OIDs', () {
      const oid = '1.3.6.1.4.1.9.9.23.1.2.1.1.6.24.1';
      final encoded = Ber.encodeOid(oid);
      final tlv = Ber.decodeTlv(encoded, 0);
      expect(Ber.decodeOid(tlv.value), oid);
    });

    test('encodes long form lengths', () {
      final payload = List<int>.filled(200, 1);
      final seq = Ber.encodeSequence(payload);
      final tlv = Ber.decodeTlv(seq, 0);
      expect(tlv.value.length, 200);
    });
  });
}
