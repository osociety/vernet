import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/services/neighbor_discovery/ber.dart';
import 'package:vernet/services/neighbor_discovery/snmp_client.dart';

int _extractRequestId(List<int> bytes) {
  final message = Ber.decodeTlv(bytes, 0);
  var offset = 0;
  offset += Ber.decodeTlv(message.value, offset).totalLength; // version
  offset += Ber.decodeTlv(message.value, offset).totalLength; // community
  final pdu = Ber.decodeTlv(message.value, offset);
  final reqIdTlv = Ber.decodeTlv(pdu.value, 0);
  return Ber.decodeInteger(reqIdTlv.value);
}

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

  test('decodes IPv4 octet strings and SnmpValue properties', () {
    const value = SnmpValue(tag: 0x40, bytes: [10, 0, 0, 1]);
    expect(value.asIp, '10.0.0.1');
    expect(value.asString, '10.0.0.1');

    const emptyVal = SnmpValue(tag: 0x04, bytes: []);
    expect(emptyVal.asString, '');

    const oidVal = SnmpValue(
      tag: 0x06,
      bytes: [43, 6, 1, 2, 1], // 1.3.6.1.2.1
    );
    expect(oidVal.asString, '1.3.6.1.2.1');

    const intVal = SnmpValue(tag: 0x02, bytes: [0x05]);
    expect(intVal.asInt, 5);
    expect(intVal.asString, '5');

    const counterVal = SnmpValue(tag: 0x41, bytes: [0x64]);
    expect(counterVal.asInt, 100);

    const nonPrintable = SnmpValue(tag: 0x04, bytes: [0xde, 0xad, 0xbe, 0xef]);
    expect(nonPrintable.asString, 'de:ad:be:ef');

    const endOfMib = SnmpValue(tag: 0x82, bytes: []);
    expect(endOfMib.isEndOfMibView, isTrue);

    const noSuchObj = SnmpValue(tag: 0x80, bytes: []);
    expect(noSuchObj.isNoSuchObject, isTrue);

    const noSuchInst = SnmpValue(tag: 0x81, bytes: []);
    expect(noSuchInst.isNoSuchInstance, isTrue);
  });

  test('SnmpV2cClient get retrieves value from UDP server', () async {
    RawDatagramSocket? server;
    try {
      server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = server?.receive();
          if (dg != null) {
            final reqId = _extractRequestId(dg.data);
            final resp = encodeTestGetResponse(
              community: 'public',
              requestId: reqId,
              bindings: [
                SnmpBinding(
                  oid: '1.3.6.1.2.1.1.1.0',
                  value: SnmpValue(tag: 0x04, bytes: 'Cisco IOS'.codeUnits),
                ),
              ],
            );
            server?.send(resp, dg.address, dg.port);
          }
        }
      });

      final client = SnmpV2cClient(port: server.port);
      final value = await client.get(
        '127.0.0.1',
        'public',
        '1.3.6.1.2.1.1.1.0',
        timeout: const Duration(seconds: 2),
      );

      expect(value, isNotNull);
      expect(value!.asString, 'Cisco IOS');
    } finally {
      server?.close();
    }
  });

  test('SnmpV2cClient get returns null for noSuchObject', () async {
    RawDatagramSocket? server;
    try {
      server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = server?.receive();
          if (dg != null) {
            final reqId = _extractRequestId(dg.data);
            final resp = encodeTestGetResponse(
              community: 'public',
              requestId: reqId,
              bindings: [
                const SnmpBinding(
                  oid: '1.3.6.1.2.1.1.99.0',
                  value: SnmpValue(tag: 0x80, bytes: []),
                ),
              ],
            );
            server?.send(resp, dg.address, dg.port);
          }
        }
      });

      final client = SnmpV2cClient(port: server.port);
      final value = await client.get(
        '127.0.0.1',
        'public',
        '1.3.6.1.2.1.1.99.0',
        timeout: const Duration(seconds: 2),
      );

      expect(value, isNull);
    } finally {
      server?.close();
    }
  });

  test('SnmpV2cClient walk retrieves subtree and stops at boundary', () async {
    RawDatagramSocket? server;
    try {
      server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = server?.receive();
          if (dg != null) {
            final reqId = _extractRequestId(dg.data);
            final resp = encodeTestGetResponse(
              community: 'public',
              requestId: reqId,
              bindings: [
                SnmpBinding(
                  oid: '1.3.6.1.2.1.1.1.0',
                  value: SnmpValue(tag: 0x04, bytes: 'IOS-XE'.codeUnits),
                ),
                const SnmpBinding(
                  oid: '1.3.6.1.2.1.2.1.0', // outside prefix 1.3.6.1.2.1.1
                  value: SnmpValue(tag: 0x02, bytes: [1]),
                ),
              ],
            );
            server?.send(resp, dg.address, dg.port);
          }
        }
      });

      final client = SnmpV2cClient(port: server.port);
      final results = await client.walk(
        '127.0.0.1',
        'public',
        '1.3.6.1.2.1.1',
        timeout: const Duration(seconds: 2),
      );

      expect(results, hasLength(1));
      expect(results['1.3.6.1.2.1.1.1.0']?.asString, 'IOS-XE');
    } finally {
      server?.close();
    }
  });
}
