import 'dart:typed_data';

import 'package:vernet/models/neighbor_info.dart';

/// Link Layer Discovery Protocol (IEEE 802.1AB) parser.
class LldpParser {
  static const int chassisId = 1;
  static const int portId = 2;
  static const int ttl = 3;
  static const int portDescription = 4;
  static const int systemName = 5;
  static const int systemDescription = 6;
  static const int capabilities = 7;
  static const int managementAddress = 8;
  static const int organizational = 127;

  static NeighborInfo? parse(List<int> bytes) {
    final payload = _lldpPayload(bytes);
    if (payload == null) {
      return null;
    }
    var offset = 0;
    String? chassis;
    String? port;
    String? portDesc;
    String? sysName;
    String? sysDesc;
    String? mgmtIp;
    String? vlan;
    String? speedDuplex;
    String? caps;

    while (offset + 2 <= payload.length) {
      final type = payload[offset] >> 1;
      final length = ((payload[offset] & 0x01) << 8) | payload[offset + 1];
      offset += 2;
      if (type == 0) {
        break;
      }
      if (offset + length > payload.length) {
        break;
      }
      final value = payload.sublist(offset, offset + length);
      offset += length;
      switch (type) {
        case chassisId:
          chassis = _id(value);
        case portId:
          port = _id(value);
        case portDescription:
          portDesc = _ascii(value);
        case systemName:
          sysName = _ascii(value);
        case systemDescription:
          sysDesc = _ascii(value);
        case capabilities:
          caps = _capabilities(value);
        case managementAddress:
          mgmtIp ??= _managementIp(value);
        case organizational:
          final org = _orgSpecific(value);
          vlan ??= org.vlan;
          speedDuplex ??= org.speedDuplex;
      }
    }

    if (chassis == null && sysName == null && port == null) {
      return null;
    }

    return NeighborInfo(
      protocol: NeighborProtocol.lldp,
      deviceId: chassis,
      sysName: sysName ?? chassis,
      managementIp: mgmtIp,
      remotePort: portDesc?.isNotEmpty == true ? portDesc : port,
      platform: _firstLine(sysDesc),
      vlan: vlan,
      speedDuplex: speedDuplex,
      capabilities: caps,
    );
  }

  static List<int>? _lldpPayload(List<int> bytes) {
    if (bytes.length >= 14) {
      var typeOffset = 12;
      if ((bytes[12] << 8 | bytes[13]) == 0x8100 && bytes.length >= 18) {
        typeOffset = 16;
      }
      final etherType = (bytes[typeOffset] << 8) | bytes[typeOffset + 1];
      if (etherType == 0x88cc) {
        return bytes.sublist(typeOffset + 2);
      }
    }
    if (bytes.length >= 2) {
      final type = bytes[0] >> 1;
      if (type >= 1 && type <= 8 || type == 127) {
        return bytes;
      }
    }
    return null;
  }

  static String _id(List<int> value) {
    if (value.isEmpty) {
      return '';
    }
    final subtype = value.first;
    final rest = value.sublist(1);
    if (subtype == 4 || rest.length == 6) {
      return rest.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
    }
    return _ascii(rest);
  }

  static String _ascii(List<int> value) {
    return String.fromCharCodes(value.where((c) => c != 0)).trim();
  }

  static String? _managementIp(List<int> value) {
    if (value.length < 6) {
      return null;
    }
    final addrLen = value[0];
    if (addrLen < 2 || 1 + addrLen > value.length) {
      return null;
    }
    final subtype = value[1];
    final addr = value.sublist(2, 1 + addrLen);
    if (subtype == 1 && addr.length == 4) {
      return addr.join('.');
    }
    return null;
  }

  static String _capabilities(List<int> value) {
    if (value.length < 4) {
      return '';
    }
    final enabled = (value[2] << 8) | value[3];
    const labels = {
      0x01: 'Other',
      0x02: 'Repeater',
      0x04: 'Bridge',
      0x08: 'WLAN AP',
      0x10: 'Router',
      0x20: 'Telephone',
      0x40: 'DOCSIS',
      0x80: 'Station',
    };
    final found = <String>[];
    for (final entry in labels.entries) {
      if (enabled & entry.key != 0) {
        found.add(entry.value);
      }
    }
    return found.join(', ');
  }

  static ({String? vlan, String? speedDuplex}) _orgSpecific(List<int> value) {
    if (value.length < 4) {
      return (vlan: null, speedDuplex: null);
    }
    final oui = (value[0] << 16) | (value[1] << 8) | value[2];
    final subtype = value[3];
    final rest = value.sublist(4);
    if (oui == 0x0080c2 && subtype == 1 && rest.length >= 2) {
      return (vlan: '${(rest[0] << 8) | rest[1]}', speedDuplex: null);
    }
    if (oui == 0x00120f && subtype == 1 && rest.length >= 5) {
      final mau = (rest[3] << 8) | rest[4];
      return (vlan: null, speedDuplex: _mauType(mau));
    }
    return (vlan: null, speedDuplex: null);
  }

  static String _mauType(int mau) {
    const map = {
      10: '10 Mbps half',
      11: '10 Mbps full',
      15: '100 Mbps half',
      16: '100 Mbps full',
      30: '1 Gbps full',
      34: '1 Gbps full',
      39: '10 Gbps full',
    };
    return map[mau] ?? 'MAU $mau';
  }

  static String? _firstLine(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.split('\n').first.trim();
  }

  static Uint8List buildTestPayload({
    required String sysNameValue,
    required String port,
    required String platform,
    String? ip,
    int vlan = 20,
  }) {
    final tlvs = <int>[
      ..._tlv(chassisId, [4, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
      ..._tlv(portId, [5, ...port.codeUnits]),
      ..._tlv(ttl, [0x00, 0x78]),
      ..._tlv(systemName, sysNameValue.codeUnits),
      ..._tlv(systemDescription, platform.codeUnits),
      ..._tlv(organizational, [0x00, 0x80, 0xc2, 0x01, (vlan >> 8) & 0xff, vlan & 0xff]),
      ..._tlv(organizational, [0x00, 0x12, 0x0f, 0x01, 0x00, 0x00, 0x00, 0x00, 0x1e]),
      if (ip != null) ..._tlv(managementAddress, _mgmt(ip)),
      0x00, 0x00,
    ];
    return Uint8List.fromList(tlvs);
  }

  static List<int> _tlv(int type, List<int> value) {
    final length = value.length;
    return [(type << 1) | ((length >> 8) & 0x01), length & 0xff, ...value];
  }

  static List<int> _mgmt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return [
      5, // length of subtype+address
      1, // IPv4
      ...parts,
      0, // if subtype unknown
      0, 0, 0, 0, // if id
      0, // oid length
    ];
  }
}
