import 'dart:typed_data';

import 'package:vernet/models/neighbor_info.dart';

/// Cisco Discovery Protocol (CDP) TLV parser.
///
/// Accepts a full Ethernet frame (optional 802.1Q), a SNAP payload, or a
/// raw CDP header starting at the version byte.
class CdpParser {
  static const int deviceId = 0x0001;
  static const int address = 0x0002;
  static const int portId = 0x0003;
  static const int capabilities = 0x0004;
  static const int version = 0x0005;
  static const int platform = 0x0006;
  static const int nativeVlan = 0x000a;
  static const int duplex = 0x000b;
  static const int managementAddress = 0x0016;

  static NeighborInfo? parse(List<int> bytes) {
    final payload = _cdpPayload(bytes);
    if (payload == null || payload.length < 4) {
      return null;
    }
    // version, ttl, checksum — then TLVs
    var offset = 4;
    String? device;
    String? port;
    String? plat;
    String? mgmtIp;
    String? vlan;
    String? duplexLabel;
    String? caps;
    String? sysDescr;

    while (offset + 4 <= payload.length) {
      final type = (payload[offset] << 8) | payload[offset + 1];
      final length = (payload[offset + 2] << 8) | payload[offset + 3];
      if (length < 4 || offset + length > payload.length) {
        break;
      }
      final value = payload.sublist(offset + 4, offset + length);
      switch (type) {
        case deviceId:
          device = _ascii(value);
        case portId:
          port = _ascii(value);
        case platform:
          plat = _ascii(value);
        case version:
          sysDescr = _ascii(value);
        case nativeVlan:
          if (value.length >= 2) {
            vlan = '${(value[0] << 8) | value[1]}';
          }
        case duplex:
          if (value.isNotEmpty) {
            duplexLabel = value[0] == 1 ? 'full' : 'half';
          }
        case address:
        case managementAddress:
          mgmtIp ??= _parseAddresses(value);
        case capabilities:
          caps = _capabilities(value);
      }
      offset += length;
    }

    if (device == null && port == null && plat == null) {
      return null;
    }

    return NeighborInfo(
      protocol: NeighborProtocol.cdp,
      deviceId: device,
      sysName: device,
      managementIp: mgmtIp,
      remotePort: port,
      platform: plat ?? _firstLine(sysDescr),
      vlan: vlan,
      speedDuplex: duplexLabel,
      capabilities: caps,
    );
  }

  static List<int>? _cdpPayload(List<int> bytes) {
    var llc = 14;
    if (bytes.length >= 18 && (bytes[12] << 8 | bytes[13]) == 0x8100) {
      llc = 18;
    }
    if (bytes.length >= llc + 8 &&
        bytes[llc] == 0xaa &&
        bytes[llc + 1] == 0xaa &&
        bytes[llc + 2] == 0x03) {
      return bytes.sublist(llc + 8);
    }
    if (bytes.length >= 4 && (bytes[0] == 1 || bytes[0] == 2)) {
      return bytes;
    }
    return null;
  }

  static String? _parseAddresses(List<int> value) {
    if (value.length < 8) {
      return null;
    }
    var offset = 0;
    // Number of addresses (4 bytes) for type 0x0002; type 0x0016 is similar.
    if (value.length >= 4) {
      offset = 4;
    }
    while (offset + 5 <= value.length) {
      final protocolLength = value[offset + 1];
      final protocolStart = offset + 2;
      final addrLenOffset = protocolStart + protocolLength;
      if (addrLenOffset + 2 > value.length) {
        break;
      }
      final addrLen = (value[addrLenOffset] << 8) | value[addrLenOffset + 1];
      final addrStart = addrLenOffset + 2;
      if (addrStart + addrLen > value.length) {
        break;
      }
      final addr = value.sublist(addrStart, addrStart + addrLen);
      if (addr.length == 4) {
        return addr.join('.');
      }
      offset = addrStart + addrLen;
    }
    return null;
  }

  static String _capabilities(List<int> value) {
    var bits = 0;
    for (final b in value) {
      bits = (bits << 8) | b;
    }
    const labels = {
      0x01: 'Router',
      0x02: 'Transparent bridge',
      0x04: 'Source Route Bridge',
      0x08: 'Switch',
      0x10: 'Host',
      0x20: 'IGMP',
      0x40: 'Repeater',
      0x80: 'Phone',
    };
    final found = <String>[];
    for (final entry in labels.entries) {
      if (bits & entry.key != 0) {
        found.add(entry.value);
      }
    }
    return found.join(', ');
  }

  static String _ascii(List<int> value) {
    return String.fromCharCodes(value.where((c) => c != 0)).trim();
  }

  static String? _firstLine(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.split('\n').first.trim();
  }

  static Uint8List buildTestPayload({
    required String deviceIdValue,
    required String port,
    required String platformValue,
    String? ip,
    int vlan = 1,
    bool fullDuplex = true,
  }) {
    final tlvs = <int>[
      ..._tlv(deviceId, deviceIdValue.codeUnits),
      ..._tlv(portId, port.codeUnits),
      ..._tlv(platform, platformValue.codeUnits),
      ..._tlv(nativeVlan, [(vlan >> 8) & 0xff, vlan & 0xff]),
      ..._tlv(duplex, [if (fullDuplex) 1 else 0]),
      if (ip != null) ..._tlv(address, _addressTlv(ip)),
    ];
    return Uint8List.fromList([2, 180, 0, 0, ...tlvs]);
  }

  static List<int> _tlv(int type, List<int> value) {
    final length = value.length + 4;
    return [
      (type >> 8) & 0xff,
      type & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
      ...value,
    ];
  }

  static List<int> _addressTlv(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return [
      0, 0, 0, 1, // one address
      1, // NLPID
      1, // protocol length
      0xcc, // IP
      0, 4, // address length
      ...parts,
    ];
  }
}
