/// Minimal BER helpers for SNMPv2c.
class Ber {
  static List<int> encodeLength(int length) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length');
    }
    if (length < 128) {
      return [length];
    }
    if (length <= 0xff) {
      return [0x81, length];
    }
    if (length <= 0xffff) {
      return [0x82, (length >> 8) & 0xff, length & 0xff];
    }
    throw ArgumentError('BER length too large: $length');
  }

  static (int length, int headerBytes) decodeLength(
    List<int> bytes,
    int offset,
  ) {
    if (offset >= bytes.length) {
      throw const FormatException('Unexpected end of BER length');
    }
    final first = bytes[offset];
    if (first < 128) {
      return (first, 1);
    }
    final count = first & 0x7f;
    if (count == 0 || offset + count >= bytes.length) {
      throw const FormatException('Invalid BER length');
    }
    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | bytes[offset + 1 + i];
    }
    return (length, 1 + count);
  }

  static List<int> encodeInteger(int value) {
    final content = _integerBytes(value);
    return [0x02, ...encodeLength(content.length), ...content];
  }

  static List<int> _integerBytes(int value) {
    if (value == 0) {
      return [0x00];
    }
    final bytes = <int>[];
    var remaining = value;
    if (value > 0) {
      while (remaining > 0) {
        bytes.insert(0, remaining & 0xff);
        remaining >>= 8;
      }
      if (bytes.first & 0x80 != 0) {
        bytes.insert(0, 0x00);
      }
      return bytes;
    }
    // Two's complement for negatives (SNMP error-status can be 0 only in practice).
    var n = value;
    do {
      bytes.insert(0, n & 0xff);
      n >>= 8;
    } while (n != -1 || (bytes.first & 0x80) == 0);
    return bytes;
  }

  static int decodeInteger(List<int> content) {
    if (content.isEmpty) {
      return 0;
    }
    var value = content.first;
    if (value & 0x80 != 0) {
      value -= 256;
    }
    for (var i = 1; i < content.length; i++) {
      value = (value << 8) | content[i];
    }
    return value;
  }

  static List<int> encodeOctetString(List<int> value) {
    return [0x04, ...encodeLength(value.length), ...value];
  }

  static List<int> encodeNull() => [0x05, 0x00];

  static List<int> encodeOid(String oid) {
    final parts = oid.split('.').where((p) => p.isNotEmpty).map(int.parse).toList();
    if (parts.length < 2) {
      throw ArgumentError('OID must have at least two components: $oid');
    }
    final content = <int>[40 * parts[0] + parts[1]];
    for (var i = 2; i < parts.length; i++) {
      content.addAll(_encodeBase128(parts[i]));
    }
    return [0x06, ...encodeLength(content.length), ...content];
  }

  static List<int> _encodeBase128(int value) {
    if (value < 0) {
      throw ArgumentError.value(value);
    }
    if (value < 128) {
      return [value];
    }
    final stack = <int>[];
    var remaining = value;
    stack.add(remaining & 0x7f);
    remaining >>= 7;
    while (remaining > 0) {
      stack.add((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    return stack.reversed.toList();
  }

  static String decodeOid(List<int> content) {
    if (content.isEmpty) {
      throw const FormatException('Empty OID');
    }
    final first = content.first;
    final parts = <int>[first ~/ 40, first % 40];
    var value = 0;
    for (var i = 1; i < content.length; i++) {
      final byte = content[i];
      value = (value << 7) | (byte & 0x7f);
      if (byte & 0x80 == 0) {
        parts.add(value);
        value = 0;
      }
    }
    return parts.join('.');
  }

  static List<int> encodeSequence(List<int> content, {int tag = 0x30}) {
    return [tag, ...encodeLength(content.length), ...content];
  }

  static BerTlv decodeTlv(List<int> bytes, int offset) {
    if (offset >= bytes.length) {
      throw const FormatException('Unexpected end of BER TLV');
    }
    final tag = bytes[offset];
    final (length, headerBytes) = decodeLength(bytes, offset + 1);
    final start = offset + 1 + headerBytes;
    final end = start + length;
    if (end > bytes.length) {
      throw const FormatException('BER value truncated');
    }
    return BerTlv(
      tag: tag,
      value: bytes.sublist(start, end),
      totalLength: 1 + headerBytes + length,
    );
  }
}

class BerTlv {
  const BerTlv({
    required this.tag,
    required this.value,
    required this.totalLength,
  });

  final int tag;
  final List<int> value;
  final int totalLength;
}
