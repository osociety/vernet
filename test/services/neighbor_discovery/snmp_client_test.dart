import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

void main() {
  test('parses an SNMPv2c GetResponse', () {
    final datagram = encodeTestGetResponse(
      community: 'public',
      bindings: [
        SnmpBinding(
          oid: '1.3.6.1.2.1.1.5.0',
          value: SnmpValue(tag: 0x04, bytes: 'core-sw1'.codeUnits),
        ),
      ],
    );

    final bindings = SnmpV2cClient.parseResponse(datagram);
    expect(bindings, hasLength(1));
    expect(bindings.first.oid, '1.3.6.1.2.1.1.5.0');
    expect(bindings.first.value.asString, 'core-sw1');
  });

  test('decodes IPv4 octet strings', () {
    const value = SnmpValue(tag: 0x40, bytes: [10, 0, 0, 1]);
    expect(value.asIp, '10.0.0.1');
    expect(value.asString, '10.0.0.1');
  });
}
