import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:vernet/services/neighbor_discovery/ber.dart';

class SnmpValue {
  const SnmpValue({required this.tag, required this.bytes});

  final int tag;
  final List<int> bytes;

  bool get isEndOfMibView => tag == 0x82;
  bool get isNoSuchObject => tag == 0x80;
  bool get isNoSuchInstance => tag == 0x81;

  int? get asInt {
    if (tag != 0x02 && tag != 0x41 && tag != 0x42 && tag != 0x43 && tag != 0x47) {
      return null;
    }
    return Ber.decodeInteger(bytes);
  }

  String get asString {
    if (bytes.isEmpty) {
      return '';
    }
    if (tag == 0x40 && bytes.length == 4) {
      return asIp ?? '';
    }
    if (tag == 0x06) {
      return Ber.decodeOid(bytes);
    }
    if (tag == 0x02 || tag == 0x41 || tag == 0x42 || tag == 0x43 || tag == 0x47) {
      return '${asInt ?? ''}';
    }
    final text = String.fromCharCodes(bytes);
    if (text.codeUnits.every((c) => c >= 32 && c < 127 || c == 9 || c == 10)) {
      return text;
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  String? get asIp {
    if (bytes.length == 4) {
      return bytes.join('.');
    }
    return null;
  }
}

class SnmpBinding {
  const SnmpBinding({required this.oid, required this.value});

  final String oid;
  final SnmpValue value;
}

abstract class SnmpClient {
  Future<SnmpValue?> get(
    String host,
    String community,
    String oid, {
    Duration timeout,
  });

  Future<Map<String, SnmpValue>> walk(
    String host,
    String community,
    String oid, {
    Duration timeout,
  });
}

/// SNMPv2c over UDP (Get / GetBulk). Used to read CDP and LLDP neighbor MIBs.
class SnmpV2cClient implements SnmpClient {
  SnmpV2cClient({this.maxRepetitions = 20, this.port = 161});

  final int maxRepetitions;
  final int port;
  int _requestId = 1;

  @override
  Future<SnmpValue?> get(
    String host,
    String community,
    String oid, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final bindings = await _request(
      host,
      community,
      _encodePdu(tag: 0xa0, requestId: _nextId(), extraInts: [0, 0], oids: [oid]),
      timeout,
    );
    if (bindings.isEmpty) {
      return null;
    }
    final value = bindings.first.value;
    if (value.isNoSuchObject || value.isNoSuchInstance || value.isEndOfMibView) {
      return null;
    }
    return value;
  }

  @override
  Future<Map<String, SnmpValue>> walk(
    String host,
    String community,
    String oid, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final results = <String, SnmpValue>{};
    var nextOid = oid;
    for (var i = 0; i < 500; i++) {
      final bindings = await _request(
        host,
        community,
        _encodePdu(
          tag: 0xa5,
          requestId: _nextId(),
          extraInts: [0, maxRepetitions],
          oids: [nextOid],
        ),
        timeout,
      );
      if (bindings.isEmpty) {
        break;
      }
      var progressed = false;
      for (final binding in bindings) {
        if (binding.value.isEndOfMibView) {
          return results;
        }
        if (!_isWithin(binding.oid, oid) || binding.oid == nextOid) {
          return results;
        }
        results[binding.oid] = binding.value;
        nextOid = binding.oid;
        progressed = true;
      }
      if (!progressed) {
        break;
      }
    }
    return results;
  }

  int _nextId() {
    _requestId = (_requestId + 1) & 0x7fffffff;
    if (_requestId == 0) {
      _requestId = 1;
    }
    return _requestId;
  }

  static bool _isWithin(String oid, String prefix) {
    return oid == prefix || oid.startsWith('$prefix.');
  }

  List<int> _encodePdu({
    required int tag,
    required int requestId,
    required List<int> extraInts,
    required List<String> oids,
  }) {
    final varbinds = <int>[];
    for (final oid in oids) {
      varbinds.addAll(
        Ber.encodeSequence([
          ...Ber.encodeOid(oid),
          ...Ber.encodeNull(),
        ]),
      );
    }
    final pdu = Ber.encodeSequence(
      [
        ...Ber.encodeInteger(requestId),
        ...Ber.encodeInteger(extraInts[0]),
        ...Ber.encodeInteger(extraInts[1]),
        ...Ber.encodeSequence(varbinds),
      ],
      tag: tag,
    );
    return pdu;
  }

  static List<int> encodeMessage({
    required String community,
    required List<int> pdu,
  }) {
    return Ber.encodeSequence([
      ...Ber.encodeInteger(1), // SNMPv2c
      ...Ber.encodeOctetString(community.codeUnits),
      ...pdu,
    ]);
  }

  static List<SnmpBinding> parseResponse(List<int> datagram) {
    final message = Ber.decodeTlv(datagram, 0);
    if (message.tag != 0x30) {
      throw const FormatException('Not an SNMP sequence');
    }
    var offset = 0;
    offset += Ber.decodeTlv(message.value, offset).totalLength; // version
    offset += Ber.decodeTlv(message.value, offset).totalLength; // community
    final pdu = Ber.decodeTlv(message.value, offset);
    var pduOffset = 0;
    pduOffset += Ber.decodeTlv(pdu.value, pduOffset).totalLength; // request id
    pduOffset += Ber.decodeTlv(pdu.value, pduOffset).totalLength; // error
    pduOffset += Ber.decodeTlv(pdu.value, pduOffset).totalLength; // error index
    final varbindList = Ber.decodeTlv(pdu.value, pduOffset);
    final bindings = <SnmpBinding>[];
    var vbOffset = 0;
    while (vbOffset < varbindList.value.length) {
      final seq = Ber.decodeTlv(varbindList.value, vbOffset);
      final oidTlv = Ber.decodeTlv(seq.value, 0);
      final valueTlv = Ber.decodeTlv(seq.value, oidTlv.totalLength);
      bindings.add(
        SnmpBinding(
          oid: Ber.decodeOid(oidTlv.value),
          value: SnmpValue(tag: valueTlv.tag, bytes: valueTlv.value),
        ),
      );
      vbOffset += seq.totalLength;
    }
    return bindings;
  }

  Future<List<SnmpBinding>> _request(
    String host,
    String community,
    List<int> pdu,
    Duration timeout,
  ) async {
    final message = encodeMessage(community: community, pdu: pdu);
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    Timer? timer;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(message, InternetAddress(host), port);
      final completer = Completer<List<SnmpBinding>>();
      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        try {
          final bindings = parseResponse(datagram.data);
          if (!completer.isCompleted) {
            completer.complete(bindings);
          }
        } catch (_) {
          // Ignore unrelated UDP traffic.
        }
      });
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('No SNMP reply from $host', timeout),
          );
        }
      });
      return await completer.future;
    } finally {
      timer?.cancel();
      await sub?.cancel();
      socket?.close();
    }
  }
}

/// Builds a GetResponse datagram for unit tests.
Uint8List encodeTestGetResponse({
  required String community,
  required List<SnmpBinding> bindings,
  int requestId = 1,
}) {
  final varbinds = <int>[];
  for (final binding in bindings) {
    varbinds.addAll(
      Ber.encodeSequence([
        ...Ber.encodeOid(binding.oid),
        binding.value.tag,
        ...Ber.encodeLength(binding.value.bytes.length),
        ...binding.value.bytes,
      ]),
    );
  }
  final pdu = Ber.encodeSequence(
    [
      ...Ber.encodeInteger(requestId),
      ...Ber.encodeInteger(0),
      ...Ber.encodeInteger(0),
      ...Ber.encodeSequence(varbinds),
    ],
    tag: 0xa2,
  );
  return Uint8List.fromList(
    SnmpV2cClient.encodeMessage(community: community, pdu: pdu),
  );
}
