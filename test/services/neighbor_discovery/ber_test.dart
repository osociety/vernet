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

      final bigPayload = List<int>.filled(500, 1);
      final bigSeq = Ber.encodeSequence(bigPayload);
      final bigTlv = Ber.decodeTlv(bigSeq, 0);
      expect(bigTlv.value.length, 500);
    });

    test('round-trips negative integers', () {
      for (final value in [-1, -50, -128, -256, -32768]) {
        final encoded = Ber.encodeInteger(value);
        final tlv = Ber.decodeTlv(encoded, 0);
        expect(Ber.decodeInteger(tlv.value), value);
      }
      expect(Ber.decodeInteger([]), 0);
    });

    test('encodeNull produces valid null TLV', () {
      final n = Ber.encodeNull();
      expect(n, [0x05, 0x00]);
    });

    test('encodeLength validation', () {
      expect(() => Ber.encodeLength(-1), throwsArgumentError);
      expect(Ber.encodeLength(1000), [0x82, 0x03, 0xe8]);
      expect(() => Ber.encodeLength(0x10000), throwsArgumentError);
    });

    test('decodeLength error handling', () {
      expect(() => Ber.decodeLength([], 0), throwsFormatException);
      expect(() => Ber.decodeLength([0x80], 0), throwsFormatException);
      expect(() => Ber.decodeLength([0x82, 0x01], 0), throwsFormatException);
    });

    test('encodeOid validation', () {
      expect(() => Ber.encodeOid('1'), throwsArgumentError);
      expect(() => Ber.encodeOid(''), throwsArgumentError);
    });

    test('decodeOid error handling', () {
      expect(() => Ber.decodeOid([]), throwsFormatException);
    });

    test('decodeTlv error handling', () {
      expect(() => Ber.decodeTlv([], 0), throwsFormatException);
      expect(() => Ber.decodeTlv([0x04, 0x05, 0x01, 0x02], 0), throwsFormatException);
    });
  });
}
